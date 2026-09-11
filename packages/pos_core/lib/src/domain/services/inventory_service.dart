import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../database/daos/product_dao.dart';
import '../../database/daos/purchase_order_dao.dart';
import '../../database/daos/stock_movement_dao.dart';
import '../../database/database.dart';
import '../../database/tables/catalog_tables.dart';
import '../../database/tables/purchase_order_tables.dart';

/// True for movement types that add to stock; false for types that remove
/// from it. Centralized here so callers never have to remember (and can't
/// get wrong) which sign a movement type implies.
bool _isIncrease(StockMovementType type) => switch (type) {
      StockMovementType.restock ||
      StockMovementType.transferIn ||
      StockMovementType.saleReturn ||
      StockMovementType.adjustmentIncrease =>
        true,
      StockMovementType.damage ||
      StockMovementType.loss ||
      StockMovementType.transferOut ||
      StockMovementType.saleDeduction ||
      StockMovementType.adjustmentDecrease =>
        false,
    };

class PurchaseOrderLineInput {
  const PurchaseOrderLineInput({
    required this.productId,
    required this.quantityOrdered,
    required this.unitCostKobo,
  });

  final String productId;
  final double quantityOrdered;
  final int unitCostKobo;
}

class ReceivedLineInput {
  const ReceivedLineInput({
    required this.itemId,
    required this.quantityReceivedNow,
  });

  /// [PurchaseOrderItem.id], not the product id — a PO can list the same
  /// product on two lines (e.g. two different cost prices from a supplier).
  final String itemId;

  /// Quantity received in *this* delivery, not the cumulative total.
  final double quantityReceivedNow;
}

/// Product, stock, and purchase-order business logic. Every stock quantity
/// change — whether from a direct adjustment or receiving a purchase order
/// — goes through here so [StockMovements] is always a complete audit trail
/// and [Products.quantityOnHand] never drifts out of sync with it.
class InventoryService {
  InventoryService(this._db)
      : _productDao = _db.productDao,
        _stockMovementDao = _db.stockMovementDao,
        _purchaseOrderDao = _db.purchaseOrderDao;

  final PosDatabase _db;
  final ProductDao _productDao;
  final StockMovementDao _stockMovementDao;
  final PurchaseOrderDao _purchaseOrderDao;
  static const _uuid = Uuid();

  Future<Product> createProduct({
    required String name,
    required int costPriceKobo,
    required int sellingPriceKobo,
    required ProductUnit unit,
    required String staffId,
    String? barcode,
    String? sku,
    String? categoryId,
    String? supplierId,
    bool isVatable = true,
    int unitsPerPack = 1,
    int lowStockThreshold = 0,
    int initialQuantity = 0,
  }) async {
    final id = _uuid.v4();
    await _db.transaction(() async {
      await _productDao.insertProduct(ProductsCompanion.insert(
        id: id,
        name: name,
        barcode: Value(barcode),
        sku: Value(sku),
        categoryId: Value(categoryId),
        supplierId: Value(supplierId),
        costPriceKobo: costPriceKobo,
        sellingPriceKobo: sellingPriceKobo,
        isVatable: Value(isVatable),
        unit: unit,
        unitsPerPack: Value(unitsPerPack),
        lowStockThreshold: Value(lowStockThreshold),
      ));
      if (initialQuantity > 0) {
        await _recordMovement(
          productId: id,
          type: StockMovementType.restock,
          quantity: initialQuantity,
          staffId: staffId,
          reason: 'Initial stock on product creation',
        );
      }
    });
    return (await _productDao.findById(id))!;
  }

  /// Updates product fields other than quantity — stock only ever changes
  /// through [adjustStock] or [receivePurchaseOrder], never a direct edit,
  /// so every change to it is always attributed and logged.
  Future<void> updateProduct(Product product) => _productDao.updateProduct(
        product.toCompanion(true).copyWith(updatedAt: Value(DateTime.now())),
      );

  Future<void> deleteProduct(String id) => _productDao.softDelete(id);

  /// Records a stock change of [quantity] (always positive) for [productId].
  /// The sign applied to [Products.quantityOnHand] is derived from [type],
  /// so callers can't accidentally under/overstate a movement's direction.
  Future<void> adjustStock({
    required String productId,
    required StockMovementType type,
    required int quantity,
    required String staffId,
    String? reason,
  }) {
    if (quantity <= 0) {
      throw ArgumentError.value(quantity, 'quantity', 'must be positive');
    }
    return _db.transaction(() => _recordMovement(
          productId: productId,
          type: type,
          quantity: quantity,
          staffId: staffId,
          reason: reason,
        ));
  }

  /// Posts a `saleDeduction`/`saleReturn` movement for [quantity] units of
  /// [productId], attributed to [saleId]. Deliberately does *not* open its
  /// own transaction — [SaleService] calls this from inside the same
  /// transaction that writes the sale/refund row, so stock and the sale
  /// record can never disagree about whether the other happened.
  Future<void> recordMovementForSale({
    required String productId,
    required int quantity,
    required bool isReturn,
    required String staffId,
    required String saleId,
  }) {
    if (quantity <= 0) {
      throw ArgumentError.value(quantity, 'quantity', 'must be positive');
    }
    return _recordMovement(
      productId: productId,
      type: isReturn
          ? StockMovementType.saleReturn
          : StockMovementType.saleDeduction,
      quantity: quantity,
      staffId: staffId,
      relatedSaleId: saleId,
    );
  }

  Future<void> _recordMovement({
    required String productId,
    required StockMovementType type,
    required int quantity,
    required String staffId,
    String? reason,
    String? relatedSaleId,
  }) async {
    final delta = _isIncrease(type) ? quantity : -quantity;
    await _productDao.applyQuantityDelta(productId, delta);
    await _stockMovementDao.insertMovement(StockMovementsCompanion.insert(
      id: _uuid.v4(),
      productId: productId,
      type: type,
      quantityDelta: delta,
      staffId: staffId,
      reason: Value(reason),
      relatedSaleId: Value(relatedSaleId),
    ));
  }

  Future<PurchaseOrder> createPurchaseOrder({
    required String supplierId,
    required String staffId,
    required List<PurchaseOrderLineInput> items,
    DateTime? expectedAt,
    String? notes,
  }) async {
    if (items.isEmpty) {
      throw ArgumentError('A purchase order needs at least one line item');
    }
    final id = _uuid.v4();
    await _db.transaction(() async {
      await _purchaseOrderDao.insertOrder(PurchaseOrdersCompanion.insert(
        id: id,
        supplierId: supplierId,
        staffId: staffId,
        status: const Value(PurchaseOrderStatus.ordered),
        expectedAt: Value(expectedAt),
        notes: Value(notes),
      ));
      for (final item in items) {
        await _purchaseOrderDao.insertItem(PurchaseOrderItemsCompanion.insert(
          id: _uuid.v4(),
          purchaseOrderId: id,
          productId: item.productId,
          quantityOrdered: item.quantityOrdered,
          unitCostKobo: item.unitCostKobo,
        ));
      }
    });
    return (await _purchaseOrderDao.findById(id))!;
  }

  /// Applies a (possibly partial) delivery against a purchase order: bumps
  /// each line's received quantity, posts a restock [StockMovement] for the
  /// whole-unit portion received, and rolls the order status up to
  /// ordered/partiallyReceived/received based on the totals afterwards.
  Future<void> receivePurchaseOrder({
    required String purchaseOrderId,
    required List<ReceivedLineInput> receivedLines,
    required String staffId,
  }) async {
    await _db.transaction(() async {
      final items = await _purchaseOrderDao.itemsFor(purchaseOrderId);
      final itemsById = {for (final item in items) item.id: item};

      for (final line in receivedLines) {
        if (line.quantityReceivedNow <= 0) continue;
        final item = itemsById[line.itemId];
        if (item == null) {
          throw ArgumentError('Unknown purchase order item ${line.itemId}');
        }
        final newTotal = item.quantityReceived + line.quantityReceivedNow;
        if (newTotal > item.quantityOrdered + 0.0001) {
          throw ArgumentError(
              'Cannot receive $newTotal against an order of ${item.quantityOrdered}');
        }
        await _purchaseOrderDao.updateItemReceivedQuantity(item.id, newTotal);

        final wholeUnits = line.quantityReceivedNow.round();
        if (wholeUnits > 0) {
          await _recordMovement(
            productId: item.productId,
            type: StockMovementType.restock,
            quantity: wholeUnits,
            staffId: staffId,
            reason: 'Received against purchase order $purchaseOrderId',
          );
        }
      }

      final updatedItems = await _purchaseOrderDao.itemsFor(purchaseOrderId);
      final fullyReceived =
          updatedItems.every((i) => i.quantityReceived >= i.quantityOrdered - 0.0001);
      final anyReceived = updatedItems.any((i) => i.quantityReceived > 0);
      final newStatus = fullyReceived
          ? PurchaseOrderStatus.received
          : anyReceived
              ? PurchaseOrderStatus.partiallyReceived
              : PurchaseOrderStatus.ordered;
      await _purchaseOrderDao.updateOrderStatus(
        purchaseOrderId,
        newStatus,
        receivedAt: fullyReceived ? DateTime.now() : null,
      );
    });
  }
}
