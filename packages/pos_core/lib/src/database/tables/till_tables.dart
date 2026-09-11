import 'package:drift/drift.dart';

import 'staff_table.dart';

enum TillSessionStatus { open, closed }

/// A cash-drawer session: opened with a counted float, closed with a
/// physical cash count reconciled against the expected (float + cash sales
/// - cash refunds) figure. [varianceKobo] is counted - expected; negative
/// means the drawer is short.
class TillSessions extends Table {
  TextColumn get id => text()();
  TextColumn get staffId => text().references(Staff, #id)();
  DateTimeColumn get openedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get closedAt => dateTime().nullable()();
  IntColumn get openingFloatKobo => integer()();
  IntColumn get expectedCashKobo => integer().nullable()();
  IntColumn get countedCashKobo => integer().nullable()();
  IntColumn get varianceKobo => integer().nullable()();
  TextColumn get status => textEnum<TillSessionStatus>()
      .withDefault(Constant(TillSessionStatus.open.name))();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Staff attendance/clock-in record. Distinct from [TillSessions] because a
/// staff member's shift may not involve operating a till (e.g. stock clerk),
/// and a till session should be traceable to the shift it happened under.
class Shifts extends Table {
  TextColumn get id => text()();
  TextColumn get staffId => text().references(Staff, #id)();
  TextColumn get tillSessionId =>
      text().nullable().references(TillSessions, #id)();
  DateTimeColumn get clockInAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get clockOutAt => dateTime().nullable()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
