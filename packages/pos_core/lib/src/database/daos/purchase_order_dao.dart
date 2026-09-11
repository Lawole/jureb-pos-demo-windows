import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/purchase_order_tables.dart';

part 'purchase_order_dao.g.dart';

@DriftAccessor(tables: [PurchaseOrders, PurchaseOrderItems])
class PurchaseOrderDao extends DatabaseAccessor<PosDatabase>
    with _$PurchaseOrderDaoMixin {
  PurchaseOrderDao(super.db);

  Stream<List<PurchaseOrder>> watchAll() => (select(purchaseOrders)
        ..orderBy([(o) => OrderingTerm.desc(o.orderedAt)]))
      .watch();

  Future<PurchaseOrder?> findById(String id) =>
      (select(purchaseOrders)..where((o) => o.id.equals(id)))
          .getSingleOrNull();

  Stream<PurchaseOrder?> watchById(String id) =>
      (select(purchaseOrders)..where((o) => o.id.equals(id)))
          .watchSingleOrNull();

  Stream<List<PurchaseOrderItem>> watchItems(String purchaseOrderId) =>
      (select(purchaseOrderItems)
            ..where((i) => i.purchaseOrderId.equals(purchaseOrderId)))
          .watch();

  Future<List<PurchaseOrderItem>> itemsFor(String purchaseOrderId) =>
      (select(purchaseOrderItems)
            ..where((i) => i.purchaseOrderId.equals(purchaseOrderId)))
          .get();

  Future<int> insertOrder(PurchaseOrdersCompanion entry) =>
      into(purchaseOrders).insert(entry);

  Future<int> insertItem(PurchaseOrderItemsCompanion entry) =>
      into(purchaseOrderItems).insert(entry);

  Future<void> updateOrderStatus(
    String id,
    PurchaseOrderStatus status, {
    DateTime? receivedAt,
  }) =>
      (update(purchaseOrders)..where((o) => o.id.equals(id))).write(
        PurchaseOrdersCompanion(
          status: Value(status),
          receivedAt:
              receivedAt == null ? const Value.absent() : Value(receivedAt),
        ),
      );

  Future<void> updateItemReceivedQuantity(String itemId, double received) =>
      (update(purchaseOrderItems)..where((i) => i.id.equals(itemId)))
          .write(PurchaseOrderItemsCompanion(
        quantityReceived: Value(received),
      ));
}
