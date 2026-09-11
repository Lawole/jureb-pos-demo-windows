import 'package:drift/native.dart';
import 'package:pos_core/pos_core.dart';
import 'package:test/test.dart';

void main() {
  late PosDatabase db;
  late AuthService auth;

  setUp(() {
    db = PosDatabase.forTesting(NativeDatabase.memory());
    auth = AuthService(db.staffDao);
  });

  tearDown(() => db.close());

  group('AuthService', () {
    test('seeds a default admin only when staff table is empty', () async {
      final seeded = await auth.seedDefaultAdminIfEmpty();
      expect(seeded, isNotNull);
      expect(seeded!.role, StaffRole.admin);

      final seededAgain = await auth.seedDefaultAdminIfEmpty();
      expect(seededAgain, isNull, reason: 'must not double-seed');

      expect(await db.staffDao.countAll(), 1);
    });

    test('logs in with correct username/password', () async {
      await auth.createStaff(
        fullName: 'Amaka Okafor',
        role: StaffRole.manager,
        username: 'amaka',
        password: 'secret123',
      );

      final result =
          await auth.loginWithPassword(username: 'amaka', password: 'secret123');
      expect(result, isA<AuthSuccess>());
      expect((result as AuthSuccess).staff.fullName, 'Amaka Okafor');
    });

    test('rejects wrong password', () async {
      await auth.createStaff(
        fullName: 'Amaka Okafor',
        role: StaffRole.manager,
        username: 'amaka',
        password: 'secret123',
      );

      final result =
          await auth.loginWithPassword(username: 'amaka', password: 'wrong');
      expect(result, isA<AuthFailure>());
    });

    test('rejects login for an unknown username', () async {
      final result = await auth.loginWithPassword(
          username: 'ghost', password: 'whatever');
      expect(result, isA<AuthFailure>());
    });

    test('rejects login for a deactivated staff member', () async {
      final staff = await auth.createStaff(
        fullName: 'Tunde Bello',
        role: StaffRole.cashier,
        username: 'tunde',
        password: 'pass1234',
      );
      await db.staffDao.updateStaff(staff.copyWith(isActive: false).toCompanion(true));

      final result =
          await auth.loginWithPassword(username: 'tunde', password: 'pass1234');
      expect(result, isA<AuthFailure>());
    });

    test('logs in with a PIN', () async {
      final staff = await auth.createStaff(
        fullName: 'Chidi Cashier',
        role: StaffRole.cashier,
        pin: '1234',
      );

      final result = await auth.loginWithPin(staffId: staff.id, pin: '1234');
      expect(result, isA<AuthSuccess>());
    });

    test('rejects an incorrect PIN', () async {
      final staff = await auth.createStaff(
        fullName: 'Chidi Cashier',
        role: StaffRole.cashier,
        pin: '1234',
      );

      final result = await auth.loginWithPin(staffId: staff.id, pin: '9999');
      expect(result, isA<AuthFailure>());
    });

    test('creating staff without password or PIN throws', () {
      expect(
        () => auth.createStaff(fullName: 'No Credentials', role: StaffRole.cashier),
        throwsArgumentError,
      );
    });
  });

  group('Role-based permissions', () {
    test('admin can manage staff, cashier cannot', () {
      expect(StaffRole.admin.can(Permission.manageStaff), isTrue);
      expect(StaffRole.cashier.can(Permission.manageStaff), isFalse);
    });

    test('cashier can make sales and open/close till', () {
      expect(StaffRole.cashier.can(Permission.makeSale), isTrue);
      expect(StaffRole.cashier.can(Permission.openCloseTill), isTrue);
    });

    test('only admin and manager can process refunds', () {
      expect(StaffRole.admin.can(Permission.processRefund), isTrue);
      expect(StaffRole.manager.can(Permission.processRefund), isTrue);
      expect(StaffRole.cashier.can(Permission.processRefund), isFalse);
    });

    test('manager cannot manage staff (admin-only)', () {
      expect(StaffRole.manager.can(Permission.manageStaff), isFalse);
    });
  });
}
