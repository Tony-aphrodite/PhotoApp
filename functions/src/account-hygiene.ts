/**
 * Keeps one-account-per-phone from locking real people out.
 *
 * Registration claims a phone number without proving the registrant owns it
 * (that would take SMS). So someone can sign up with another person's number,
 * never verify the email, and the rightful owner could never register.
 *
 *   unverifiedAccountCleanupCron — daily, deletes accounts that never
 *     verified their email within UNVERIFIED_GRACE_DAYS and never did
 *     anything, releasing their phone number itself.
 *
 * An account deleted in the Firebase console loses only its Auth user: its
 * profile and its phone claim stay, so the person can neither sign in nor
 * register again with the same number (this happened on the dev project,
 * 2026-10-15). Two things clean that up now:
 *
 *   liberarTelefonoHuerfano — called by the app when registration is refused
 *     because the number is taken. If the claim's owner no longer exists in
 *     Auth, the claim is released on the spot and the app retries. A number
 *     whose owner still exists is never released this way.
 *   releaseOrphanedAccounts — part of the daily cron: every claim whose Auth
 *     user is gone is released, and its profile removed (or switched off when
 *     it has services, so the history keeps its names).
 *
 * The admin panel's adminReleasePhone remains for numbers held by accounts
 * that do exist. (There used to be an Auth onDelete trigger; those exist only
 * in 1st-gen functions, which stop at Node 22 and timed out the deploy.)
 */

import { onSchedule } from 'firebase-functions/v2/scheduler';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { db, admin, FieldPath, FieldValue } from './lib/admin';
import { releasePhoneClaimsOf } from './lib/phone-claims';
import { CALLABLE_OPTS } from './lib/callable-options';
import { rateLimit } from './lib/rate-limit';

/** Days an account may stay unverified before it is removed. */
export const UNVERIFIED_GRACE_DAYS = 7;

/**
 * Accounts created before email verification existed are never removed by
 * the cron — they include the client's own accounts and every QA account made
 * before this release, none of which were ever asked to verify.
 */
const VERIFICATION_LAUNCH = Date.parse('2026-09-15T00:00:00Z');

async function hasActivity(uid: string): Promise<boolean> {
  const [asCliente, asTecnico] = await Promise.all([
    db.collection('servicios').where('clienteId', '==', uid).limit(1).get(),
    db.collection('servicios').where('tecnicoId', '==', uid).limit(1).get(),
  ]);
  return !asCliente.empty || !asTecnico.empty;
}

export const unverifiedAccountCleanupCron = onSchedule(
  {
    schedule: '30 4 * * *',
    timeZone: 'America/Mexico_City',
    region: 'us-central1',
    timeoutSeconds: 540,
  },
  async () => {
    const cutoff = Date.now() - UNVERIFIED_GRACE_DAYS * 24 * 60 * 60 * 1000;
    let deleted = 0;
    let keptActive = 0;
    let pageToken: string | undefined;

    do {
      const page = await admin.auth().listUsers(1000, pageToken);
      pageToken = page.pageToken;

      for (const user of page.users) {
        if (user.emailVerified) continue;
        const created = Date.parse(user.metadata.creationTime);
        if (created < VERIFICATION_LAUNCH || created > cutoff) continue;

        const profile = await db.collection('users').doc(user.uid).get();
        if (profile.get('rol') === 'admin') continue;

        // Anything that touched a real service is a person, not a squatter;
        // leave the decision to an admin.
        if (await hasActivity(user.uid)) {
          keptActive++;
          continue;
        }

        await releasePhoneClaimsOf(user.uid);
        if (profile.exists) await profile.ref.delete();
        await admin.auth().deleteUser(user.uid);
        deleted++;
        // eslint-disable-next-line no-console
        console.log(`Removed unverified account ${user.uid} (${user.email}), created ${user.metadata.creationTime}`);
      }
    } while (pageToken);

    const orphans = await releaseOrphanedAccounts();
    // eslint-disable-next-line no-console
    console.log(
      `Unverified cleanup: ${deleted} removed, ${keptActive} kept because they have services. ` +
      `Orphans: ${orphans.huerfanos} of ${orphans.revisados} phone claims had no Auth user.`,
    );
  },
);

async function authUserExists(uid: string): Promise<boolean> {
  try {
    await admin.auth().getUser(uid);
    return true;
  } catch (err) {
    if ((err as { code?: string }).code === 'auth/user-not-found') return false;
    throw err;
  }
}

/**
 * Cleans up after an account whose Auth user is gone: releases its phone
 * claims and removes its profile — or, if it took part in services, keeps the
 * profile (the services still show its name) but switches it off.
 */
export async function cleanUpOrphan(uid: string): Promise<void> {
  await releasePhoneClaimsOf(uid);
  const ref = db.collection('users').doc(uid);
  const profile = await ref.get();
  if (!profile.exists || profile.get('rol') === 'admin') return;
  if (await hasActivity(uid)) {
    await ref.update({ activo: false, disponible: false, cuentaEliminada: true });
  } else {
    await ref.delete();
  }
}

/** Daily sweep: every phone claim whose owner no longer exists in Auth. */
export async function releaseOrphanedAccounts(): Promise<{ revisados: number; huerfanos: number }> {
  let revisados = 0;
  let huerfanos = 0;
  let last: string | undefined;
  for (;;) {
    let query = db.collection('telefonos').orderBy(FieldPath.documentId()).limit(300);
    if (last) query = query.startAfter(last);
    const page = await query.get();
    if (page.empty) break;
    last = page.docs[page.docs.length - 1].id;
    revisados += page.size;

    const uids = [...new Set(page.docs.map((d) => d.get('uid') as string).filter(Boolean))];
    for (let i = 0; i < uids.length; i += 100) {
      const { notFound } = await admin.auth().getUsers(uids.slice(i, i + 100).map((uid) => ({ uid })));
      for (const missing of notFound) {
        const uid = (missing as { uid?: string }).uid;
        if (!uid) continue;
        await cleanUpOrphan(uid);
        huerfanos++;
        // eslint-disable-next-line no-console
        console.log(`Released the phone claim and profile of deleted account ${uid}`);
      }
    }
    if (page.size < 300) break;
  }
  return { revisados, huerfanos };
}

/**
 * Registration was refused because the number is taken. If the account that
 * holds it was deleted (no Auth user), release it so the caller can retry;
 * a number whose owner still exists stays taken. The caller is the account
 * being created, signed in but not yet verified — so no email check here.
 */
export const liberarTelefonoHuerfano = onCall<{ telefono?: string }>(CALLABLE_OPTS, async (req) => {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
  rateLimit(uid, 'externo');
  const telefono = String(req.data?.telefono ?? '');
  if (!/^[2-9][0-9]{9}$/.test(telefono)) {
    throw new HttpsError('invalid-argument', 'Teléfono inválido.');
  }

  const claim = await db.collection('telefonos').doc(telefono).get();
  if (!claim.exists) return { liberado: true };
  const owner = claim.get('uid') as string;
  if (owner === uid) return { liberado: true };
  if (await authUserExists(owner)) return { liberado: false };

  await cleanUpOrphan(owner);
  await db.collection('admin_flags').add({
    type: 'phone_released',
    telefono,
    uidAnterior: owner,
    motivo: 'La cuenta dueña del número había sido eliminada; se liberó al registrarse alguien con ese número.',
    estado: 'pendiente',
    createdAt: FieldValue.serverTimestamp(),
  });
  return { liberado: true };
});
