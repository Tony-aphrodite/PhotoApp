# Emulator tests

Integration tests that run the real Cloud Functions and security rules in the
Firebase emulators, with Stripe replaced by `stripe-mock.js`.

- `rules.test.js` — Firestore rules as real clients hit them (money fields,
  direct cancels, quotations, phone claims, verified email).
- `flows.test.js` — Phase 1 and Phase 2 end to end: quotes, revisions, stops
  and disputes, the diagnostic visit (hold, charge, credit, minimum, cancels,
  withdrawal, no-show, admin refunds) and the hourly schedule.

Run:

```
cd emulator-tests && npm install   # once
JAVA_HOME=/path/to/jdk-21 ./run.sh
```

Needs a JDK ≥ 21 (firebase-tools requirement) and `functions/.env.demo-servitec`
(git-ignored) with the mock Stripe settings:

```
STRIPE_SECRET_KEY=sk_test_mock
STRIPE_WEBHOOK_SECRET=whsec_test_mock
STRIPE_API_HOST=127.0.0.1
STRIPE_API_PORT=12111
STRIPE_API_PROTOCOL=http
FACTURAPI_API_KEY=sk_test_mock
PLATFORM_COMMISSION_PCT=12
```

`no-watch.js` disables file watching: on machines where other apps use up the
inotify instance limit, the emulators otherwise fail with EMFILE.
