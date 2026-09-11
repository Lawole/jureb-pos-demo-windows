import 'package:pos_core/pos_core.dart';
import 'package:test/test.dart';

void main() {
  group('PasswordHasher', () {
    test('verifies a correct password', () {
      final hash = PasswordHasher.hash('correct-horse-battery-staple');
      expect(PasswordHasher.verify('correct-horse-battery-staple', hash), isTrue);
    });

    test('rejects an incorrect password', () {
      final hash = PasswordHasher.hash('correct-horse-battery-staple');
      expect(PasswordHasher.verify('wrong-password', hash), isFalse);
    });

    test('same input hashes differently each time (random salt)', () {
      final a = PasswordHasher.hash('0000');
      final b = PasswordHasher.hash('0000');
      expect(a, isNot(equals(b)));
      expect(PasswordHasher.verify('0000', a), isTrue);
      expect(PasswordHasher.verify('0000', b), isTrue);
    });

    test('rejects a malformed stored hash instead of throwing', () {
      expect(PasswordHasher.verify('anything', 'not-a-valid-hash'), isFalse);
    });

    test('4-digit PIN hashing works like a password', () {
      final hash = PasswordHasher.hash('4821');
      expect(PasswordHasher.verify('4821', hash), isTrue);
      expect(PasswordHasher.verify('4820', hash), isFalse);
    });
  });
}
