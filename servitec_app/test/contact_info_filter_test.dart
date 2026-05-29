import 'package:flutter_test/flutter_test.dart';
import 'package:servitec_app/core/utils/contact_info_filter.dart';

void main() {
  group('ContactInfoFilter.scan — clean messages return null', () {
    final cleanCases = <String, String>{
      'Hola, llego en 20 minutos': 'normal greeting',
      'Necesito 3 metros de cable': 'numbers but not phone-shaped',
      'Cost: 1500 pesos for the parts': 'short number sequence (4 digits)',
      'OK perfecto, nos vemos manana': 'plain Spanish text',
      'Pieza modelo XR-2034 disponible': 'model number (4 digits)',
      '': 'empty string',
      '   ': 'whitespace only',
    };

    for (final entry in cleanCases.entries) {
      test(entry.value, () {
        expect(ContactInfoFilter.scan(entry.key), isNull);
      });
    }
  });

  group('ContactInfoFilter.scan — phone numbers', () {
    final phoneCases = <String, String>{
      'Mi numero es 5512345678': 'MX 10-digit cell',
      'Llamame al +52 55 1234 5678': 'international with spaces',
      '55-1234-5678': 'dashed format',
      '(55) 1234 5678': 'parens format',
      'Hablame: 5 5 1 2 3 4 5 6 7 8': 'spaced digits',
      'Tel 5512345678 disponible': 'phone embedded in sentence',
    };

    for (final entry in phoneCases.entries) {
      test(entry.value, () {
        final v = ContactInfoFilter.scan(entry.key);
        expect(v, isNotNull);
        expect(v!.reason, ContactViolationReason.phone);
      });
    }
  });

  group('ContactInfoFilter.scan — emails', () {
    test('Gmail address', () {
      final v = ContactInfoFilter.scan('Mandame correo a juan@gmail.com');
      expect(v?.reason, ContactViolationReason.email);
    });

    test('Complex email with subdomain and plus tag', () {
      final v = ContactInfoFilter.scan('contacto: ana.lopez+work@example.co.mx');
      expect(v?.reason, ContactViolationReason.email);
    });
  });

  group('ContactInfoFilter.scan — external links', () {
    final linkCases = <String, String>{
      'Escribeme en wa.me/525512345678': 'wa.me link',
      'https://api.whatsapp.com/send?phone=52': 'api.whatsapp.com',
      'Mi grupo: chat.whatsapp.com/abc': 'chat.whatsapp.com',
      'Mandame en t.me/mychannel': 't.me link',
      'telegram.me/handle': 'telegram.me',
      'WA.ME/52551234': 'case-insensitive WhatsApp',
    };

    for (final entry in linkCases.entries) {
      test(entry.value, () {
        final v = ContactInfoFilter.scan(entry.key);
        expect(v?.reason, ContactViolationReason.externalLink);
      });
    }
  });

  group('ContactInfoFilter.scan — bypass keywords', () {
    final bypassCases = <String, String>{
      'Mejor por whatsapp': 'whatsapp word',
      'Mejor por whats app': 'whats app spaced',
      'Mandame wasap': 'wasap slang',
      'Te paso por guasap': 'guasap slang',
      'Mejor un wapp': 'wapp slang',
      'Hablamos por telegram': 'telegram word',
      'Mejor en messenger': 'messenger',
      'Lo arreglamos fuera de la app': 'fuera de la app',
      'Pagame por fuera': 'por fuera',
      'Hagamos transferencia directa': 'transferencia',
      'Sin la app sale mas barato': 'sin la app',
      'Vamos sin servitec': 'sin servitec',
    };

    for (final entry in bypassCases.entries) {
      test(entry.value, () {
        final v = ContactInfoFilter.scan(entry.key);
        expect(v?.reason, ContactViolationReason.bypassKeyword);
      });
    }
  });

  group('ContactInfoFilter.scan — priority ordering', () {
    test('email takes priority over phone', () {
      final v = ContactInfoFilter.scan('juan@x.com 5512345678');
      expect(v?.reason, ContactViolationReason.email);
    });

    test('external link takes priority over phone', () {
      final v = ContactInfoFilter.scan('Llamame al 5512345678 o wa.me/52');
      expect(v?.reason, ContactViolationReason.externalLink);
    });
  });

  group('ContactViolation messages', () {
    test('every violation has a non-empty Spanish message', () {
      const samples = {
        'juan@x.com': ContactViolationReason.email,
        '5512345678': ContactViolationReason.phone,
        'wa.me/52': ContactViolationReason.externalLink,
        'mejor por whatsapp': ContactViolationReason.bypassKeyword,
      };
      for (final entry in samples.entries) {
        final v = ContactInfoFilter.scan(entry.key);
        expect(v, isNotNull);
        expect(v!.reason, entry.value);
        expect(v.message, isNotEmpty);
        expect(v.message.length, greaterThan(20));
      }
    });
  });
}
