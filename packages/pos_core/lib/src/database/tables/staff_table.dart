import 'package:drift/drift.dart';

/// Fixed set of roles for RBAC. Kept as a Dart enum (not a DB table) because
/// permissions are hard-coded per role in [Role] — there is no product need
/// for admins to define custom roles, and an enum gives compile-time safety
/// everywhere role checks happen.
enum StaffRole { admin, manager, cashier }

class Staff extends Table {
  TextColumn get id => text()();
  TextColumn get fullName => text().withLength(min: 1, max: 100)();

  /// Optional: staff can log in with username+password, PIN, or both.
  TextColumn get username => text().nullable().unique()();
  TextColumn get passwordHash => text().nullable()();

  /// Short numeric PIN for fast till login, hashed the same as passwords.
  TextColumn get pinHash => text().nullable()();

  TextColumn get role => textEnum<StaffRole>()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
