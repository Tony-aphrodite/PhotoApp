import 'package:flutter_test/flutter_test.dart';
import 'package:servitec_app/core/constants/app_constants.dart';
import 'package:servitec_app/core/utils/phone_visibility.dart';

void main() {
  group('PhoneVisibility.resolve', () {
    test('hidden in pendiente', () {
      expect(PhoneVisibility.resolve(AppConstants.statusPending),
          PhoneVisibilityLevel.hidden);
    });

    test('hidden in asignado', () {
      expect(PhoneVisibility.resolve(AppConstants.statusAssigned),
          PhoneVisibilityLevel.hidden);
    });

    test('hidden in cancelado', () {
      expect(PhoneVisibility.resolve(AppConstants.statusCancelled),
          PhoneVisibilityLevel.hidden);
    });

    test('hidden for unknown status (safe default)', () {
      expect(PhoneVisibility.resolve('estado_inexistente'),
          PhoneVisibilityLevel.hidden);
    });

    test('masked in cotizacion_enviada', () {
      expect(PhoneVisibility.resolve('cotizacion_enviada'),
          PhoneVisibilityLevel.masked);
    });

    test('masked in en_reparacion', () {
      expect(PhoneVisibility.resolve('en_reparacion'),
          PhoneVisibilityLevel.masked);
    });

    test('revealed in en_progreso', () {
      expect(PhoneVisibility.resolve(AppConstants.statusInProgress),
          PhoneVisibilityLevel.revealed);
    });

    test('revealed in completado', () {
      expect(PhoneVisibility.resolve(AppConstants.statusCompleted),
          PhoneVisibilityLevel.revealed);
    });

    test('revealed in pago_pendiente', () {
      expect(PhoneVisibility.resolve(AppConstants.statusPaymentPending),
          PhoneVisibilityLevel.revealed);
    });

    test('revealed in pagado', () {
      expect(PhoneVisibility.resolve(AppConstants.statusPaid),
          PhoneVisibilityLevel.revealed);
    });
  });

  group('PhoneVisibility.display', () {
    const phone = '+525512345678';

    test('hidden status returns user-facing label, not the phone', () {
      final shown = PhoneVisibility.display(phone, AppConstants.statusPending);
      expect(shown, isNot(contains('5512345678')));
      expect(shown, equals('Disponible al iniciar el servicio'));
    });

    test('masked status hides middle digits, exposes last 2 only', () {
      final shown = PhoneVisibility.display(phone, 'cotizacion_enviada');
      expect(shown, isNot(contains('5512345678')));
      expect(shown, isNot(contains('1234')));
      // Last 2 digits of '+525512345678' are '78'
      expect(shown.endsWith('78'), isTrue);
      // Contains at least some mask character
      expect(shown.contains('•'), isTrue);
    });

    test('revealed status returns the original phone unchanged', () {
      final shown =
          PhoneVisibility.display(phone, AppConstants.statusInProgress);
      expect(shown, equals(phone));
    });

    test('masked still works when phone has formatting characters', () {
      final shown =
          PhoneVisibility.display('+52 (55) 1234-5678', 'cotizacion_enviada');
      expect(shown.endsWith('78'), isTrue);
      expect(shown, isNot(contains('1234')));
    });

    test('masked degrades gracefully on too-short phone', () {
      final shown = PhoneVisibility.display('12', 'cotizacion_enviada');
      expect(shown, equals('••••'));
    });
  });
}
