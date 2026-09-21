import '../constants/app_constants.dart';

class ServiceStateMachine {
  ServiceStateMachine._();

  // Only the transitions the app itself may perform — cancelling before work
  // starts. Everything else in the quotation and work flow is decided by
  // Cloud Functions (service-flow.ts); admins assign through
  // ServiceRepository.assignTechnician.
  static const Map<String, List<String>> _validTransitions = {
    AppConstants.statusPending: [
      AppConstants.statusAssigned,
      AppConstants.statusCancelled,
    ],
    AppConstants.statusAssigned: [AppConstants.statusCancelled],
    AppConstants.statusQuoteSent: [AppConstants.statusCancelled],
    AppConstants.statusQuoteRejected: [AppConstants.statusCancelled],
    AppConstants.statusQuoteApproved: [AppConstants.statusCancelled],
  };

  /// Whether the cliente (or an admin) may still cancel. Mirrors cancelar()
  /// in functions/src/visit-flow.ts, which every cancellation goes through.
  static bool canCancel(String estado, {bool diagnostic = false}) =>
      diagnostic ? _diagnosticCancellable.contains(estado) : canTransition(estado, AppConstants.statusCancelled);

  static const _diagnosticCancellable = {
    AppConstants.statusPending,
    AppConstants.statusAssigned,
    AppConstants.statusVisitProposed,
    AppConstants.statusVisitConfirmed,
    AppConstants.statusOnTheWay,
    AppConstants.statusDiagnosed,
    AppConstants.statusQuoteSent,
    AppConstants.statusQuoteRejected,
  };

  static bool canTransition(String from, String to) {
    final allowed = _validTransitions[from];
    if (allowed == null) return false;
    return allowed.contains(to);
  }

  static List<String> getNextStates(String currentState) {
    return _validTransitions[currentState] ?? [];
  }

  static String? validateTransition(String from, String to) {
    if (!canTransition(from, to)) {
      return 'No se puede cambiar de "$from" a "$to"';
    }
    return null;
  }
}
