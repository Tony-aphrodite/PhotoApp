/**
 * Shared plumbing for the callables that move a service through its flow
 * (service-flow.ts, visit-flow.ts): auth checks, transactional reads, and the
 * chat narration that doubles as the push notification.
 */

import { HttpsError, CallableRequest } from 'firebase-functions/v2/https';
import { db, admin } from './admin';
import { FlowError } from './service-flow-rules';

export type Tx = FirebaseFirestore.Transaction;
export type Data = FirebaseFirestore.DocumentData;
export type WriteTarget = Tx | FirebaseFirestore.WriteBatch;

export const OPTS = { region: 'us-central1', memory: '256MiB' as const };
export const now = () => admin.firestore.FieldValue.serverTimestamp();

/** Signed in with a verified email; returns the uid. */
export function requireVerified(req: CallableRequest<unknown>): string {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
  if (req.auth?.token.email_verified !== true) {
    throw new HttpsError('failed-precondition', 'Verifica tu correo antes de continuar.');
  }
  return uid;
}

/** The caller's role, checked server-side against users/{uid}. */
export async function isAdminUid(uid: string): Promise<boolean> {
  const caller = await db.collection('users').doc(uid).get();
  return caller.get('rol') === 'admin';
}

/** Runs `fn`, turning a broken flow rule into a user-facing HttpsError. */
export async function guarded<T>(fn: () => Promise<T>): Promise<T> {
  try {
    return await fn();
  } catch (err) {
    if (err instanceof FlowError) throw new HttpsError('failed-precondition', err.message);
    throw err;
  }
}

export async function readService(tx: Tx, servicioId: unknown) {
  if (typeof servicioId !== 'string' || !servicioId) {
    throw new HttpsError('invalid-argument', 'Falta el servicio.');
  }
  const ref = db.collection('servicios').doc(servicioId);
  const snap = await tx.get(ref);
  if (!snap.exists) throw new HttpsError('not-found', 'Servicio no encontrado.');
  return { ref, id: servicioId, data: snap.data() as Data };
}

/** Posts a grey system pill into the service chat; chat-message-guard turns
 * it into a push for both participants. */
export function systemMessage(w: WriteTarget, servicioId: string, mensaje: string, metadata: Data) {
  const ref = db.collection('servicios').doc(servicioId).collection('mensajes').doc();
  const doc = {
    userId: 'system',
    nombreUsuario: 'ServiTec',
    mensaje,
    tipo: 'sistema',
    timestamp: now(),
    leido: false,
    metadata,
  };
  // Both Transaction and WriteBatch expose set(ref, data).
  (w as FirebaseFirestore.WriteBatch).set(ref, doc);
}

export function wrongState(): never {
  throw new FlowError(
    'El servicio cambió de estado. Actualiza la pantalla e inténtalo de nuevo.',
  );
}
