import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/catalog_tables.dart';

part 'stock_movement_dao.g.dart';

@DriftAccessor(tables: [StockMovements])
class StockMovementDao extends DatabaseAccessor<PosDatabase>
    with _$StockMovementDaoMixin {
  StockMovementDao(super.db);

  Stream<List<StockMovement>> watchForProduct(String productId) =>
      (select(stockMovements)
            ..where((m) => m.productId.equals(productId))
            ..orderBy([(m) => OrderingTerm.desc(m.createdAt)]))
          .watch();

  Future<int> insertMovement(StockMovementsCompanion entry) =>
      into(stockMovements).insert(entry);
}
