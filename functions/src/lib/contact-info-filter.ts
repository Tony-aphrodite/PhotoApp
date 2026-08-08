/**
 * Server-side port of `servitec_app/lib/core/utils/contact_info_filter.dart`.
 *
 * The Dart version is a UX affordance (it warns before sending); THIS is the
 * enforcement point — a patched client can skip the former but not the latter.
 * Keep the two in sync: same patterns, same precedence, same Spanish copy, so
 * a user sees identical wording whichever layer catches them.
 *
 * Precedence matters: `wa.me/525512345678` must be reported as an external
 * link, not as a phone number, so the URL patterns are tested before the
 * digit-sequence pattern.
 */

export type ContactViolationReason =
  | 'phone'
  | 'email'
  | 'externalLink'
  | 'bypassKeyword';

export interface ContactViolation {
  reason: ContactViolationReason;
  /** User-facing Spanish explanation, shown in place of the blocked message. */
  message: string;
}

const EMAIL = /[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}/;

// Sequences of 8+ digits, tolerating spaces, dashes, dots and parens.
// Catches Mexican mobile/landline numbers with or without a country code.
const PHONE = /(?:\+?\d[\s\-.()]*){8,}/;

const WHATSAPP_URL = /(?:wa\.me|api\.whatsapp\.com|chat\.whatsapp\.com)/i;

const TELEGRAM_URL = /(?:t\.me|telegram\.me)/i;

// Common Spanish bypass phrases. Boundaries stay loose because users
// frequently misspell ("wasap", "guasap", "wapp").
const BYPASS_KEYWORDS = new RegExp(
  '\\b(?:whats?\\s*app|wha?tsa?pp|wasap|guasap|wapp|telegram|messenger|' +
    'fuera\\s+de\\s+la\\s+app|por\\s+fuera|afuera\\s+de\\s+la\\s+app|' +
    'transferencia|deposito\\s+directo|pagame\\s+por\\s+fuera|' +
    'sin\\s+la\\s+app|sin\\s+servitec)\\b',
  'i',
);

/** Returns `null` when the message is clean, otherwise the violation. */
export function scan(text: string): ContactViolation | null {
  if (!text || text.trim().length === 0) return null;

  if (EMAIL.test(text)) {
    return {
      reason: 'email',
      message:
        'No compartas correos electrónicos en el chat. Mantén la comunicación dentro de ServiTec.',
    };
  }

  if (WHATSAPP_URL.test(text) || TELEGRAM_URL.test(text)) {
    return {
      reason: 'externalLink',
      message:
        'No se permiten enlaces a WhatsApp o Telegram. Continúa la conversación aquí.',
    };
  }

  if (PHONE.test(text)) {
    return {
      reason: 'phone',
      message:
        'No compartas números telefónicos. ServiTec habilitará el contacto cuando inicie el servicio.',
    };
  }

  if (BYPASS_KEYWORDS.test(text)) {
    return {
      reason: 'bypassKeyword',
      message:
        'Las transacciones y la comunicación deben mantenerse dentro de ServiTec para tu protección.',
    };
  }

  return null;
}
