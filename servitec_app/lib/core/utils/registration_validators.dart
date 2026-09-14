/// Field rules for the sign-up form.
///
/// Kept apart from the widget so they can be unit-tested, and so the phone
/// normalisation the form validates is exactly the one the repository stores —
/// the uniqueness check in firestore.rules keys on that normalised value, so
/// the two must never drift.
class RegistrationValidators {
  RegistrationValidators._();

  /// Reduces a Mexican phone number to its 10 national digits, or returns
  /// null when it cannot be one.
  ///
  /// Accepts what people actually type: spaces, dashes, parentheses, and an
  /// optional country prefix — `+52`, `52`, or the legacy mobile `521`.
  /// `55 1234 5678`, `(55) 1234-5678` and `+52 1 55 1234 5678` all become
  /// `5512345678`, so the same line cannot be registered twice by writing it
  /// differently.
  static String? normalizeMxPhone(String input) {
    var digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 13 && digits.startsWith('521')) {
      digits = digits.substring(3);
    } else if (digits.length == 12 && digits.startsWith('52')) {
      digits = digits.substring(2);
    }
    if (digits.length != 10) return null;
    // No Mexican area code starts with 0 or 1.
    if (digits.startsWith('0') || digits.startsWith('1')) return null;
    return digits;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return 'Requerido';
    if (normalizeMxPhone(value) == null) {
      return 'Ingresa un teléfono de 10 dígitos';
    }
    return null;
  }

  // Deliberately not RFC 5322: it rejects the typos people make (missing
  // domain, missing TLD, spaces, double @) without rejecting real addresses
  // such as `nombre+prueba@empresa.com.mx`. Whether the inbox exists is a
  // question only a verification email can answer.
  static final RegExp _email =
      RegExp(r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9\-]+(\.[A-Za-z0-9\-]+)*\.[A-Za-z]{2,}$');

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Requerido';
    if (!_email.hasMatch(value.trim())) return 'Correo inválido';
    return null;
  }

  // Letters in any script (so á, ñ, ü pass), plus the space, apostrophe,
  // hyphen and period that appear in real names: "María José", "O'Connor",
  // "Sánchez-Vega", "Ma. Elena".
  static final RegExp _nameChars = RegExp(r"^[\p{L}][\p{L} '\-.]*$", unicode: true);
  static final RegExp _letter = RegExp(r'\p{L}', unicode: true);

  static String? name(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Requerido';
    if (!_nameChars.hasMatch(v)) return 'Solo letras';
    if (_letter.allMatches(v).length < 2) return 'Muy corto';
    return null;
  }
}
