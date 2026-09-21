/**
 * Admin callables for account state the app cannot read on its own.
 *
 *   adminGetAccountStatus — whether each account has verified its email.
 *     That flag lives on the Auth user, which client SDKs can only read for
 *     the signed-in user, so the admin panel asks here.
 *   adminReleasePhone — frees the phone number an account holds, for when
 *     someone registered with a number that is not theirs. The account itself
 *     is untouched; suspending it is a separate, deliberate action.
 *
 * Both check the caller's role server-side: a callable is an HTTPS endpoint
 * any signed-in user could hit directly.
 */

import { onCall, HttpsError, CallableRequest } from 'firebase-functions/v2/https';
import { db, admin, FieldValue } from './lib/admin';
import { releasePhoneClaimsOf } from './lib/phone-claims';

async function requireAdmin(req: CallableRequest<unknown>): Promise<string> {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
  const caller = await db.collection('users').doc(uid).get();
  if (caller.get('rol') !== 'admin') {
    throw new HttpsError('permission-denied', 'Solo administradores.');
  }
  return uid;
}

export const adminGetAccountStatus = onCall<{ uids?: string[] }>(
  { region: 'us-central1', memory: '256MiB' },
  async (req) => {
    await requireAdmin(req);
    const uids = req.data?.uids;
    if (!Array.isArray(uids) || uids.length === 0 || uids.length > 100) {
      throw new HttpsError('invalid-argument', 'Envía entre 1 y 100 uids.');
    }

    const { users } = await admin.auth().getUsers(uids.map((uid) => ({ uid })));
    const status: Record<string, { emailVerified: boolean }> = {};
    users.forEach((u) => {
      status[u.uid] = { emailVerified: u.emailVerified };
    });
    // Uids with no Auth user (profile left behind after a console deletion)
    // are simply absent; the app shows no badge for them.
    return { status };
  },
);

export const adminReleasePhone = onCall<{ uid?: string }>(
  { region: 'us-central1', memory: '256MiB' },
  async (req) => {
    const adminUid = await requireAdmin(req);
    const uid = req.data?.uid;
    if (!uid) throw new HttpsError('invalid-argument', 'Falta el uid.');

    const released = await releasePhoneClaimsOf(uid);

    if (released.length) {
      // Audit trail in the moderation queue, already reviewed, so there is a
      // record of who freed which number and when.
      await db.collection('admin_flags').add({
        type: 'phone_released',
        uid,
        telefonos: released,
        estado: 'revisada',
        revisadoPor: adminUid,
        revisadoAt: FieldValue.serverTimestamp(),
        createdAt: FieldValue.serverTimestamp(),
      });
    }
    return { released };
  },
);
