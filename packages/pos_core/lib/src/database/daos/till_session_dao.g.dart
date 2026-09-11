// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'till_session_dao.dart';

// ignore_for_file: type=lint
mixin _$TillSessionDaoMixin on DatabaseAccessor<PosDatabase> {
  $StaffTable get staff => attachedDatabase.staff;
  $TillSessionsTable get tillSessions => attachedDatabase.tillSessions;
  TillSessionDaoManager get managers => TillSessionDaoManager(this);
}

class TillSessionDaoManager {
  final _$TillSessionDaoMixin _db;
  TillSessionDaoManager(this._db);
  $$StaffTableTableManager get staff =>
      $$StaffTableTableManager(_db.attachedDatabase, _db.staff);
  $$TillSessionsTableTableManager get tillSessions =>
      $$TillSessionsTableTableManager(_db.attachedDatabase, _db.tillSessions);
}
