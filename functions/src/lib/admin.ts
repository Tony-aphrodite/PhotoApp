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
