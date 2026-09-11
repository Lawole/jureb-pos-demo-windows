import 'package:drift/drift.dart';

import 'catalog_tables.dart';
import 'staff_table.dart';

enum PurchaseOrderStatus {
  draft,
  ordered,
  partiallyReceived,
  received,
  cancelled,
}

/// A purchase order raised against a supplier. Line items live in
/// [PurchaseOrderItems]; receiving stock against a PO posts
/// [StockMovementType.restock] entries and updates [Products.quantityOnHand]
/// — this table itself never holds a stock quantity.
class PurchaseOrders extends Table {
  TextColumn get id => text()();
  TextColumn get supplierId => text().references(Suppliers, #id)();
  TextColumn get staffId => text().references(Staff, #id)();
  TextColumn get status => textEnum<PurchaseOrderStatus>()
      .withDefault(Constant(PurchaseOrderStatus.draft.name))();
  DateTimeColumn get orderedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get expectedAt => dateTime().nullable()();
  DateTimeColumn get receivedAt => dateTime().nullable()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class PurchaseOrderItems extends Table {
  TextColumn get id => text()();
  TextColumn get purchaseOrderId =>
      text().references(PurchaseOrders, #id)();
  TextColumn get productId => text().references(Products, #id)();

  RealColumn get quantityOrdered => real()();
  RealColumn get quantityReceived => real().withDefault(const Constant(0))();
  IntColumn get unitCostKobo => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
