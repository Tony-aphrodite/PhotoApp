import 'package:flutter_test/flutter_test.dart';
import 'package:servitec_app/data/models/admin_flag_model.dart';

/// The moderation queue is fed by five different Cloud Functions that do not
/// share a document shape, so the model has to absorb the differences. These
/// tests pin the labels the admin sees and the legacy-field fallbacks.
void main() {
  group('tipoLabel', () {
    test('names every type the backend writes', () {
      const cases = {
        AdminFlagModel.typeContactLeak: 'Intento de contacto fuera de la app',
        AdminFlagModel.typeNoTechnician: 'Sin técnicos disponibles',
        AdminFlagModel.typeCfdiDeferred:
            'CFDI pendiente — técnico sin datos fiscales',
        AdminFlagModel.typeCfdiFailed: 'Falló la generación del CFDI',
        AdminFlagModel.typeCommissionCfdiFailed:
            'Falló el CFDI de comisión mensual',
      };
      for (final entry in cases.entries) {
        final flag = AdminFlagModel(
          id: 'f',
          type: entry.key,
          estado: AdminFlagModel.estadoPendiente,
          createdAt: DateTime(2026, 9, 1),
        );
        expect(flag.tipoLabel, entry.value);
      }
    });

    test('falls back to the raw type for an unknown producer', () {
      final flag = AdminFlagModel(
        id: 'f',
        type: 'algo_nuevo',
        estado: AdminFlagModel.estadoPendiente,
        createdAt: DateTime(2026, 9, 1),
      );
      expect(flag.tipoLabel, 'algo_nuevo');
    });
  });

  group('motivoLabel — what the filter actually detected', () {
    AdminFlagModel withReason(String? reason) => AdminFlagModel(
          id: 'f',
          type: AdminFlagModel.typeContactLeak,
          estado: AdminFlagModel.estadoPendiente,
          createdAt: DateTime(2026, 9, 1),
          reason: reason,
        );

    test('maps each detector to Spanish', () {
      expect(withReason('phone').motivoLabel, 'Número telefónico');
      expect(withReason('email').motivoLabel, 'Correo electrónico');
      expect(withReason('externalLink').motivoLabel,
          'Enlace de WhatsApp o Telegram');
      expect(withReason('bypassKeyword').motivoLabel,
          'Mención de pago o contacto por fuera');
    });

    test('degrades gracefully when the reason is missing', () {
      expect(withReason(null).motivoLabel, '—');
    });
  });

  group('classification', () {
    test('separates moderation from backend failures', () {
      AdminFlagModel of(String type) => AdminFlagModel(
            id: 'f',
            type: type,
            estado: AdminFlagModel.estadoPendiente,
            createdAt: DateTime(2026, 9, 1),
          );
      expect(of(AdminFlagModel.typeContactLeak).isModeration, isTrue);
      expect(of(AdminFlagModel.typeCfdiFailed).isModeration, isFalse);
      expect(of(AdminFlagModel.typeNoTechnician).isModeration, isFalse);
    });

    test('a flag without an explicit estado counts as pending', () {
      // Flags written before the review state shipped must still surface, or
      // the admin silently loses the backlog.
      final flag = AdminFlagModel(
        id: 'f',
        type: AdminFlagModel.typeContactLeak,
        estado: AdminFlagModel.estadoPendiente,
        createdAt: DateTime(2026, 9, 1),
      );
      expect(flag.isPendiente, isTrue);
    });
  });
}
