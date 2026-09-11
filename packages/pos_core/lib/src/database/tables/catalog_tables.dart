import 'package:drift/drift.dart';

import 'staff_table.dart';

class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Suppliers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  TextColumn get contactPerson => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Unit of sale for a product. `unitsPerPack` lets a product be stocked as
/// one unit (e.g. carton) and sold as another (e.g. piece) — e.g. a carton
/// of 24 sachets: baseUnit = piece, unitsPerPack = 24, sold either way.
enum ProductUnit { piece, carton, kg, litre, pack }

class Products extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 150)();

  /// Scanned barcode (EAN-13/UPC/etc). Nullable because some loose/weighed
  /// items are looked up by name/PLU instead of a barcode.
  TextColumn get barcode => text().nullable().unique()();
  TextColumn get sku => text().nullable()();

  TextColumn get categoryId =>
      text().nullable().references(Categories, #id)();
  TextColumn get supplierId =>
      text().nullable().references(Suppliers, #id)();

  IntColumn get costPriceKobo => integer()();
  IntColumn get sellingPriceKobo => integer()();

  /// Whether Nigerian VAT (7.5%) applies to this line item at sale time.
  BoolColumn get isVatable => boolean().withDefault(const Constant(true))();

  TextColumn get unit => textEnum<ProductUnit>()();
  IntColumn get unitsPerPack => integer().withDefault(const Constant(1))();

  /// Cached on-hand quantity, kept in sync with [StockMovements] inside a
  /// transaction. Source of truth for auditing is the movement ledger.
  IntColumn get quantityOnHand => integer().withDefault(const Constant(0))();
  IntColumn get lowStockThreshold => integer().withDefault(const Constant(0))();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

enum StockMovementType {
  restock,
  damage,
  loss,
  transferIn,
  transferOut,
  saleDeduction,
  saleReturn,
  adjustmentIncrease,
  adjustmentDecrease,
}

/// Append-only ledger of every stock change. [Products.quantityOnHand] is a
/// derived cache; this table is the audit trail of *why* it changed.
class StockMovements extends Table {
  TextColumn get id => text()();
  TextColumn get productId => text().references(Products, #id)();
  TextColumn get type => textEnum<StockMovementType>()();

  /// Signed delta applied to quantityOnHand (negative for deductions).
  IntColumn get quantityDelta => integer()();
  TextColumn get reason => text().nullable()();
  TextColumn get staffId => text().references(Staff, #id)();
  TextColumn get relatedSaleId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
