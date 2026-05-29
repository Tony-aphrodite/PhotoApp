import '../constants/app_constants.dart';

/// Single source of truth for when the client's phone number is exposed to
/// the technician/admin in the UI.
///
/// Note: this is a UI-layer mask only. The phone field remains in the service
/// document, so any client with read access still sees the raw value. The real
/// boundary must be a Firestore security rule (or a separate `service_private`
/// doc) — tracked in 5-29.md section 4.
class PhoneVisibility {
  PhoneVisibility._();

  /// Returns the visibility level for a given service status.
  static PhoneVisibilityLevel resolve(String estado) {
    switch (estado) {
      case AppConstants.statusInProgress:
      case AppConstants.statusCompleted:
      case AppConstants.statusPaymentPending:
      case AppConstants.statusPaid:
        return PhoneVisibilityLevel.revealed;
      // Quotation flow states (defined as raw strings in quotation screens —
      // not in AppConstants yet). Phone is masked once the client has at least
      // received a quotation, signalling commitment to the platform.
      case 'cotizacion_enviada':
      case 'en_reparacion':
        return PhoneVisibilityLevel.masked;
      default:
        return PhoneVisibilityLevel.hidden;
    }
  }

  /// Renders the phone for display based on the visibility level.
  static String display(String phone, String estado) {
    final level = resolve(estado);
    switch (level) {
      case PhoneVisibilityLevel.revealed:
        return phone;
      case PhoneVisibilityLevel.masked:
        return _mask(phone);
      case PhoneVisibilityLevel.hidden:
        return 'Disponible al iniciar el servicio';
    }
  }

  static String _mask(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 4) return '••••';
    final last2 = digits.substring(digits.length - 2);
    return '+•• •• •••• ••$last2';
  }
}

enum PhoneVisibilityLevel { hidden, masked, revealed }
