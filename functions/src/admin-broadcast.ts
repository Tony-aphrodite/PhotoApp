/**
 * Callable — an admin sends a push notification to an audience.
 *
 * Audiences: every user, every cliente, every técnico, or one uid. The
 * caller must be an admin per their `users` document; the check is here and
 * not only in the app, because a callable is an HTTPS endpoint anyone
 * signed in could hit directly.
 *
 * Every send is logged to `notificaciones_admin` with the resolved recipient
 * count, so the admin panel can show a history and the client has a record of
 * what was pushed to whom.
 *
 * Fan-out is in chunks: FCM delivery is per token and a large audience should
 * not hold the request open for minutes. A hard cap keeps a typo in the
 * audience picker from paging every account on the platform.
 */

import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { db, admin, FieldValue } from './lib/admin';
import { sendPushToUsers } from './lib/push';

type Audience = 'todos' | 'clientes' | 'tecnicos' | 'usuario';

interface BroadcastInput {
  audience: Audience;
  title: string;
  body: string;
  /** Required when audience === 'usuario'. */
  uid?: string;
}

const MAX_RECIPIENTS = 5000;
const CHUNK = 200;

export const sendAdminBroadcast = onCall<BroadcastInput>(
  { region: 'us-central1', memory: '256MiB', timeoutSeconds: 300 },
  async (req) => {
    const callerUid = req.auth?.uid;
    if (!callerUid) throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');

    const caller = (await db.collection('users').doc(callerUid).get()).data();
    if (caller?.rol !== 'admin') {
      throw new HttpsError('permission-denied', 'Solo administradores.');
    }

    const { audience, title, body, uid } = req.data;
    if (!title?.trim() || !body?.trim()) {
      throw new HttpsError('invalid-argument', 'Título y mensaje son obligatorios.');
    }
    if (title.length > 80 || body.length > 400) {
      throw new HttpsError('invalid-argument', 'Título máx. 80 caracteres, mensaje máx. 400.');
    }

    let recipients: string[] = [];
    if (audience === 'usuario') {
      if (!uid) throw new HttpsError('invalid-argument', 'Falta el uid del usuario.');
      recipients = [uid];
    } else {
      let q: FirebaseFirestore.Query = db.collection('users').where('activo', '==', true);
      if (audience === 'clientes') q = q.where('rol', '==', 'cliente');
      else if (audience === 'tecnicos') q = q.where('rol', '==', 'tecnico');
      else if (audience !== 'todos') {
        throw new HttpsError('invalid-argument', `Audiencia desconocida: ${audience}`);
      }
      // Only users who can actually receive a push. select() keeps the read
      // cheap — we never need the rest of the profile here.
      const snap = await q.select('fcmToken').limit(MAX_RECIPIENTS).get();
      recipients = snap.docs
        .filter((d) => typeof d.data().fcmToken === 'string')
        .map((d) => d.id);
    }

    for (let i = 0; i < recipients.length; i += CHUNK) {
      await sendPushToUsers(recipients.slice(i, i + CHUNK), {
        title: title.trim(),
        body: body.trim(),
        data: { type: 'admin_broadcast' },
      });
    }

    await db.collection('notificaciones_admin').add({
      audience,
      uid: uid ?? null,
      title: title.trim(),
      body: body.trim(),
      recipientCount: recipients.length,
      sentBy: callerUid,
      createdAt: FieldValue.serverTimestamp(),
    });

    return { ok: true, recipientCount: recipients.length };
  },
);
