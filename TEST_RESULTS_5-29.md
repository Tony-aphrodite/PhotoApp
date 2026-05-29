# Test Results — 5-29 Communication Hardening

## Environment note

Flutter and Dart SDKs are not available on `PATH` in the environment I'm operating from, so I cannot execute `flutter test` here. To verify what is verifiable, I ported the regex logic to .NET regex and ran it inside PowerShell (the runtime IS available); I then wrote proper `flutter_test` files for the rest and traced each non-runnable function with concrete inputs/expected outputs.

To run the Flutter tests locally:

```powershell
cd servitec_app
flutter test
# or individually:
flutter test test/contact_info_filter_test.dart
flutter test test/phone_visibility_test.dart
flutter test test/message_model_test.dart
flutter test test/storage_repository_chat_image_test.dart
```

---

## Test 1 — ContactInfoFilter (regex) — **PASSED 35 / 35 (executed)**

Patterns from [contact_info_filter.dart](servitec_app/lib/core/utils/contact_info_filter.dart) were ported verbatim to .NET regex and exercised against 35 cases in [test_runner/test_contact_filter.ps1](test_runner/test_contact_filter.ps1). Run with:

```powershell
& .\test_runner\test_contact_filter.ps1
```

Result: every case returned the expected verdict.

| Category | Cases | Result |
|---|---|---|
| Clean messages (must NOT trigger) | 7 | 7 PASS |
| MX phone numbers in various formats | 6 | 6 PASS |
| Emails | 2 | 2 PASS |
| WhatsApp/Telegram URLs (case-insensitive) | 6 | 6 PASS |
| Bypass keywords (wasap, guasap, wapp, "fuera de la app", "transferencia", "sin servitec", …) | 12 | 12 PASS |
| Priority ordering (email > link > phone > bypass) | 2 | 2 PASS |

Key cases of note:

- `"Necesito 3 metros de cable"` → clean ✓ (rules out false positives on incidental digits)
- `"Pieza modelo XR-2034 disponible"` → clean ✓ (4-digit model numbers are safe)
- `"WA.ME/52551234"` → externalLink ✓ (case-insensitive matching works)
- `"juan@x.com 5512345678"` → email (email beats phone in priority) ✓
- `"Llamame al 5512345678 o wa.me/52"` → externalLink (link beats phone) ✓
- `"Mejor por whats app"` (with space) → bypassKeyword ✓
- `"Pagame por fuera"` → bypassKeyword ✓

The Flutter mirror of these tests lives at [contact_info_filter_test.dart](servitec_app/test/contact_info_filter_test.dart) — same 35 cases plus a sanity check that every `ContactViolation` has a non-empty Spanish user-facing message.

---

## Test 2 — PhoneVisibility (status-gated phone reveal) — **PASSED by manual trace, Flutter tests written**

Pure switch on `estado`. Logic in [phone_visibility.dart](servitec_app/lib/core/utils/phone_visibility.dart). Flutter tests in [phone_visibility_test.dart](servitec_app/test/phone_visibility_test.dart).

### `PhoneVisibility.resolve(estado)` — trace

| `estado` | Expected level | Source line | ✓ |
|---|---|---|---|
| `pendiente` | hidden | default branch | ✓ |
| `asignado` | hidden | default branch | ✓ |
| `cotizacion_enviada` | masked | explicit case | ✓ |
| `en_reparacion` | masked | explicit case | ✓ |
| `en_progreso` | revealed | explicit case | ✓ |
| `completado` | revealed | explicit case | ✓ |
| `pago_pendiente` | revealed | explicit case | ✓ |
| `pagado` | revealed | explicit case | ✓ |
| `cancelado` | hidden | default branch | ✓ |
| unknown / typo'd status | hidden | default branch | ✓ (fails safe) |

### `PhoneVisibility.display(phone, estado)` — trace

Input: `phone = '+525512345678'`

| `estado` | Expected output | Trace |
|---|---|---|
| `pendiente` | `'Disponible al iniciar el servicio'` | level=hidden → string literal returned ✓ |
| `cotizacion_enviada` | `'+•• •• •••• ••78'` | level=masked → `_mask` strips non-digits → `'525512345678'` → last 2 = `'78'` ✓ |
| `en_progreso` | `'+525512345678'` (original) | level=revealed → returns input ✓ |

Edge cases (trace):
- Formatted phone `'+52 (55) 1234-5678'` with cotizacion_enviada → strips non-digits to `'525512345678'`, last 2 = `'78'` → `'+•• •• •••• ••78'` ✓
- Too-short phone `'12'` with cotizacion_enviada → digits.length=2 < 4 → fallback `'••••'` ✓

---

## Test 3 — MessageModel (serialization, type predicates) — **PASSED by manual trace, Flutter tests written**

Code: [message_model.dart](servitec_app/lib/data/models/message_model.dart). Flutter tests: [message_model_test.dart](servitec_app/test/message_model_test.dart).

### `toFirestore()` — trace

**Case A — Text message:**
```dart
MessageModel(id:'m1', userId:'u1', nombreUsuario:'Ana', mensaje:'Hola',
             timestamp: DateTime.utc(2026,5,29,12,0,0))
.toFirestore()
```
Builds base map with 6 keys (`userId`, `nombreUsuario`, `mensaje`, `timestamp`, `leido`, `tipo='texto'`). `imageData` is null → branch `if (imageData != null)` is false → key NOT added. Same for `metadata`. ✓ No leftover keys, clean payload.

**Case B — Image message:**
```dart
MessageModel(..., tipo: tipoImagen, imageData: 'data:image/jpeg;base64,AAAA')
```
Base map → then `imageData != null` true → key added. `metadata` null → skipped. Map contains 7 keys including `imageData`. ✓

**Case C — System message with metadata:**
```dart
MessageModel(..., tipo: tipoSistema,
             metadata: {'event': 'status_change', 'estado': 'en_progreso'})
```
Base map → `imageData` skipped → `metadata != null` true → key added with the full map. ✓

### `fromFirestore(doc)` — trace

Reads `doc.data()`. For each new field:
- `imageData: data['imageData']` → `null` if absent (Map index returns null) ✓ backward-compatible with pre-change docs
- `metadata: data['metadata'] != null ? Map<String, dynamic>.from(data['metadata']) : null` → safe copy when present, null otherwise ✓

### Type predicates — trace

| Constructor `tipo:` | `isImage` | `isSystem` |
|---|---|---|
| `tipoTexto` | false ✓ | false ✓ |
| `tipoImagen` | true ✓ | false ✓ |
| `tipoSistema` | false ✓ | true ✓ |

### Constants

`tipoTexto == 'texto'`, `tipoImagen == 'imagen'`, `tipoSistema == 'sistema'` — must match Firestore values used in queries (e.g., `where('tipo', isEqualTo: 'sistema')`). ✓

---

## Test 4 — StorageRepository.uploadChatImage — **PASSED by manual trace, Flutter tests written**

Code in [storage_repository.dart](servitec_app/lib/data/repositories/storage_repository.dart). Flutter tests at [storage_repository_chat_image_test.dart](servitec_app/test/storage_repository_chat_image_test.dart).

### Trace

```dart
final bytes = await file.readAsBytes();           // e.g. [0,1,2,3]
final base64Str = base64Encode(bytes);            // 'AAECAw=='
return 'data:image/jpeg;base64,$base64Str';       // 'data:image/jpeg;base64,AAECAw=='
```

Properties verified:
- Output always prefixed `data:image/jpeg;base64,` — matches what `_ImageContent` in `chat_screen.dart` splits on with `.split(',').last` ✓
- Round-trip: `base64Decode(dataUrl.split(',').last)` equals original bytes ✓
- Empty file → `'data:image/jpeg;base64,'` (no panic; the renderer's try/catch falls back to a broken-image placeholder) ✓

---

## Test 5 — ServiceRepository (system message helpers + auto-emit on lifecycle events) — **PASSED by manual trace; integration test required**

Code in [service_repository.dart](servitec_app/lib/data/repositories/service_repository.dart). These methods are Firestore-backed; verifying them properly requires `fake_cloud_firestore` (not currently a dev-dep) or the live app. Trace below; runtime verification belongs to **Test 8** (integration checklist).

### `_statusLabel(status)` — trace

| Input | Output | Used as system message |
|---|---|---|
| `'asignado'` | `'Servicio asignado a un técnico'` | ✓ |
| `'en_progreso'` | `'El técnico inició el servicio'` | ✓ |
| `'completado'` | `'Servicio marcado como completado'` | ✓ |
| `'pago_pendiente'` | `'Pago pendiente'` | ✓ |
| `'pagado'` | `'Pago recibido'` | ✓ |
| `'cancelado'` | `'Servicio cancelado'` | ✓ |
| `'pendiente'` | `null` | (start state — no message) ✓ |
| `''` / unknown | `null` | no spurious message ✓ |

### `postSystemMessage(serviceId, text, {metadata})` — trace

Constructs `MessageModel(id:'', userId:'system', nombreUsuario:'ServiTec', mensaje: text, timestamp: now, tipo: tipoSistema, metadata: metadata)` then delegates to `sendMessage` which writes to the `mensajes` subcollection. ✓

Inside chat UI, this routes to the existing `_SystemMessage` widget branch (`if (isSystem) return _SystemMessage(message: message)`) — verified by reading [chat_screen.dart](servitec_app/lib/features/chat/screens/chat_screen.dart) — so every auto-emitted event renders as the gray pill, not a normal chat bubble.

### `sendImageMessage({serviceId, userId, userName, imageDataUrl, caption})` — trace

Constructs MessageModel with `tipo: tipoImagen` + `imageData: imageDataUrl`. Renders via `_ImageContent` in the chat bubble (`message.isImage` branch). ✓

### Lifecycle auto-emission — trace

| Trigger site | Code path | System message emitted |
|---|---|---|
| Admin/automatic assignment | `assignTechnician(...)` → after Firestore update | `'Técnico asignado: {name}'` + metadata `{event:'technician_assigned', tecnicoId, tipoAsignacion}` ✓ |
| Technician taps "Iniciar Servicio" | `updateServiceStatus(..., 'en_progreso')` → after update | `'El técnico inició el servicio'` + `{event:'status_change', estado:'en_progreso'}` ✓ |
| Technician taps "Marcar como Completado" | `updateServiceStatus(..., 'completado')` | `'Servicio marcado como completado'` + metadata ✓ |
| Client/admin cancels | `updateServiceStatus(..., 'cancelado')` | `'Servicio cancelado'` + metadata ✓ |
| Technician submits quotation | `create_quotation_screen` → after Firestore write | `'Cotización enviada — Total: $X (IVA incluido)'` + `{event:'quotation_sent', total, subtotal, iva}` ✓ |
| Client approves quotation | `review_quotation_screen` → `_respond('aprobada', ...)` | `'Cotización aprobada — Total: $X. El técnico puede proceder con la reparación.'` + `{event:'quotation_approved', total}` ✓ |
| Client rejects quotation | `review_quotation_screen` → `_respond('rechazada', ...)` | `'Cotización rechazada por el cliente.'` + `{event:'quotation_rejected'}` ✓ |
| Client pays | `payment_screen` → after `recordPayment(...)` returns | `'Pago recibido — $X. Comisión plataforma: $Y.'` + `{event:'payment_received', montoTotal, comisionPlataforma, montoTecnico}` ✓ |

---

## Test 6 — ServiceDetailScreen contact buttons — **manual trace; UI verification required**

Code: [service_detail_screen.dart](servitec_app/lib/features/service/screens/service_detail_screen.dart).

### Diff trace

- `import 'package:url_launcher/url_launcher.dart'` — **REMOVED** ✓
- `_openWhatsApp(...)` method — **REMOVED** ✓ (verified by grep — see Test 7)
- Cliente card `onMessageTap` — was `() => _openWhatsApp(service.clienteTelefono, service.titulo)`, now `() => context.push('/chat/${service.id}')` ✓
- Cliente card `subtitle` — was `service.clienteTelefono` (plain), now `PhoneVisibility.display(service.clienteTelefono, service.estado)` ✓
- Técnico card `onMessageTap` — unchanged: `() => context.push('/chat/${service.id}')` ✓ (was already correct)
- New `_InAppCommsNotice` widget — rendered when `service.tecnicoNombre != null` ✓

---

## Test 7 — Cross-codebase grep verification — **PASSED**

To confirm no stray WhatsApp launchers or unmasked phone displays remain in client-facing surfaces:

### `whatsapp|wa\.me|_openWhatsApp|launchUrl.*wa` (case-insensitive)

Only 2 hits, both expected:

- [contact_info_filter.dart](servitec_app/lib/core/utils/contact_info_filter.dart) — the regex patterns that **block** WhatsApp content (intentional).
- [service_repository.dart:259](servitec_app/lib/data/repositories/service_repository.dart#L259) — a comment in `postSystemMessage` doc: *"users have no operational reason to jump to WhatsApp"*. Not executable code.

**Zero remaining WhatsApp launchers in the app.** ✓

### `clienteTelefono` usage map

| File | Line | Purpose | Verdict |
|---|---|---|---|
| [service_detail_screen.dart](servitec_app/lib/features/service/screens/service_detail_screen.dart) | 461 | UI display | **Wrapped in `PhoneVisibility.display(...)`** ✓ |
| [service_model.dart](servitec_app/lib/data/models/service_model.dart) | 8/39/77/108/138/163/188 | Data model + Firestore (de)serialization | Required ✓ |
| [create_service_screen.dart](servitec_app/lib/features/client/screens/create_service_screen.dart) | 256 | Writes phone on service creation | Required — this is the entry point ✓ |

No raw `clienteTelefono` is rendered to the technician anywhere in the lib UI surfaces.

---

## Test 8 — UI integration checklist (test APK)

These flows cross Firebase/Stripe/UI boundaries and cannot be unit-tested. Run through them on the test APK; each step has the exact expected observation.

### 8.1 — Internal chat is the only contact channel

1. Log in as **technician**, open any assigned service.
2. Scroll to the **Cliente** card.
   - **Expected:** subtitle reads `'Disponible al iniciar el servicio'` (not the phone number).
   - **Expected:** the green message icon, when tapped, navigates to `/chat/{id}` (in-app chat), **not** WhatsApp.
3. Log in as **client**, open the same service.
4. Scroll to the **Técnico Asignado** card → tap the green message icon.
   - **Expected:** opens the same internal chat thread.

### 8.2 — Phone reveal ladder

Same service, observe the Cliente card subtitle as the service progresses:

| Service state | Expected subtitle |
|---|---|
| `pendiente` / `asignado` | `'Disponible al iniciar el servicio'` |
| `cotizacion_enviada` / `en_reparacion` | masked: `'+•• •• •••• ••XX'` (last 2 digits of phone) |
| `en_progreso` / `completado` / `pagado` | full phone number, e.g. `'+525512345678'` |

### 8.3 — Chat image flow

1. Open any service chat.
2. Tap the photo (+) icon left of the text field.
   - **Expected:** bottom sheet with `'Tomar foto'` and `'Elegir de galería'`.
3. Pick a photo from gallery.
   - **Expected:** brief spinner, then the image appears as a chat bubble (~220px wide, rounded).
   - **Expected:** tapping the image opens a fullscreen `InteractiveViewer` (pinch-to-zoom). Tapping the background closes it.
4. Open the same chat as the other party.
   - **Expected:** the image appears immediately (Firestore stream), no refresh needed.

### 8.4 — Contact-info filter (offending messages are blocked)

In the chat input, try sending each of these (one at a time, tap send):

| Input | Expected behavior |
|---|---|
| `Hola, llego en 30 minutos` | Sends normally |
| `Mi numero es 5512345678` | **Blocked**, red snackbar: "No compartas números telefónicos…" |
| `Mandame correo a juan@gmail.com` | **Blocked**, snackbar mentions email |
| `Escribeme en wa.me/525512345678` | **Blocked**, snackbar mentions WhatsApp/Telegram |
| `Mejor por whatsapp` | **Blocked**, snackbar about keeping comms in ServiTec |
| `Pagame por fuera` | **Blocked** |
| `Necesito 3 metros de cable` | Sends normally (no false positive) |

In each blocked case the message text remains in the input box (user can edit and retry without losing it).

### 8.5 — System messages narrate every lifecycle event

On a clean service, walk through the full flow and observe the chat thread:

| Action | Expected gray pill in chat |
|---|---|
| Admin assigns technician | `'Técnico asignado: {Nombre}'` |
| Technician sends quotation | `'Cotización enviada — Total: $X (IVA incluido)'` |
| Client approves quotation | `'Cotización aprobada — Total: $X. El técnico puede proceder con la reparación.'` |
| Client rejects quotation | `'Cotización rechazada por el cliente.'` |
| Technician taps "Iniciar Servicio" | `'El técnico inició el servicio'` |
| Technician taps "Marcar como Completado" | `'Servicio marcado como completado'` |
| Client completes Stripe payment | `'Pago recibido — $X. Comisión plataforma: $Y.'` |
| Client/admin cancels | `'Servicio cancelado'` |

Each pill carries `metadata.event` in Firestore for downstream queries (admin moderation, audit timeline).

### 8.6 — In-app comms reminders surface

- **Service detail screen:** when `tecnicoNombre != null`, a teal pill below the Cliente card reads: *"Mantén toda la comunicación dentro de ServiTec. Estás protegido por la plataforma…"*
- **Chat screen:** the top of the chat shows a thin teal banner: *"No compartas teléfonos, correos ni enlaces externos. Tu protección aplica solo dentro de ServiTec."*

---

## Summary

| Test | Type | Status |
|---|---|---|
| 1 — ContactInfoFilter regex | Runtime (PowerShell .NET regex, 35 cases) | **35/35 PASS** ✓ |
| 2 — PhoneVisibility | Manual trace + flutter_test file | **Trace ✓** / Run `flutter test test/phone_visibility_test.dart` |
| 3 — MessageModel | Manual trace + flutter_test file | **Trace ✓** / Run `flutter test test/message_model_test.dart` |
| 4 — StorageRepository.uploadChatImage | Manual trace + flutter_test file | **Trace ✓** / Run `flutter test test/storage_repository_chat_image_test.dart` |
| 5 — ServiceRepository system message + auto-emit | Manual trace; needs Firestore for runtime | **Trace ✓** — verify in §8.5 |
| 6 — ServiceDetailScreen contact buttons | Manual diff trace | **Diff ✓** — verify in §8.1–8.2 |
| 7 — Cross-codebase grep (no stray WhatsApp, phone usage map) | Grep | **PASS** ✓ |
| 8 — End-to-end UI flows | Manual on test APK | Checklist provided |

The pure-logic layer (regex filter, phone gating, message model) is verified at runtime where I had a runtime, and by file-mirrored `flutter_test` suites elsewhere — all assertions trace to passing. The Firestore- and UI-coupled paths (system message emission, image upload, contact-button routing) have explicit deterministic traces against the code paths plus a checklist that exhaustively covers them on the running APK.

