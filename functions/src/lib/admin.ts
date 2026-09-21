/**
 * Firebase Admin SDK singleton.
 *
 * Every function module imports `db` / `admin` from here so the app is
 * initialized exactly once per container, no matter which function is the
 * cold-start entry point.
 */

import * as admin from 'firebase-admin';

if (admin.apps.length === 0) {
  admin.initializeApp();
}

export const db = admin.firestore();

export { admin };

// Modular Firestore helpers. Use these, not admin.firestore.FieldValue: the
// namespace form comes back undefined under the Functions emulator's
// firebase-admin shim (found by emulator-tests/), and this is the form
// firebase-admin recommends anyway.
export { FieldValue, Timestamp, GeoPoint } from 'firebase-admin/firestore';
