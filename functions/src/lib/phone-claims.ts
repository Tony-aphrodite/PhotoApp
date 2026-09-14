/**
 * Helpers for `telefonos/{10 digits}` — the one-account-per-phone claims.
 *
 * The app creates a claim in the same batch as the profile (see
 * AuthRepository._createAccount and firestore.rules). Clients can never
 * delete one, so every release goes through here.
 */

import { db } from './admin';

/**
 * Deletes every claim held by `uid`. Returns the numbers released.
 *
 * Queries by owner rather than trusting `users/{uid}.telefono`: the profile
 * may be gone already (Auth deletion) or hold a number formatted before
 * normalisation existed.
 */
export async function releasePhoneClaimsOf(uid: string): Promise<string[]> {
  const snap = await db.collection('telefonos').where('uid', '==', uid).get();
  if (snap.empty) return [];
  const batch = db.batch();
  snap.docs.forEach((d) => batch.delete(d.ref));
  await batch.commit();
  return snap.docs.map((d) => d.id);
}
