# Tester Quickstart — Integrated APK

For whoever installs the test APK. Walk through every step and note anything that doesn't behave as described.

Expected time: **30–45 minutes** for the full happy-path plus a handful of edge cases.

---

## Prereqs

- Two Android devices (or one device + one emulator). One will be **Cliente**, the other **Técnico**. If you only have one device, you can log out and switch, but two is much faster.
- A **Stripe test card**: `4242 4242 4242 4242`, any future expiry, any 3-digit CVC, any 5-digit ZIP. This is the "always succeeds" test card.
- A test `.cer` + `.key` file for the Técnico's fiscal onboarding. Any dummy CSD works in test mode. If you don't have one, ask FacturAPI support for their sandbox certificate download.
- Firebase Console access to inspect Firestore documents when needed.

---

## Setup: create the two test accounts

**Device A (Cliente):**
1. Install the APK, open the app.
2. Register a new account, pick **Cliente** role. Use a **real inbox you can open** — the phone must be 10 digits and not used by any other account.
3. The app opens **Verifica tu correo**. Open the link in the email (check spam), then come back to the app — it notices on its own; **Ya lo verifiqué** forces the check. Until then the account cannot create services, send messages, or receive assignments.
4. The **onboarding disclosure modal** should appear immediately after first login. Read it and tap "Entendido y acepto".
   - **Expected**: Modal disappears, doesn't come back on subsequent launches.
   - **Verify in Firestore**: `users/{uid}.disclosureAcceptedAt` is populated.

**Device B (Técnico):**
1. Install the APK, open the app.
2. Register a new account, pick **Técnico** role, add at least one specialty (e.g., `limpieza`).
3. Verify the email the same way. An unverified técnico is skipped by auto-assignment.
4. Accept the disclosure.
   - **Expected**: same modal as cliente, plus a **fiscal banner** at the top of the technician home ("Completa tu registro fiscal — 60d restantes"), and a **Stripe banner** below it ("Enlaza tu cuenta bancaria").

**Optionally (Admin)**: don't register — the admin account already exists. Sign in on the normal login screen with the `ADMIN_EMAIL` / `ADMIN_PASSWORD` credentials (provisioned automatically on deploy, see `functions/scripts/seed-admin.js`) and the app opens the admin panel directly. Not required for the happy path.

---

## Test 1 — Fiscal onboarding (Técnico)

1. On Device B, tap **"Iniciar"** on the fiscal banner.
2. Fill in step 1 (RFC, razón social, régimen `626`, CP).
3. Step 2: upload the test `.cer` and `.key`, enter the CSD password.
4. Step 3: review → tap **"Enviar"**.

**Expected**:
- Success snackbar: *"Datos fiscales enviados. Tu organization en FacturAPI está lista."*
- Fiscal banner disappears from home.
- In Firestore, `users/{tecnicoUid}.facturapi.status` = `active`, `organizationId` populated.
- In FacturAPI dashboard → Organizations → a new sub-organization appears named after your razón social.

**If it fails** with a Firebase Functions error, the FacturAPI SDK method names probably need adjustment (see DEPLOY.md step 1). Check Cloud Functions logs.

---

## Test 2 — Stripe Connect onboarding (Técnico)

1. On Device B, tap **"Enlazar"** on the Stripe banner.
2. On the Stripe Connect screen, tap **"Enlazar cuenta bancaria"**.
3. Browser opens with Stripe's hosted onboarding.
4. Fill in the test info (Stripe accepts fake data in test mode — e.g., DOB `1990-01-01`, CURP anything, bank CLABE `000000000000000000` for test).
5. Complete the flow. Stripe redirects back to `servitec://stripe/return`.

**Expected**:
- App comes back to foreground.
- Pull down to refresh the Stripe Connect screen.
- Status card should now say **"Activa"** (or **"Incompleta"** if Stripe wants more info — normal in sandbox).
- Stripe banner on home disappears.
- In Firestore, `users/{tecnicoUid}.stripeConnectAccountId` = `acct_...`.

---

## Test 3 — Create service (Cliente)

1. On Device A, tap **"+ Solicitar"** or a category.
2. Fill in title, description, category `limpieza` (matches técnico's specialty), urgency `normal`, location, add a photo.
3. Submit.

**Expected**:
- Service appears in "Mis Servicios" as **Pendiente**, then flips to **Asignado** within a second or two — `onServiceCreated` auto-assigns whenever `tipoAsignacion` is `automatica` (the default), scoring técnicos on rating, current workload, distance and experience.
- In Firestore, `servicios/{id}` was created with `clienteTelefono` **empty**, and `servicios/{id}/private/contact` was created with the real phone.
- If no técnico has the matching specialty, the service stays **Pendiente**, every admin gets a "Sin técnicos disponibles" push, and a `no_technician_available` entry lands in `admin_flags/`.

---

## Test 4 — Assignment + push notifications

If Test 3 auto-assigned already, that *is* this test — skip to the expectations below.

**To exercise manual assignment instead**, set `tipoAsignacion: "manual"` on the service document in the Firestore Console before a técnico is picked, or create the service and immediately clear `tecnicoId`. Then:
1. On admin device, open Dashboard, tap the pending service, tap **"Asignar Tecnico"**, pick the técnico from the list.

With `manual`, nobody is auto-assigned: admins get a "Nuevo servicio pendiente" push and every matching técnico gets "Nuevo servicio disponible".

**Expected**:
- Cliente device receives a push: *"ServiTec — Técnico asignado: {Nombre}"*.
- In the service chat, gray pill: *"Técnico asignado: {Nombre}"*.
- Cliente card on service detail (viewed by técnico) shows *"Disponible al iniciar el servicio"* — phone is hidden.

---

## Test 5 — Chat filter (server-side, the real defense)

Open the service chat as either party. Try sending each of these:

| Message | Expected result |
|---|---|
| `hola, listo` | Sends normally |
| `mi wa es 55 1234 5678` | Message appears briefly, then replaces with "⚠️ Mensaje bloqueado: No compartas números telefónicos..." |
| `escríbeme a juan@gmail.com` | Same block with email message |
| `wa.me/525512345678` | Blocked with WhatsApp warning |
| `mejor por wasap` | Blocked with off-platform warning |

**Key difference from client-side filter**: even if the sender's app doesn't block it, the SERVER redacts it. Both parties see the block in real time.

**Verify** in Firestore: an entry appears in `admin_flags/` for each blocked attempt with the original text preserved for moderation.

---

## Test 6 — Chat photo + push

1. Técnico taps the 📷 icon in chat, picks a photo.
2. **Expected**: photo appears as a chat bubble.
3. Cliente device receives push: *"Nuevo mensaje · {Nombre} — 📷 Foto"*.

---

## Test 7 — Quotation (required before any work)

1. Técnico opens the assigned service → **Enviar cotización** → 2 items (e.g. mano de obra $800 + material $235) → send.
2. **Expected**: state `Cotización enviada`; cliente gets push *"Cotización enviada — Total: $1,200.60 (IVA incluido)…"*; técnico sees *"Esperando la respuesta del cliente"* and **no "Iniciar trabajo" button**.
3. Cliente opens the service → **Revisar cotización** → **Rechazar** → confirm.
4. **Expected**: state `Cotización rechazada`; técnico can **Enviar nueva cotización** (version 2). The service's *Cotizaciones* card lists v1 crossed out.
5. Técnico sends v2 → cliente **Aprobar** → confirm.
6. **Expected**: state `Cotización aprobada`; técnico gets push; técnico now sees **Iniciar trabajo ($X)**. Phone on the cliente card is still masked.

---

## Test 8 — Work, revised quotation, stopping

**8a — Happy path**
1. Técnico **Iniciar trabajo** → state `En Progreso`; técnico now sees the full cliente phone.
2. Técnico **Marcar como terminado** → the dialog shows the approved amount → state `Completado`; cliente sees **Pagar $X** for exactly that amount.

**8b — Revised quotation approved** (new service, repeat Test 7 first)
1. While `En Progreso`, técnico **Encontré un problema adicional** → send a higher total.
2. **Expected**: state `Revisión enviada`; **Marcar como terminado is gone** until the cliente answers; cliente sees the old and new totals side by side.
3. Cliente **Aprobar** → back to `En Progreso` with the new total; paying later charges the new total.

**8c — Revision rejected, técnico continues the original scope**
1. As 8b, but cliente **Rechazar** → state `Revisión rechazada`.
2. Técnico sees three options → **Continuar con el trabajo original** → `En Progreso` → terminate → cliente pays the **original** amount.

**8d — Revision rejected, técnico stops; cliente accepts**
1. As 8c step 1, then técnico **Detener trabajo**: pick a reason, write an explanation, add ≥1 photo, propose an amount ≤ the approved one.
2. **Expected**: the app refuses without a photo or with an amount above the approved one. After sending: state `Trabajo detenido`; cliente sees reason, photos and amount.
3. Cliente **Aceptar $X** → state `Completado` → pays $X. (Proposing $0 closes the service with no charge.)
4. Admin → Alertas shows a *work_stopped* entry.

**8e — Stop disputed, admin resolves**
1. As 8d, but cliente **No estoy de acuerdo** with a comment → state `En revisión ServiTec`; admins get a push.
2. Admin opens the service (Dashboard → **Detenidos** filter) → **Resolver disputa** → amount + note.
3. **Expected**: state `Completado` with that amount (or closed without charge below $10); both parties see the note in chat.

---

## Test 8f — Diagnostic visit (Phase 2, dev project only)

Setup: Admin → Herramientas → Categorías → edit a category (e.g. Aire acondicionado) → turn on **Requiere visita de diagnóstico**, price $400. The técnico must have Stripe connected (Test 2) or they will not be offered the job.

1. Cliente creates a request in that category → the form shows the diagnostic notice. Técnico gets it as `Asignado` with **Proponer horario de visita**.
2. Técnico proposes a time **within the next 2 hours** (so "Voy en camino" unlocks during the test). Cliente sees the visit card with the four rules → **Confirmar y autorizar $400** → Stripe sheet → card `4242…`.
   - **Expected**: `Visita confirmada`; Stripe dashboard shows a $400 PaymentIntent **uncaptured** (held).
3. Técnico **Voy en camino** → confirm. **Expected**: `Técnico en camino`; the PaymentIntent is now **captured**; chat says it is no longer refundable.
4. Técnico **Enviar cotización de reparación** → total $1,500. Cliente sees "se te descontará la visita"; approves.
5. Técnico **Iniciar trabajo** → **Marcar como terminado**. Cliente sees **Pagar $1,100** with "Total $1,500 menos la visita ya pagada ($400)". Pays.
   - **Expected**: two transactions in Stripe ($400 and $1,100), each with 12% application fee ($48 + $132).

Variants worth one run each:
- **Repair below the visit** ($300 in step 4): after "Marcar como terminado" the service goes straight to `Pagado`; no second charge.
- **Cliente rejects the repair**: tap **No quiero la reparación** → `Pagado`, only $400 charged.
- **Cancel before travel** (after step 2): Cancelar servicio → hold released in Stripe, nothing charged.
- **Cancel after travel** (after step 3): dialog warns it is non-refundable → `Pagado` with $400 kept.
- **Técnico withdraws** after step 3: **Cancelar mi asignación** → $400 refunded, service back to `Pendiente` for the admin to reassign; Admin → Técnicos shows "Canceló: 1".
- **No-show**: after step 3 and 30 minutes past the appointment, cliente **El técnico no llegó** → admin **Resolver reporte** → refund and reassign, or reject.
- **Auto-close**: leave a service in `Diagnóstico realizado`; the card shows the auto-close date (7 days). Reminders at 48h/24h come from the hourly cron.

---

## Test 9 — Payment + CFDI

1. On Cliente device, service should show a **"Pagar"** button now.
2. Tap it → payment breakdown shows total, 12% platform commission, técnico net.
3. Tap **"Pagar"** → Stripe payment sheet opens.
4. Enter card `4242 4242 4242 4242`, `12/34`, `123`, `12345`.
5. Confirm.

**Expected**:
- Payment succeeds.
- Snackbar: *"Pago exitoso"*.
- Both devices get push: *"ServiTec — Pago recibido — $X..."*.
- Service state → `pagado`.
- **CFDI stamped** (~2–5 sec after payment):
  - Firestore `facturas/` collection has a new doc, `tipo: tecnico_cliente`.
  - In FacturAPI dashboard under the técnico's organization → Facturas → the new invoice appears.
  - Chat gets a system pill: *"CFDI emitido — folio {UUID}"*.
- Técnico's earnings screen shows the transaction.
- **Reload the service detail on either device** → a **"Ver factura (PDF)"** button appears. Tap it: the browser opens the branded ServiTec PDF. If the button doesn't show, the CFDI hasn't been stamped yet (give it a few seconds) or the técnico never finished fiscal onboarding — see the gotcha in DEPLOY.md.
- On the técnico device, **Ganancias → Facturas** lists the same CFDI with its folio fiscal and PDF / XML buttons.

---

## Test 10 — Appointments and the técnico's agenda

1. On Device A (Cliente), open an assigned service and book an appointment for **tomorrow** (any slot).
2. On Device B (Técnico), tap the **calendar icon** in the top right of the home screen.

**Expected**:
- **Mi Agenda** opens, grouped by day. The new appointment sits under **Mañana** with its time, duration, the service title, the client's name, and chips for *A domicilio* / *En taller* and *programada*.
- Tap **Confirmar** → the chip flips to *confirmada* and the buttons become **Completada** / **No asistió**. In Firestore, `citas/{id}.estado` follows along.
- Tap **Completada** → chip turns green and only **Ver servicio** remains.

**The 24h reminder** runs hourly and only fires for appointments 24–25 hours out, so it won't trigger during a same-day test. To force it: `firebase functions:shell` → `appointmentReminderCron()` with an appointment booked for roughly this time tomorrow. Both devices should get *"Recordatorio de cita — Mañana a las HH:MM, a domicilio — {título}"*, and `citas/{id}.recordatorioEnviadoAt` gets stamped so it never sends twice.

---

## Test 11 — Verify commission fell into the platform's balance

1. In Stripe dashboard (test mode) → **Balance** → should show 12% of the transaction accumulated.
2. Under **Connect → Connected accounts** → the técnico's account → transaction of amount minus 12% posted to their pending balance.

---

## What to report if something fails

For each broken step:
1. Test number.
2. Exact button pressed.
3. What you expected to happen.
4. What actually happened (error message text, screenshot).
5. Content of the relevant Firestore document (`users/{uid}`, `servicios/{id}`, or `facturas/{id}`) at the moment of failure.
6. If it's a Cloud Function error: paste the last 20 lines from `firebase functions:log`.

---

## Known limitations of this test build

- **The red "Multiple capabilities paused" banner** in Stripe dashboard is expected in sandbox and doesn't affect functionality.
- **CFDI PDFs are branded now** — both the service CFDI and the monthly commission CFDI render the ServiTec template and upload to Storage as `facturas/{facturaId}.pdf`, alongside the signed XML. Reachable in the app: the técnico sees them under **Ganancias → Facturas**, and both parties get a **"Ver factura (PDF)"** button on a paid service's detail screen. Opening one launches the browser.
- **Monthly commission CFDI cron** is deployed but won't run until the 1st of next month. To test manually: `firebase functions:shell` → `monthlyCommissionCron()`.
- **iOS build not verified** — this checklist assumes Android.
- **Marketing SDKs (AppsFlyer/Adjust/Singular) not integrated** — waiting on marketing agency's choice.
