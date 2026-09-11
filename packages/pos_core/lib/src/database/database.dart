import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

import 'connection/connection.dart' as impl;
import 'daos/category_dao.dart';
import 'daos/counter_dao.dart';
import 'daos/product_dao.dart';
import 'daos/purchase_order_dao.dart';
import 'daos/sale_dao.dart';
import 'daos/staff_dao.dart';
import 'daos/stock_movement_dao.dart';
import 'daos/supplier_dao.dart';
import 'daos/till_session_dao.dart';
import 'tables/catalog_tables.dart';
import 'tables/counter_table.dart';
import 'tables/customer_table.dart';
import 'tables/purchase_order_tables.dart';
import 'tables/sales_tables.dart';
import 'tables/staff_table.dart';
import 'tables/till_tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Staff,
    Categories,
    Suppliers,
    Products,
    StockMovements,
    Customers,
    TillSessions,
    Shifts,
    Sales,
    SaleItems,
    Payments,
    PurchaseOrders,
    PurchaseOrderItems,
    Counters,
  ],
  daos: [
    StaffDao,
    CategoryDao,
    SupplierDao,
    ProductDao,
    StockMovementDao,
    PurchaseOrderDao,
    TillSessionDao,
    SaleDao,
    CounterDao,
  ],
)
class PosDatabase extends _$PosDatabase {
  PosDatabase(super.executor);

  /// Opens (or creates) the on-disk database at [fileName] under the given
  /// [directoryPath]. Used by desktop/mobile apps; tests use
  /// [PosDatabase.forTesting] with an in-memory executor instead.
  factory PosDatabase.open({
    required String directoryPath,
    String fileName = 'pos.sqlite',
  }) =>
      PosDatabase(impl.openConnection(directoryPath, fileName));

  @visibleForTesting
  factory PosDatabase.forTesting(QueryExecutor executor) =>
      PosDatabase(executor);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // v1 -> v2: Phase 2 added purchase orders.
          if (from < 2) {
            await m.createTable(purchaseOrders);
            await m.createTable(purchaseOrderItems);
          }
          // v2 -> v3: Phase 3 added the receipt-number counter table.
          if (from < 3) {
            await m.createTable(counters);
          }
          // v3 -> v4: Phase 3 refunds track cumulative returned quantity
          // per sale line.
          if (from < 4) {
            await m.addColumn(saleItems, saleItems.returnedQuantity);
          }
        },
      );
}
