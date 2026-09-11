// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sale_dao.dart';

// ignore_for_file: type=lint
mixin _$SaleDaoMixin on DatabaseAccessor<PosDatabase> {
  $StaffTable get staff => attachedDatabase.staff;
  $TillSessionsTable get tillSessions => attachedDatabase.tillSessions;
  $CustomersTable get customers => attachedDatabase.customers;
  $SalesTable get sales => attachedDatabase.sales;
  $CategoriesTable get categories => attachedDatabase.categories;
  $SuppliersTable get suppliers => attachedDatabase.suppliers;
  $ProductsTable get products => attachedDatabase.products;
  $SaleItemsTable get saleItems => attachedDatabase.saleItems;
  $PaymentsTable get payments => attachedDatabase.payments;
  SaleDaoManager get managers => SaleDaoManager(this);
}

class SaleDaoManager {
  final _$SaleDaoMixin _db;
  SaleDaoManager(this._db);
  $$StaffTableTableManager get staff =>
      $$StaffTableTableManager(_db.attachedDatabase, _db.staff);
  $$TillSessionsTableTableManager get tillSessions =>
      $$TillSessionsTableTableManager(_db.attachedDatabase, _db.tillSessions);
  $$CustomersTableTableManager get customers =>
      $$CustomersTableTableManager(_db.attachedDatabase, _db.customers);
  $$SalesTableTableManager get sales =>
      $$SalesTableTableManager(_db.attachedDatabase, _db.sales);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$SuppliersTableTableManager get suppliers =>
      $$SuppliersTableTableManager(_db.attachedDatabase, _db.suppliers);
  $$ProductsTableTableManager get products =>
      $$ProductsTableTableManager(_db.attachedDatabase, _db.products);
  $$SaleItemsTableTableManager get saleItems =>
      $$SaleItemsTableTableManager(_db.attachedDatabase, _db.saleItems);
  $$PaymentsTableTableManager get payments =>
      $$PaymentsTableTableManager(_db.attachedDatabase, _db.payments);
}
