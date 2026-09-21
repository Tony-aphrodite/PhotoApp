import 'package:flutter_test/flutter_test.dart';
import 'package:servitec_app/core/constants/app_constants.dart';
import 'package:servitec_app/core/utils/phone_visibility.dart';
import 'package:servitec_app/core/utils/service_state_machine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:servitec_app/data/models/service_model.dart';
import 'package:servitec_app/data/models/visit_info.dart';
import 'package:servitec_app/data/models/work_stop.dart';

void main() {
  group('stage groups', () {
    test('every flow state belongs to exactly one stage', () {
      final all = [
        ...AppConstants.preWorkStates,
        ...AppConstants.workStates,
        ...AppConstants.doneStates,
      ];
      expect(all.toSet().length, all.length, reason: 'a state is in two stages');
      for (final s in [
        AppConstants.statusAssigned,
        AppConstants.statusQuoteSent,
        AppConstants.statusQuoteRejected,
        AppConstants.statusQuoteApproved,
        AppConstants.statusInProgress,
        AppConstants.statusRevisionSent,
        AppConstants.statusRevisionRejected,
        AppConstants.statusStopped,
        AppConstants.statusDisputed,
        AppConstants.statusCompleted,
        AppConstants.statusPaid,
      ]) {
        expect(all, contains(s));
      }
    });

    test('stage groups fit a Firestore whereIn (max 30)', () {
      expect(AppConstants.workStates.length, lessThanOrEqualTo(30));
    });
  });

  group('cancelling', () {
    test('allowed until work starts', () {
      for (final s in [
        AppConstants.statusPending,
        AppConstants.statusAssigned,
        AppConstants.statusQuoteSent,
        AppConstants.statusQuoteRejected,
        AppConstants.statusQuoteApproved,
      ]) {
        expect(ServiceStateMachine.canCancel(s), isTrue, reason: s);
      }
    });

    test('not allowed once work has started or finished', () {
      for (final s in [
        AppConstants.statusInProgress,
        AppConstants.statusRevisionSent,
        AppConstants.statusRevisionRejected,
        AppConstants.statusStopped,
        AppConstants.statusDisputed,
        AppConstants.statusCompleted,
        AppConstants.statusPaid,
        AppConstants.statusCancelled,
      ]) {
        expect(ServiceStateMachine.canCancel(s), isFalse, reason: s);
      }
    });
  });

  group('diagnostic flow', () {
    test('cancellable until the repair is approved, via the server', () {
      for (final s in [
        AppConstants.statusVisitProposed,
        AppConstants.statusVisitConfirmed,
        AppConstants.statusOnTheWay,
        AppConstants.statusDiagnosed,
        AppConstants.statusQuoteSent,
      ]) {
        expect(ServiceStateMachine.canCancel(s, diagnostic: true), isTrue, reason: s);
      }
      for (final s in [
        AppConstants.statusQuoteApproved,
        AppConstants.statusInProgress,
        AppConstants.statusNoShowReported,
        AppConstants.statusPaid,
      ]) {
        expect(ServiceStateMachine.canCancel(s, diagnostic: true), isFalse, reason: s);
      }
    });

    test('visit states sit in the right stages', () {
      expect(AppConstants.preWorkStates, contains(AppConstants.statusVisitConfirmed));
      expect(AppConstants.workStates, contains(AppConstants.statusOnTheWay));
      expect(PhoneVisibility.resolve(AppConstants.statusVisitProposed), PhoneVisibilityLevel.masked);
      expect(PhoneVisibility.resolve(AppConstants.statusOnTheWay), PhoneVisibilityLevel.revealed);
    });

    test('amount due credits the visit and treats it as the minimum', () {
      ServiceModel svc(double total, {bool charged = true}) => ServiceModel(
            id: 's', clienteId: 'c', clienteNombre: '', clienteTelefono: '',
            titulo: '', descripcion: '', categoria: 'plomeria', urgencia: 'normal',
            ubicacion: const GeoPoint(0, 0), ubicacionTexto: '', fotos: const [],
            estado: AppConstants.statusCompleted, tipoAsignacion: 'automatica',
            createdAt: DateTime(2026), updatedAt: DateTime(2026),
            costoFinal: total, flujo: 'diagnostico',
            visita: VisitInfo(precio: 400, montoCobrado: 400,
                pagoEstado: charged ? 'cobrado' : 'retenido'),
          );
      expect(svc(1500).amountDue, 1100);
      expect(svc(300).amountDue, 0);
      expect(svc(1500, charged: false).amountDue, 1500, reason: 'nothing credited until charged');
    });
  });

  group('phone visibility across the flow', () {
    test('masked while quoting', () {
      for (final s in [
        AppConstants.statusQuoteSent,
        AppConstants.statusQuoteRejected,
        AppConstants.statusQuoteApproved,
      ]) {
        expect(PhoneVisibility.resolve(s), PhoneVisibilityLevel.masked, reason: s);
      }
    });

    test('revealed once work started, including revisions and stops', () {
      for (final s in AppConstants.workStates) {
        expect(PhoneVisibility.resolve(s), PhoneVisibilityLevel.revealed, reason: s);
      }
    });
  });

  group('WorkStop.fromMap', () {
    test('parses the server document', () {
      final stop = WorkStop.fromMap({
        'motivo': 'riesgo_seguridad',
        'descripcion': 'Cableado expuesto',
        'fotos': ['https://x/1.jpg'],
        'montoPropuesto': 500,
        'montoAprobadoPrevio': 1200.5,
        'respuestaCliente': 'disputada',
      })!;
      expect(stop.motivoLabel, 'Riesgo de seguridad');
      expect(stop.montoPropuesto, 500.0);
      expect(stop.montoAprobadoPrevio, 1200.5);
      expect(stop.fotos, hasLength(1));
      expect(stop.respuestaCliente, 'disputada');
    });

    test('absent or malformed means no stop', () {
      expect(WorkStop.fromMap(null), isNull);
      expect(WorkStop.fromMap('x'), isNull);
    });
  });
}
