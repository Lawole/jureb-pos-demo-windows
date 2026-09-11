import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/counter_table.dart';

part 'counter_dao.g.dart';

@DriftAccessor(tables: [Counters])
class CounterDao extends DatabaseAccessor<PosDatabase> with _$CounterDaoMixin {
  CounterDao(super.db);

  /// Atomically increments and returns the next value for [key], starting
  /// at 1. Must be called from inside the caller's transaction so the
  /// read-modify-write can't race with a concurrent sale.
  Future<int> next(String key) async {
    final existing =
        await (select(counters)..where((c) => c.key.equals(key)))
            .getSingleOrNull();
    final nextValue = (existing?.value ?? 0) + 1;
    await into(counters).insertOnConflictUpdate(
      CountersCompanion.insert(key: key, value: Value(nextValue)),
    );
    return nextValue;
  }
}
