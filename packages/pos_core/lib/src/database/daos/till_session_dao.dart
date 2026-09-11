import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/till_tables.dart';

part 'till_session_dao.g.dart';

@DriftAccessor(tables: [TillSessions])
class TillSessionDao extends DatabaseAccessor<PosDatabase>
    with _$TillSessionDaoMixin {
  TillSessionDao(super.db);

  Future<TillSession?> findOpen() => (select(tillSessions)
        ..where((t) => t.status.equals(TillSessionStatus.open.name)))
      .getSingleOrNull();

  Stream<TillSession?> watchOpen() => (select(tillSessions)
        ..where((t) => t.status.equals(TillSessionStatus.open.name)))
      .watchSingleOrNull();

  Stream<List<TillSession>> watchRecent({int limit = 20}) =>
      (select(tillSessions)
            ..orderBy([(t) => OrderingTerm.desc(t.openedAt)])
            ..limit(limit))
          .watch();

  Future<TillSession?> findById(String id) =>
      (select(tillSessions)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertSession(TillSessionsCompanion entry) =>
      into(tillSessions).insert(entry);

  Future<void> closeSession(
    String id, {
    required int expectedCashKobo,
    required int countedCashKobo,
  }) =>
      (update(tillSessions)..where((t) => t.id.equals(id))).write(
        TillSessionsCompanion(
          status: const Value(TillSessionStatus.closed),
          closedAt: Value(DateTime.now()),
          expectedCashKobo: Value(expectedCashKobo),
          countedCashKobo: Value(countedCashKobo),
          varianceKobo: Value(countedCashKobo - expectedCashKobo),
        ),
      );
}
