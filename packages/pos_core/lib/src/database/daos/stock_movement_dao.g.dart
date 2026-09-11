// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stock_movement_dao.dart';

// ignore_for_file: type=lint
mixin _$StockMovementDaoMixin on DatabaseAccessor<PosDatabase> {
  $CategoriesTable get categories => attachedDatabase.categories;
  $SuppliersTable get suppliers => attachedDatabase.suppliers;
  $ProductsTable get products => attachedDatabase.products;
  $StaffTable get staff => attachedDatabase.staff;
  $StockMovementsTable get stockMovements => attachedDatabase.stockMovements;
  StockMovementDaoManager get managers => StockMovementDaoManager(this);
}

class StockMovementDaoManager {
  final _$StockMovementDaoMixin _db;
  StockMovementDaoManager(this._db);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$SuppliersTableTableManager get suppliers =>
      $$SuppliersTableTableManager(_db.attachedDatabase, _db.suppliers);
  $$ProductsTableTableManager get products =>
      $$ProductsTableTableManager(_db.attachedDatabase, _db.products);
  $$StaffTableTableManager get staff =>
      $$StaffTableTableManager(_db.attachedDatabase, _db.staff);
  $$StockMovementsTableTableManager get stockMovements =>
      $$StockMovementsTableTableManager(
        _db.attachedDatabase,
        _db.stockMovements,
      );
}
