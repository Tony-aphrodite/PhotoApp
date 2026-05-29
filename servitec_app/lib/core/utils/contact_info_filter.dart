/// Detects contact info or off-platform bypass attempts in chat messages.
///
/// Client-side first line of defense. Server-side enforcement (Cloud Function
/// on message create + Firestore rules) must replicate this — a determined
/// user can patch the client. Tracked in 5-29.md section 4.
class ContactInfoFilter {
  ContactInfoFilter._();

  static final RegExp _email = RegExp(
    r'[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}',
  );

  // Sequences with 8+ digits (allows spaces, dashes, dots, parens).
  // Catches Mexican mobile/landline regardless of country-code prefix.
  static final RegExp _phone = RegExp(
    r'(?:\+?\d[\s\-.()]*){8,}',
  );

  static final RegExp _whatsappUrl = RegExp(
    r'(?:wa\.me|api\.whatsapp\.com|chat\.whatsapp\.com)',
    caseSensitive: false,
  );

  static final RegExp _telegramUrl = RegExp(
    r'(?:t\.me|telegram\.me)',
    caseSensitive: false,
  );

  // Common Spanish bypass phrases. Word boundaries kept loose because users
  // frequently misspell ("wasap", "guasap", "wapp").
  static final RegExp _bypassKeywords = RegExp(
    r'\b(?:whats?\s*app|wha?tsa?pp|wasap|guasap|wapp|telegram|messenger|'
    r'fuera\s+de\s+la\s+app|por\s+fuera|afuera\s+de\s+la\s+app|'
    r'transferencia|deposito\s+directo|pagame\s+por\s+fuera|'
    r'sin\s+la\s+app|sin\s+servitec)\b',
    caseSensitive: false,
  );

  /// Returns `null` if the message is clean, otherwise a [ContactViolation].
  static ContactViolation? scan(String text) {
    if (text.trim().isEmpty) return null;

    if (_email.hasMatch(text)) {
      return const ContactViolation(
        reason: ContactViolationReason.email,
        message:
            'No compartas correos electrónicos en el chat. Mantén la comunicación dentro de ServiTec.',
      );
    }

    if (_whatsappUrl.hasMatch(text) || _telegramUrl.hasMatch(text)) {
      return const ContactViolation(
        reason: ContactViolationReason.externalLink,
        message:
            'No se permiten enlaces a WhatsApp o Telegram. Continúa la conversación aquí.',
      );
    }

    if (_phone.hasMatch(text)) {
      return const ContactViolation(
        reason: ContactViolationReason.phone,
        message:
            'No compartas números telefónicos. ServiTec habilitará el contacto cuando inicie el servicio.',
      );
    }

    if (_bypassKeywords.hasMatch(text)) {
      return const ContactViolation(
        reason: ContactViolationReason.bypassKeyword,
        message:
            'Las transacciones y la comunicación deben mantenerse dentro de ServiTec para tu protección.',
      );
    }

    return null;
  }
}

enum ContactViolationReason { phone, email, externalLink, bypassKeyword }

class ContactViolation {
  final ContactViolationReason reason;
  final String message;

  const ContactViolation({required this.reason, required this.message});
}
