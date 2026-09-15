import 'package:flutter_test/flutter_test.dart';
import 'package:servitec_app/core/constants/app_constants.dart';
import 'package:servitec_app/core/utils/phone_visibility.dart';
import 'package:servitec_app/core/utils/service_state_machine.dart';
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
