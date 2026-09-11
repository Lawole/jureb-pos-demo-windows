import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../database/daos/staff_dao.dart';
import '../../database/database.dart';
import '../../database/tables/staff_table.dart';
import '../../utils/password_hasher.dart';
import '../models/permission.dart';

sealed class AuthResult {
  const AuthResult();
}

class AuthSuccess extends AuthResult {
  const AuthSuccess(this.staff);
  final StaffData staff;
}

class AuthFailure extends AuthResult {
  const AuthFailure(this.reason);
  final String reason;
}

/// Authenticates staff against the local database. Deliberately has no
/// network dependency — login must work with zero connectivity, which is
/// the normal operating condition for a Nigerian retail till.
class AuthService {
  AuthService(this._staffDao);

  final StaffDao _staffDao;
  static const _uuid = Uuid();

  Future<AuthResult> loginWithPassword({
    required String username,
    required String password,
  }) async {
    final staff = await _staffDao.findByUsername(username);
    if (staff == null || !staff.isActive) {
      return const AuthFailure('Invalid username or password');
    }
    if (staff.passwordHash == null ||
        !PasswordHasher.verify(password, staff.passwordHash!)) {
      return const AuthFailure('Invalid username or password');
    }
    return AuthSuccess(staff);
  }

  Future<AuthResult> loginWithPin({
    required String staffId,
    required String pin,
  }) async {
    final staff = await _staffDao.findById(staffId);
    if (staff == null || !staff.isActive) {
      return const AuthFailure('Staff not found');
    }
    if (staff.pinHash == null || !PasswordHasher.verify(pin, staff.pinHash!)) {
      return const AuthFailure('Incorrect PIN');
    }
    return AuthSuccess(staff);
  }

  /// Creates a new staff record. Requires at least one credential (password
  /// or PIN) so the account is actually loginable.
  Future<StaffData> createStaff({
    required String fullName,
    required StaffRole role,
    String? username,
    String? password,
    String? pin,
  }) async {
    if (password == null && pin == null) {
      throw ArgumentError('Staff must have a password or a PIN set');
    }
    final id = _uuid.v4();
    await _staffDao.insertStaff(StaffCompanion.insert(
      id: id,
      fullName: fullName,
      role: role,
      username: Value(username),
      passwordHash: Value(password == null ? null : PasswordHasher.hash(password)),
      pinHash: Value(pin == null ? null : PasswordHasher.hash(pin)),
    ));
    return (await _staffDao.findById(id))!;
  }

  /// Seeds a default administrator account on first run so the app is never
  /// unusable out of the box. The generated PIN is returned so the caller
  /// (setup wizard) can display it once for the owner to change.
  Future<StaffData?> seedDefaultAdminIfEmpty() async {
    if (await _staffDao.countAll() > 0) return null;
    return createStaff(
      fullName: 'Store Admin',
      role: StaffRole.admin,
      username: 'admin',
      password: 'admin123',
      pin: '0000',
    );
  }
}

extension StaffPermissions on StaffData {
  bool can(Permission permission) => role.can(permission);
}
