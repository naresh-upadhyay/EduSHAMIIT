import 'package:flutter_test/flutter_test.dart';
import 'package:edu_shamiit_core/utils/validators.dart';

void main() {
  group('Full Name Validator Tests', () {
    test('Valid names pass validation', () {
      expect(Validators.validateFullName('Dr. Rajesh Shami'), isNull);
      expect(Validators.validateFullName('Mary-Jane Watson'), isNull);
      expect(Validators.validateFullName("Liam O'Connor"), isNull);
      expect(Validators.validateFullName('Amit Kumar'), isNull);
    });

    test('Invalid names fail validation', () {
      expect(Validators.validateFullName(''), isNotNull);
      expect(Validators.validateFullName('   '), isNotNull);
      expect(Validators.validateFullName('A'), isNotNull);
      expect(Validators.validateFullName('123456'), isNotNull);
      expect(Validators.validateFullName('@@@@@@'), isNotNull);
    });
  });

  group('Email Validator Tests', () {
    test('Valid email addresses pass validation', () {
      expect(Validators.validateEmail('user@gmail.com'), isNull);
      expect(Validators.validateEmail('john.doe@school.edu'), isNull);
      expect(Validators.validateEmail('admin+test@shamiit.com'), isNull);
    });

    test('Invalid email addresses fail validation', () {
      expect(Validators.validateEmail(''), isNotNull);
      expect(Validators.validateEmail('user'), isNotNull);
      expect(Validators.validateEmail('user@'), isNotNull);
      expect(Validators.validateEmail('@gmail.com'), isNotNull);
      expect(Validators.validateEmail('user @gmail.com'), isNotNull);
    });
  });

  group('Indian 10-Digit Mobile Phone Validator Tests', () {
    test('Valid Indian 10-digit mobile numbers pass', () {
      expect(Validators.validatePhone('9876543210'), isNull);
      expect(Validators.validatePhone('8123456789'), isNull);
      expect(Validators.validatePhone('7012345678'), isNull);
      expect(Validators.validatePhone('6398765432'), isNull);
    });

    test('Invalid mobile numbers fail', () {
      expect(Validators.validatePhone(''), isNotNull);
      expect(Validators.validatePhone('1234567890'), isNotNull); // Doesn't start with 6-9
      expect(Validators.validatePhone('5123456789'), isNotNull); // Doesn't start with 6-9
      expect(Validators.validatePhone('987654321'), isNotNull);  // 9 digits
      expect(Validators.validatePhone('98765432101'), isNotNull); // 11 digits
    });
  });

  group('Password Policy Requirements Tests', () {
    test('Password requirements checking works', () {
      final weak = PasswordRequirements.check('hello');
      expect(weak.hasMin8Chars, isFalse);
      expect(weak.hasUppercase, isFalse);
      expect(weak.hasLowercase, isTrue);
      expect(weak.hasNumber, isFalse);
      expect(weak.hasSpecialChar, isFalse);
      expect(weak.isStrong, isFalse);

      final strong = PasswordRequirements.check('Hello@123');
      expect(strong.hasMin8Chars, isTrue);
      expect(strong.hasUppercase, isTrue);
      expect(strong.hasLowercase, isTrue);
      expect(strong.hasNumber, isTrue);
      expect(strong.hasSpecialChar, isTrue);
      expect(strong.isStrong, isTrue);
    });
  });

  group('Confirm Password Tests', () {
    test('Matching passwords pass', () {
      expect(Validators.validateConfirmPassword('Hello@123', 'Hello@123'), isNull);
    });

    test('Mismatching passwords fail', () {
      expect(Validators.validateConfirmPassword('Hello@123', 'Hello@1234'), isNotNull);
      expect(Validators.validateConfirmPassword('', 'Hello@123'), isNotNull);
    });
  });
}
