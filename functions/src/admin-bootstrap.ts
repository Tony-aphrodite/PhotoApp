/**
 * Callable — turns the caller's own account into an admin, given the correct
 * setup code.
 *
 * Exists because the only prior path to a first admin account was editing
 * `users/{uid}.rol` by hand in the Firestore console — a workflow that put a
 * non-technical client in the position of hand-editing database documents
 * for something as routine as adding staff. This replaces it with a button
 * in the app: register normally, then activate admin access with a code only
 * the client holds.
 *
 * The code is ADMIN_BOOTSTRAP_CODE in functions/.env — the same secret for
 * every activation, shared by the client with whoever they want to have
 * admin access. Not a one-time bootstrap: promoting a second or third staff
 * member later is meant to be exactly this easy, with no code change and no
 * redeploy.
 *
 * Every successful activation is logged to `admin_bootstrap_log` so the
 * client can see who gained admin access and when.
 */

import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { db, admin } from './lib/admin';

interface BootstrapAdminInput {
  code: string;
}

export const bootstrapAdmin = onCall<BootstrapAdminInput>(
  { region: 'us-central1', memory: '256MiB' },
  async (req) => {
    const uid = req.auth?.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
    }

    const expected = process.env.ADMIN_BOOTSTRAP_CODE;
    if (!expected) {
      // Fails closed: an unconfigured secret must never be treated as "no
      // code required."
      throw new HttpsError(
        'failed-precondition',
        'La activación de administrador no está configurada. Contacta a soporte.',
      );
    }

    const code = (req.data?.code ?? '').trim();
    if (!code || code !== expected) {
      throw new HttpsError('permission-denied', 'Código incorrecto.');
    }

    const userRef = db.collection('users').doc(uid);
    const userSnap = await userRef.get();
    if (!userSnap.exists) {
      throw new HttpsError(
        'not-found',
        'No se encontró tu perfil. Regístrate en la app antes de activar el acceso de administrador.',
      );
    }

    const user = userSnap.data()!;
    if (user.rol === 'admin') {
      return { ok: true, alreadyAdmin: true };
    }

    // Admin SDK bypasses firestore.rules, which is the point: clients can
    // never write `rol: 'admin'` themselves (see the users/{userId} create
    // rule), so this is the one legitimate path to it.
    await userRef.update({ rol: 'admin' });

    await db.collection('admin_bootstrap_log').add({
      uid,
      email: user.email ?? null,
      previousRol: user.rol ?? null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { ok: true, alreadyAdmin: false };
  },
);
