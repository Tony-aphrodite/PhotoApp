"""
Runtime verification of ContactInfoFilter regex patterns.

The patterns below are copied verbatim from
servitec_app/lib/core/utils/contact_info_filter.dart with Dart-to-Python
syntax adjustments (raw strings, no `?:` group differences). Each test case
asserts what the Dart filter would do in production.
"""
import re
import sys

# Patterns mirror contact_info_filter.dart (Dart RegExp -> Python re)
EMAIL = re.compile(r'[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}')
PHONE = re.compile(r'(?:\+?\d[\s\-.()]*){8,}')
WHATSAPP_URL = re.compile(r'(?:wa\.me|api\.whatsapp\.com|chat\.whatsapp\.com)', re.IGNORECASE)
TELEGRAM_URL = re.compile(r'(?:t\.me|telegram\.me)', re.IGNORECASE)
BYPASS = re.compile(
    r'\b(?:whats?\s*app|wha?tsa?pp|wasap|guasap|wapp|telegram|messenger|'
    r'fuera\s+de\s+la\s+app|por\s+fuera|afuera\s+de\s+la\s+app|'
    r'transferencia|deposito\s+directo|pagame\s+por\s+fuera|'
    r'sin\s+la\s+app|sin\s+servitec)\b',
    re.IGNORECASE,
)

def scan(text: str):
    """Returns the violation reason or None — mirrors Dart scan()."""
    if not text.strip():
        return None
    if EMAIL.search(text):
        return "email"
    if WHATSAPP_URL.search(text) or TELEGRAM_URL.search(text):
        return "externalLink"
    if PHONE.search(text):
        return "phone"
    if BYPASS.search(text):
        return "bypassKeyword"
    return None


# (message, expected_reason or None, description)
CASES = [
    # --- Clean (should NOT trigger) ---
    ("Hola, llego en 20 minutos", None, "Normal greeting"),
    ("Necesito 3 metros de cable", None, "Numbers but not phone-shaped (only 1 digit)"),
    ("Cost: 1500 pesos for the parts", None, "Short number sequences (4 digits)"),
    ("OK perfecto, nos vemos mañana", None, "Plain Spanish text"),
    ("Pieza modelo XR-2034 disponible", None, "Model number (4 digits)"),
    ("", None, "Empty string"),
    ("   ", None, "Whitespace only"),

    # --- Phone numbers (should trigger 'phone') ---
    ("Mi numero es 5512345678", "phone", "MX 10-digit cell"),
    ("Llamame al +52 55 1234 5678", "phone", "International with spaces"),
    ("55-1234-5678", "phone", "Dashed format"),
    ("(55) 1234 5678", "phone", "Parens format"),
    ("Hablame: 5 5 1 2 3 4 5 6 7 8", "phone", "Spaced digits"),
    ("Tel 5512345678 disponible", "phone", "Phone embedded in sentence"),

    # --- Email (should trigger 'email') ---
    ("Mandame correo a juan@gmail.com", "email", "Gmail address"),
    ("contacto: ana.lopez+work@example.co.mx", "email", "Complex email"),

    # --- External links (should trigger 'externalLink') ---
    ("Escribeme en wa.me/525512345678", "externalLink", "wa.me link"),
    ("https://api.whatsapp.com/send?phone=52", "externalLink", "api.whatsapp.com"),
    ("Mi grupo: chat.whatsapp.com/abc", "externalLink", "chat.whatsapp.com"),
    ("Mandame en t.me/mychannel", "externalLink", "t.me link"),
    ("telegram.me/handle", "externalLink", "telegram.me"),
    ("WA.ME/52551234", "externalLink", "Case-insensitive WhatsApp"),

    # --- Bypass keywords (should trigger 'bypassKeyword') ---
    ("Mejor por whatsapp", "bypassKeyword", "whatsapp word"),
    ("Mejor por whats app", "bypassKeyword", "whats app spaced"),
    ("Mandame wasap", "bypassKeyword", "wasap slang"),
    ("Te paso por guasap", "bypassKeyword", "guasap slang"),
    ("Mejor un wapp", "bypassKeyword", "wapp slang"),
    ("Hablamos por telegram", "bypassKeyword", "telegram word"),
    ("Mejor en messenger", "bypassKeyword", "messenger"),
    ("Lo arreglamos fuera de la app", "bypassKeyword", "fuera de la app"),
    ("Pagame por fuera", "bypassKeyword", "por fuera"),
    ("Hagamos transferencia directa", "bypassKeyword", "transferencia"),
    ("Sin la app sale mas barato", "bypassKeyword", "sin la app"),
    ("Vamos sin servitec", "bypassKeyword", "sin servitec"),

    # --- Priority (email beats phone when both present) ---
    ("juan@x.com 5512345678", "email", "Email takes priority over phone"),
    ("Llamame al 5512345678 o wa.me/52", "externalLink", "Link beats phone"),
]


def main():
    passed, failed = 0, 0
    failures = []
    for msg, expected, desc in CASES:
        actual = scan(msg)
        ok = actual == expected
        marker = "PASS" if ok else "FAIL"
        if ok:
            passed += 1
        else:
            failed += 1
            failures.append((desc, msg, expected, actual))
        # Truncate display
        shown = (msg[:55] + "...") if len(msg) > 55 else msg
        print(f"  [{marker}] {desc:50s} | expected={str(expected):14s} | input='{shown}'")

    print()
    print(f"Total: {passed + failed}  Passed: {passed}  Failed: {failed}")
    if failures:
        print("\nFAILURES:")
        for desc, msg, expected, actual in failures:
            print(f"  - {desc}")
            print(f"      input    : {msg!r}")
            print(f"      expected : {expected}")
            print(f"      got      : {actual}")
        sys.exit(1)
    print("\nAll regex assertions passed.")


if __name__ == "__main__":
    main()
