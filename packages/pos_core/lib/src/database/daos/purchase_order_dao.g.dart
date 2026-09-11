// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'purchase_order_dao.dart';

// ignore_for_file: type=lint
mixin _$PurchaseOrderDaoMixin on DatabaseAccessor<PosDatabase> {
  $SuppliersTable get suppliers => attachedDatabase.suppliers;
  $StaffTable get staff => attachedDatabase.staff;
  $PurchaseOrdersTable get purchaseOrders => attachedDatabase.purchaseOrders;
  $CategoriesTable get categories => attachedDatabase.categories;
  $ProductsTable get products => attachedDatabase.products;
  $PurchaseOrderItemsTable get purchaseOrderItems =>
      attachedDatabase.purchaseOrderItems;
  PurchaseOrderDaoManager get managers => PurchaseOrderDaoManager(this);
}

class PurchaseOrderDaoManager {
  final _$PurchaseOrderDaoMixin _db;
  PurchaseOrderDaoManager(this._db);
  $$SuppliersTableTableManager get suppliers =>
      $$SuppliersTableTableManager(_db.attachedDatabase, _db.suppliers);
  $$StaffTableTableManager get staff =>
      $$StaffTableTableManager(_db.attachedDatabase, _db.staff);
  $$PurchaseOrdersTableTableManager get purchaseOrders =>
      $$PurchaseOrdersTableTableManager(
        _db.attachedDatabase,
        _db.purchaseOrders,
      );
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$ProductsTableTableManager get products =>
      $$ProductsTableTableManager(_db.attachedDatabase, _db.products);
  $$PurchaseOrderItemsTableTableManager get purchaseOrderItems =>
      $$PurchaseOrderItemsTableTableManager(
        _db.attachedDatabase,
        _db.purchaseOrderItems,
      );
}
