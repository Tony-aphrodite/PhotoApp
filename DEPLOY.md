# Deploy Guide

The full sequence to bring the app from source to a testable integrated APK. Run these on the machine that has Node, Firebase CLI, and the Flutter SDK installed (this repo's local machine, not the sandbox).

Expected total time: **30–90 minutes** first time (mostly waiting on downloads + Firebase's first deploy). Fastest re-deploys after that are ~2–5 minutes.

---

## 0. Prerequisites (one-time)

```powershell
# Install Firebase CLI if you don't have it
npm install -g firebase-tools

# Sign in with the developer email (must be a member of the Firebase project)
firebase login

# Confirm the correct project is selected
firebase use servicios-domicilio-mvp
```

Also make sure the `functions/.env` file has all credentials filled in. Current state should be:

```
STRIPE_SECRET_KEY=sk_test_...           ✅
STRIPE_PUBLISHABLE_KEY=pk_test_...       ✅
STRIPE_PLATFORM_ACCOUNT_ID=acct_...      ✅
STRIPE_WEBHOOK_SECRET=                    ⏳ (added after step 4)
FACTURAPI_API_KEY=sk_test_...            ✅
FACTURAPI_SERVITEC_ORG_ID=XIA...         ✅
PLATFORM_COMMISSION_PCT=12                ✅
```

---

## 1. Install & compile Cloud Functions

```powershell
cd functions
npm install
npm run build
```

**Expected outcome:** `lib/` folder appears with compiled JS.

**Most likely first-time issue:** TypeScript errors from FacturAPI SDK method mismatches. If `npm run build` throws about `.updateLegal`, `.uploadCertificate`, or `.getApiKey`, the installed Facturapi SDK version has different method names. Fix path:

```powershell
# Look at what methods actually exist
node -e "const F = require('facturapi').default || require('facturapi'); const c = new F('sk_test_x'); console.log(Object.keys(c.organizations));"
```

Common substitutions in older/newer SDK versions:
- `.updateLegal(id, data)` → `.updateFiscalData(id, data)` or `.updateLegal(id, {legal: {...}})`
- `.uploadCertificate(id, {cer, key, password})` → sometimes takes `{cerFile, keyFile}` (streams) instead of Buffers
- `.getApiKey(id, 'test')` → sometimes named `.getTestApiKey(id)` or split into two methods

Update `functions/src/setup-technician-fiscal.ts` accordingly, then re-run `npm run build`.

---

## 2. Deploy Firestore rules & indexes

```powershell
cd ..
firebase deploy --only firestore:rules,firestore:indexes
```

**Expected outcome:** rules published, indexes queued for build (indexes take 5–10 min to build; queries needing them will error with a "URL to build index" until then, which is normal).

**Verify:** Firebase Console → Firestore → Rules tab → should show timestamp within the last minute matching the local `firestore.rules` file.

---

## 3. Deploy Cloud Functions

```powershell
firebase deploy --only functions
```

**Expected outcome:** 9 functions deployed:
- `setupTechnicianFiscal` (callable)
- `createPaymentIntent` (HTTPS)
- `createTechnicianConnectOnboardingLink` (callable)
- `getTechnicianConnectStatus` (callable)
- `onPaymentSucceededStripeWebhook` (HTTPS)
- `onChatMessageCreated` (Firestore trigger)
- `onServiceCreated` (Firestore trigger)
- `monthlyCommissionCron` (scheduler)
- `gracePeriodDailyCron` (scheduler)

This codebase replaces the legacy `servitec_app/functions/` — `firebase.json`
points only here, both under codebase `default`. The deploy therefore *deletes*
the old `sendAdvancedNotification`, `generateMonthlyReport` and
`cleanupExpiredServices` from the project. All three were unimplemented
placeholders, so nothing is lost; the CLI will still prompt to confirm the
deletions.

**Copy the deployed URL for `onPaymentSucceededStripeWebhook`** — you need it for step 4. Should look like:
```
https://us-central1-servicios-domicilio-mvp.cloudfunctions.net/onPaymentSucceededStripeWebhook
```

**Watch for errors** in the terminal — most likely: FacturAPI SDK / Stripe SDK missing methods (fix and re-deploy just the failing function via `firebase deploy --only functions:functionName`).

---

## 4. Register the Stripe webhook

1. Open Stripe dashboard → https://dashboard.stripe.com/test/webhooks
2. **"Add endpoint"**
3. Endpoint URL: paste the URL from step 3
4. **Events to send**: select `payment_intent.succeeded`
5. Click **"Add endpoint"**
6. On the webhook detail page, click **"Reveal"** next to Signing secret. Copy the `whsec_...` value.
7. Paste it into `functions/.env`:
   ```
   STRIPE_WEBHOOK_SECRET=whsec_XXXXXXXXX
   ```
8. Re-deploy the webhook function so it picks up the new secret:
   ```powershell
   cd functions
   firebase deploy --only functions:onPaymentSucceededStripeWebhook
   ```

**Verify:** back in Stripe dashboard, on the webhook detail page click **"Send test webhook"** → pick `payment_intent.succeeded` → send. Watch the response — should be `200`.

---

## 5. Build the tester APK

```powershell
cd ..\servitec_app
flutter pub get
flutter build apk --release
```

**Expected outcome:** `build/app/outputs/flutter-apk/app-release.apk` (~30–50 MB).

**Install on a device:**
```powershell
flutter install --release
# or manually:
adb install -r build\app\outputs\flutter-apk\app-release.apk
```

---

## 6. Smoke test the integrated flow

On the installed APK, verify each of these works. See `TESTER_QUICKSTART.md` for the detailed checklist.

Fast smoke:

1. **Register a cliente** → onboarding disclosure modal appears → accept.
2. **Register a técnico** on a second device → same disclosure appears.
3. **Cliente creates a service** → técnico gets a push notification (if FCM permission granted).
4. **Cliente chat: try to send "mi whatsapp es 5512345678"** → server blocks it (message text replaced with a warning).
5. **Técnico opens the fiscal onboarding wizard** → uploads CSD → success → `facturapi.status` on user doc flips to `active` (Firestore Console).
6. **Técnico opens Stripe Connect screen** → clicks "Enlazar" → Stripe hosted onboarding opens in browser → completes flow → returns to app.
7. **Cliente pays** for a completed service via Stripe test card `4242 4242 4242 4242` → payment succeeds → webhook fires → CFDI stamped → transaction appears in earnings screen.

---

## Common gotchas

- **"Multiple capabilities paused"** banner in Stripe dashboard: normal for sandbox, doesn't block anything.
- **Push notifications don't arrive**: check `users/{uid}.fcmToken` in Firestore — if empty, the app didn't call `saveTokenToUser` (check auth_repository log output).
- **CFDI never emitted after payment**: check Cloud Functions logs (`firebase functions:log --only onPaymentSucceededStripeWebhook`) — likely the técnico's `facturapi.organizationApiKey` is missing (they haven't finished fiscal onboarding).
- **Firestore index errors** in console output: click the URL Firestore prints, it builds the index in 5–10 min.
- **Stripe webhook 400 errors**: usually a `STRIPE_WEBHOOK_SECRET` mismatch. Re-copy from dashboard and re-deploy.
