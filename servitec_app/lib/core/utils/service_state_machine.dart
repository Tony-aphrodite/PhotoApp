import '../constants/app_constants.dart';

class ServiceStateMachine {
  ServiceStateMachine._();

  static const Map<String, List<String>> _validTransitions = {
    AppConstants.statusPending: [
      AppConstants.statusAssigned,
      AppConstants.statusCancelled,
    ],
    AppConstants.statusAssigned: [
      AppConstants.statusInProgress,
      AppConstants.statusCancelled,
    ],
    AppConstants.statusInProgress: [
      AppConstants.statusCompleted,
      AppConstants.statusCancelled,
    ],
    AppConstants.statusCompleted: [
      AppConstants.statusPaymentPending,
    ],
    AppConstants.statusPaymentPending: [
      AppConstants.statusPaid,
    ],
    AppConstants.statusPaid: [],
    AppConstants.statusCancelled: [],
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
