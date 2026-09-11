/// Platform-agnostic core: database, domain models, and business logic for
/// the POS app. UI layers (desktop today, mobile later) depend on this
/// package and never touch Drift or hashing directly.
library;

export 'src/database/daos/category_dao.dart';
export 'src/database/daos/counter_dao.dart';
export 'src/database/daos/product_dao.dart';
export 'src/database/daos/purchase_order_dao.dart';
export 'src/database/daos/sale_dao.dart';
export 'src/database/daos/staff_dao.dart';
export 'src/database/daos/stock_movement_dao.dart';
export 'src/database/daos/supplier_dao.dart';
export 'src/database/daos/till_session_dao.dart';
export 'src/database/database.dart';
export 'src/database/tables/catalog_tables.dart';
export 'src/database/tables/counter_table.dart';
export 'src/database/tables/customer_table.dart';
export 'src/database/tables/purchase_order_tables.dart';
export 'src/database/tables/sales_tables.dart';
export 'src/database/tables/staff_table.dart';
export 'src/database/tables/till_tables.dart';
export 'src/domain/models/permission.dart';
export 'src/domain/services/auth_service.dart';
export 'src/domain/services/inventory_service.dart';
export 'src/domain/services/receipt_formatter.dart';
export 'src/domain/services/sale_service.dart';
export 'src/domain/services/sales_calculator.dart';
export 'src/domain/services/till_service.dart';
export 'src/utils/money.dart';
export 'src/utils/password_hasher.dart';
