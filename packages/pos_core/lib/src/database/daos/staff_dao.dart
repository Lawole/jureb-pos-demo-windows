import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/staff_table.dart';

part 'staff_dao.g.dart';

@DriftAccessor(tables: [Staff])
class StaffDao extends DatabaseAccessor<PosDatabase> with _$StaffDaoMixin {
  StaffDao(super.db);

  Future<StaffData?> findByUsername(String username) =>
      (select(staff)..where((s) => s.username.equals(username)))
          .getSingleOrNull();

  Future<StaffData?> findById(String id) =>
      (select(staff)..where((s) => s.id.equals(id))).getSingleOrNull();

  Future<List<StaffData>> allActive() =>
      (select(staff)..where((s) => s.isActive.equals(true))).get();

  /// True active staff with a PIN set, for the PIN-pad login list.
  Stream<List<StaffData>> watchPinLoginCandidates() => (select(staff)
        ..where((s) => s.isActive.equals(true) & s.pinHash.isNotNull()))
      .watch();

  Future<int> insertStaff(StaffCompanion entry) => into(staff).insert(entry);

  Future<bool> updateStaff(StaffCompanion entry) => update(staff).replace(entry);

  Future<int> countAll() => select(staff).get().then((rows) => rows.length);
}
