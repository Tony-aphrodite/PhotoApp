#!/usr/bin/env bash
# Runs the rules and flow tests inside the Firebase emulators.
#   JAVA_HOME must point at a JDK >= 21 (firebase-tools requirement).
set -euo pipefail
cd "$(dirname "$0")/.."
(cd functions && npm run build >/dev/null)
export NODE_OPTIONS="--require $(pwd)/emulator-tests/no-watch.js"
npx -y firebase-tools@15 emulators:exec --project demo-servitec \
  --only auth,firestore,functions,pubsub \
  "NODE_OPTIONS= FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 node --test --test-concurrency=1 emulator-tests/rules.test.js emulator-tests/flows.test.js"
