import 'package:drift/native.dart';
import 'package:pos_core/pos_core.dart';
import 'package:test/test.dart';

void main() {
  late PosDatabase db;
  late InventoryService inventory;
  late String staffId;

  setUp(() async {
    db = PosDatabase.forTesting(NativeDatabase.memory());
    inventory = InventoryService(db);
    final auth = AuthService(db.staffDao);
    final staff = await auth.createStaff(
      fullName: 'Stock Clerk',
      role: StaffRole.manager,
      pin: '1111',
    );
    staffId = staff.id;
  });

  tearDown(() => db.close());

  Future<Product> makeProduct({int initialQuantity = 0, int lowStockThreshold = 0}) =>
      inventory.createProduct(
        name: 'Peak Milk 400g',
        costPriceKobo: 80000,
        sellingPriceKobo: 100000,
        unit: ProductUnit.piece,
        staffId: staffId,
        initialQuantity: initialQuantity,
        lowStockThreshold: lowStockThreshold,
      );

  group('createProduct', () {
    test('creates a product with zero stock by default', () async {
      final product = await makeProduct();
      expect(product.quantityOnHand, 0);
    });

    test('initial quantity is logged as a restock movement', () async {
      final product = await makeProduct(initialQuantity: 50);
      expect(product.quantityOnHand, 50);

      final movements = await db.stockMovementDao.watchForProduct(product.id).first;
      expect(movements, hasLength(1));
      expect(movements.single.type, StockMovementType.restock);
      expect(movements.single.quantityDelta, 50);
    });
  });

  group('adjustStock', () {
    test('restock increases quantity', () async {
      final product = await makeProduct(initialQuantity: 10);
      await inventory.adjustStock(
        productId: product.id,
        type: StockMovementType.restock,
        quantity: 20,
        staffId: staffId,
      );
      final updated = await db.productDao.findById(product.id);
      expect(updated!.quantityOnHand, 30);
    });

    test('damage decreases quantity', () async {
      final product = await makeProduct(initialQuantity: 10);
      await inventory.adjustStock(
        productId: product.id,
        type: StockMovementType.damage,
        quantity: 3,
        staffId: staffId,
        reason: 'Dropped carton',
      );
      final updated = await db.productDao.findById(product.id);
      expect(updated!.quantityOnHand, 7);

      final movements = await db.stockMovementDao.watchForProduct(product.id).first;
      final damageMovement =
          movements.firstWhere((m) => m.type == StockMovementType.damage);
      expect(damageMovement.quantityDelta, -3);
      expect(damageMovement.reason, 'Dropped carton');
    });

    test('deduction that would go below zero is rejected and not applied',
        () async {
      final product = await makeProduct(initialQuantity: 5);
      expect(
        () => inventory.adjustStock(
          productId: product.id,
          type: StockMovementType.loss,
          quantity: 10,
          staffId: staffId,
        ),
        throwsArgumentError,
      );

      final unchanged = await db.productDao.findById(product.id);
      expect(unchanged!.quantityOnHand, 5,
          reason: 'a rejected adjustment must not partially apply');

      final movements = await db.stockMovementDao.watchForProduct(product.id).first;
      expect(movements, hasLength(1), reason: 'only the initial-stock movement, no loss movement');
    });

    test('zero or negative quantity is rejected', () async {
      final product = await makeProduct();
      expect(
        () => inventory.adjustStock(
          productId: product.id,
          type: StockMovementType.restock,
          quantity: 0,
          staffId: staffId,
        ),
        throwsArgumentError,
      );
    });
  });

  group('low stock', () {
    test('watchLowStock reports products at or below threshold', () async {
      await makeProduct(initialQuantity: 2, lowStockThreshold: 5);
      await makeProduct(initialQuantity: 100, lowStockThreshold: 5);

      final lowStock = await db.productDao.watchLowStock().first;
      expect(lowStock, hasLength(1));
      expect(lowStock.single.quantityOnHand, 2);
    });
  });

  group('purchase orders', () {
    test('creating a PO with no items is rejected', () async {
      expect(
        () => inventory.createPurchaseOrder(
          supplierId: 'supplier-1',
          staffId: staffId,
          items: const [],
        ),
        throwsArgumentError,
      );
    });

    test('receiving a PO fully updates stock and marks it received', () async {
      final product = await makeProduct(initialQuantity: 0);
      final supplierId = await _makeSupplier(db);

      final po = await inventory.createPurchaseOrder(
        supplierId: supplierId,
        staffId: staffId,
        items: [
          PurchaseOrderLineInput(
              productId: product.id, quantityOrdered: 24, unitCostKobo: 75000),
        ],
      );

      final items = await db.purchaseOrderDao.itemsFor(po.id);
      await inventory.receivePurchaseOrder(
        purchaseOrderId: po.id,
        staffId: staffId,
        receivedLines: [
          ReceivedLineInput(itemId: items.single.id, quantityReceivedNow: 24),
        ],
      );

      final updatedProduct = await db.productDao.findById(product.id);
      expect(updatedProduct!.quantityOnHand, 24);

      final updatedPo = await db.purchaseOrderDao.findById(po.id);
      expect(updatedPo!.status, PurchaseOrderStatus.received);
      expect(updatedPo.receivedAt, isNotNull);
    });

    test('partial receipt marks the order partiallyReceived', () async {
      final product = await makeProduct();
      final supplierId = await _makeSupplier(db);

      final po = await inventory.createPurchaseOrder(
        supplierId: supplierId,
        staffId: staffId,
        items: [
          PurchaseOrderLineInput(
              productId: product.id, quantityOrdered: 10, unitCostKobo: 50000),
        ],
      );
      final items = await db.purchaseOrderDao.itemsFor(po.id);

      await inventory.receivePurchaseOrder(
        purchaseOrderId: po.id,
        staffId: staffId,
        receivedLines: [
          ReceivedLineInput(itemId: items.single.id, quantityReceivedNow: 4),
        ],
      );

      final updatedPo = await db.purchaseOrderDao.findById(po.id);
      expect(updatedPo!.status, PurchaseOrderStatus.partiallyReceived);

      final updatedProduct = await db.productDao.findById(product.id);
      expect(updatedProduct!.quantityOnHand, 4);
    });

    test('receiving more than ordered is rejected', () async {
      final product = await makeProduct();
      final supplierId = await _makeSupplier(db);

      final po = await inventory.createPurchaseOrder(
        supplierId: supplierId,
        staffId: staffId,
        items: [
          PurchaseOrderLineInput(
              productId: product.id, quantityOrdered: 5, unitCostKobo: 50000),
        ],
      );
      final items = await db.purchaseOrderDao.itemsFor(po.id);

      expect(
        () => inventory.receivePurchaseOrder(
          purchaseOrderId: po.id,
          staffId: staffId,
          receivedLines: [
            ReceivedLineInput(itemId: items.single.id, quantityReceivedNow: 6),
          ],
        ),
        throwsArgumentError,
      );

      final updatedProduct = await db.productDao.findById(product.id);
      expect(updatedProduct!.quantityOnHand, 0,
          reason: 'rejected over-receipt must not touch stock');
    });
  });
}

Future<String> _makeSupplier(PosDatabase db) async {
  const uuid = 'supplier-test-id';
  await db.supplierDao.insertSupplier(SuppliersCompanion.insert(
    id: uuid,
    name: 'Promasidor Nigeria',
  ));
  return uuid;
}
