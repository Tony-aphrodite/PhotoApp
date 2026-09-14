import 'package:flutter_test/flutter_test.dart';
import 'package:servitec_app/core/utils/registration_validators.dart';

void main() {
  group('normalizeMxPhone', () {
    test('keeps a plain 10-digit number', () {
      expect(RegistrationValidators.normalizeMxPhone('5512345678'), '5512345678');
    });

    test('strips formatting', () {
      expect(RegistrationValidators.normalizeMxPhone('(55) 1234-5678'), '5512345678');
      expect(RegistrationValidators.normalizeMxPhone('55 1234 5678'), '5512345678');
    });

    test('drops the country prefix in every common spelling', () {
      expect(RegistrationValidators.normalizeMxPhone('+52 55 1234 5678'), '5512345678');
      expect(RegistrationValidators.normalizeMxPhone('525512345678'), '5512345678');
      expect(RegistrationValidators.normalizeMxPhone('+52 1 55 1234 5678'), '5512345678');
    });

    test('rejects the 11-digit number from the QA report', () {
      expect(RegistrationValidators.normalizeMxPhone('83312345688'), isNull);
    });

    test('rejects too short, too long and impossible area codes', () {
      expect(RegistrationValidators.normalizeMxPhone('551234567'), isNull);
      expect(RegistrationValidators.normalizeMxPhone('551234567890'), isNull);
      expect(RegistrationValidators.normalizeMxPhone('0512345678'), isNull);
      expect(RegistrationValidators.normalizeMxPhone('1512345678'), isNull);
    });
  });

  group('email', () {
    test('accepts real-world addresses', () {
      expect(RegistrationValidators.email('dgallardoc@outlook.com'), isNull);
      expect(RegistrationValidators.email('nombre+prueba@empresa.com.mx'), isNull);
      expect(RegistrationValidators.email('  a.b@c.io  '), isNull);
    });

    test('rejects the typos the old "contains @" check let through', () {
      expect(RegistrationValidators.email('a@'), isNotNull);
      expect(RegistrationValidators.email('a@b'), isNotNull);
      expect(RegistrationValidators.email('@b.com'), isNotNull);
      expect(RegistrationValidators.email('a b@c.com'), isNotNull);
      expect(RegistrationValidators.email('a@@c.com'), isNotNull);
    });
  });

  group('name', () {
    test('accepts accented and compound names', () {
      for (final n in ['María José', 'Núñez', "O'Connor", 'Sánchez-Vega', 'Ma. Elena']) {
        expect(RegistrationValidators.name(n), isNull, reason: n);
      }
    });

    test('rejects digits, symbols and single letters', () {
      expect(RegistrationValidators.name('Juan3'), isNotNull);
      expect(RegistrationValidators.name('@@'), isNotNull);
      expect(RegistrationValidators.name('J'), isNotNull);
      expect(RegistrationValidators.name('   '), isNotNull);
    });
  });
}
