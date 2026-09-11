import 'package:pos_core/pos_core.dart';

/// Every screen in this app talks to the database through one of these
/// four services instead of writing SQL/Drift code itself. There is
/// exactly one [Services] object for the whole app, created once in
/// `main()` and handed to every widget via `provider`.
///
/// If you're new to this codebase: whenever you need to read or change
/// data (add a product, complete a sale, open the till...), look here
/// first. `db` is the raw database — most screens use the *services*
/// below instead of `db` directly, but `db` is there for read-only
/// queries (the DAOs) that don't need any business-rule checking.
class Services {
  Services(this.db)
      : auth = AuthService(db.staffDao),
        inventory = InventoryService(db),
        sales = SaleService(db),
        till = TillService(db);

  final PosDatabase db;
  final AuthService auth;
  final InventoryService inventory;
  final SaleService sales;
  final TillService till;
}
