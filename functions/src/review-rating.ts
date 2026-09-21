/**
 * Firestore trigger — keeps a técnico's average rating in sync with `resenas`.
 *
 * Runs on create, update and delete of any review, recomputes the mean and
 * count for the técnico involved, and writes them onto the user document.
 *
 * Why here and not in the app: firestore.rules block every client — the
 * reviewer, the técnico, and admins alike — from writing `calificacionPromedio`
 * or `totalResenas`. That is the right rule (a rating a client can write is a
 * rating a client can forge), but it means the app-side recompute that used to
 * run after submitting a review was silently denied, and ratings never moved.
 * The Admin SDK bypasses rules, so this is the only place the write can live.
 *
 * Deleting a review from the admin moderation screen lands here too, so the
 * técnico's score corrects itself without the admin doing anything else.
 */

import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { db, admin, FieldValue } from './lib/admin';

export const onReviewWritten = onDocumentWritten(
  {
    document: 'resenas/{reviewId}',
    region: 'us-central1',
  },
  async (event) => {
    // On delete only `before` exists; on create only `after`. Either carries
    // the técnico we need to recompute.
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    const tecnicoId: string | undefined = after?.tecnicoId ?? before?.tecnicoId;
    if (!tecnicoId) return;

    const snap = await db
      .collection('resenas')
      .where('tecnicoId', '==', tecnicoId)
      .get();

    const ratings = snap.docs
      .map((d) => Number(d.data().calificacion))
      .filter((n) => Number.isFinite(n) && n >= 1 && n <= 5);

    const total = ratings.length;
    const promedio = total === 0
      ? 0
      : +(ratings.reduce((a, b) => a + b, 0) / total).toFixed(2);

    await db.collection('users').doc(tecnicoId).update({
      calificacionPromedio: promedio,
      totalResenas: total,
      updatedAt: FieldValue.serverTimestamp(),
    });

    // eslint-disable-next-line no-console
    console.log(`Rating recomputed for ${tecnicoId}: ${promedio} (${total})`);
  },
);
