import 'package:flutter/foundation.dart';
import 'package:pos_core/pos_core.dart';

import '../services.dart';

/// Keeps track of who is currently logged in at this till.
///
/// This is a [ChangeNotifier]: it holds a value (`currentStaff`) and calls
/// `notifyListeners()` whenever that value changes. Any widget wrapped in a
/// `Consumer<AuthController>` (or using `context.watch<AuthController>()`)
/// automatically rebuilds when that happens — that's the whole trick behind
/// the `provider` package.
class AuthController extends ChangeNotifier {
  AuthController(this._services);

  final Services _services;

  /// Null means nobody is logged in — the app should show the login screen.
  StaffData? currentStaff;

  /// Tries to log in with a username and password.
  /// Returns null on success, or an error message to show the user.
  Future<String?> loginWithPassword(String username, String password) async {
    final result = await _services.auth
        .loginWithPassword(username: username, password: password);
    if (result is AuthSuccess) {
      currentStaff = result.staff;
      notifyListeners();
      return null;
    }
    return (result as AuthFailure).reason;
  }

  /// Tries every active staff member's PIN until one matches `pin`.
  /// Returns null on success, or an error message to show the user.
  Future<String?> loginWithPin(String pin) async {
    final candidates = await _services.db.staffDao.allActive();
    for (final staff in candidates) {
      if (staff.pinHash == null) continue;
      final result =
          await _services.auth.loginWithPin(staffId: staff.id, pin: pin);
      if (result is AuthSuccess) {
        currentStaff = result.staff;
        notifyListeners();
        return null;
      }
    }
    return 'Incorrect PIN';
  }

  void logout() {
    currentStaff = null;
    notifyListeners();
  }
}
