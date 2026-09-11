import 'package:drift/drift.dart';

/// Tiny key/value counter table, currently used only for the sequential
/// receipt number. A single row per key is read-modify-written inside a
/// transaction so two tills opened at once (or a retry after a crash)
/// never hand out the same number.
class Counters extends Table {
  TextColumn get key => text()();
  IntColumn get value => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {key};
}
