/**
 * Firestore trigger — a client just created a service request.
 *
 * Every *later* lifecycle event (assignment, cotización, inicio, pago) already
 * reaches both parties: those code paths post a system message into
 * `servicios/{id}/mensajes`, and `onChatMessageCreated` fans that out as a push.
 * Creation is the one event with no chat thread to hang a message on, so it
 * needs its own trigger — this one, which replaces `onServiceCreated` from the
 * legacy `servitec_app/functions` codebase.
 *
 * Two paths, keyed on `tipoAsignacion` (defaults to `automatica`):
 *
 *   automatica → score the eligible técnicos, assign the best one, and post the
 *                "Técnico asignado" system message. The push then rides the
 *                existing chat fan-out, so the técnico is notified exactly once.
 *   manual     → nobody is assigned yet, so notify the admins who will do it and
 *                broadcast to eligible técnicos in case they self-assign.
 *
 * When no técnico matches the category at all, admins are alerted either way —
 * the request would otherwise sit in `pendiente` unnoticed.
 *
 * Scoring is a port of `AutoAssignmentService` in
 * servitec_app/lib/core/utils/auto_assignment_service.dart. Keep them in sync;
 * the Dart copy is currently unreferenced but is the readable spec.
 */

import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { db, admin } from './lib/admin';
import { sendPushToUsers } from './lib/push';

interface ScoredTechnician {
  uid: string;
  nombre: string;
  score: number;
}

/** Haversine distance in km. */
function distanceKm(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number,
): number {
  const earthRadius = 6371;
  const toRad = (deg: number) => (deg * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) *
      Math.cos(toRad(lat2)) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  return earthRadius * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

/** Técnicos who are active, available, and hold the required specialty. */
async function eligibleTechnicians(
  categoria: string,
): Promise<FirebaseFirestore.QueryDocumentSnapshot[]> {
  const snap = await db
    .collection('users')
    .where('rol', '==', 'tecnico')
    .where('disponible', '==', true)
    .where('activo', '==', true)
    .where('especialidades', 'array-contains', categoria)
    .get();
  return snap.docs;
}

async function notifyAdmins(
  title: string,
  body: string,
  data: Record<string, string>,
): Promise<void> {
  const admins = await db
    .collection('users')
    .where('rol', '==', 'admin')
    .where('activo', '==', true)
    .get();
  await sendPushToUsers(
    admins.docs.map((d) => d.id),
    { title, body, data },
  );
}

export const onServiceCreated = onDocumentCreated(
  {
    document: 'servicios/{servicioId}',
    region: 'us-central1',
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const service = snap.data();
    const servicioId = event.params.servicioId as string;

    // Only brand-new, unassigned requests are interesting here.
    if (service.estado !== 'pendiente') return;

    const categoria = (service.categoria as string) || '';
    const titulo = (service.titulo as string) || 'Nuevo servicio';
    const urgencia = (service.urgencia as string) || 'normal';
    const tipoAsignacion = (service.tipoAsignacion as string) || 'automatica';

    const candidates = await eligibleTechnicians(categoria);

    if (candidates.length === 0) {
      // eslint-disable-next-line no-console
      console.log(`No técnicos available for category "${categoria}"`);
      await notifyAdmins(
        'Sin técnicos disponibles',
        `Nadie cubre "${categoria}" para «${titulo}». Se requiere asignación manual.`,
        { type: 'no_technician_available', servicioId, categoria },
      );
      await db.collection('admin_flags').add({
        type: 'no_technician_available',
        servicioId,
        categoria,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return;
    }

    if (tipoAsignacion !== 'automatica') {
      // Manual assignment: the admin picks. Tell them, and let matching
      // técnicos know a job is up for grabs.
      await notifyAdmins(
        'Nuevo servicio pendiente',
        `${categoria}: ${titulo}`,
        { type: 'service_awaiting_assignment', servicioId, categoria },
      );
      await sendPushToUsers(
        candidates.map((d) => d.id),
        {
          title: 'Nuevo servicio disponible',
          body: `${categoria}: ${titulo}`,
          data: { type: 'service_available', servicioId, categoria, urgencia },
        },
      );
      return;
    }

    // ---- Automatic assignment ----

    // Active workload per candidate, used as the main penalty term.
    const workloads = new Map<string, number>();
    await Promise.all(
      candidates.map(async (doc) => {
        const active = await db
          .collection('servicios')
          .where('tecnicoId', '==', doc.id)
          .where('estado', 'in', ['asignado', 'en_progreso'])
          .get();
        workloads.set(doc.id, active.size);
      }),
    );

    const serviceLocation = service.ubicacion as
      | FirebaseFirestore.GeoPoint
      | undefined;

    const scored: ScoredTechnician[] = candidates.map((doc) => {
      const tech = doc.data();
      let score = 0;

      // Rating: 0-5 stars → 0-40 points.
      score += (Number(tech.calificacionPromedio) || 0) * 8;

      // Workload: 0-30 points, losing 10 per service already in flight.
      score += Math.max(0, 30 - (workloads.get(doc.id) ?? 0) * 10);

      // Proximity: 0-20 points, 1 point shed per km.
      const techLocation = tech.ubicacionDefecto as
        | FirebaseFirestore.GeoPoint
        | undefined;
      if (serviceLocation && techLocation) {
        const km = distanceKm(
          serviceLocation.latitude,
          serviceLocation.longitude,
          techLocation.latitude,
          techLocation.longitude,
        );
        score += Math.max(0, 20 - km);
      }

      // Experience: 0-10 points.
      score += Math.min(10, Number(tech.serviciosCompletados) || 0);

      return {
        uid: doc.id,
        nombre: `${tech.nombre ?? ''} ${tech.apellido ?? ''}`.trim(),
        score,
      };
    });

    scored.sort((a, b) => b.score - a.score);
    const best = scored[0];

    await snap.ref.update({
      tecnicoId: best.uid,
      tecnicoNombre: best.nombre,
      estado: 'asignado',
      tipoAsignacion: 'automatica',
      asignadoAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // This single write does double duty: it renders the gray "Técnico
    // asignado" pill in the chat, and onChatMessageCreated turns it into a
    // push for both participants — which is why there is no explicit
    // sendPushToUser here. Adding one would deliver the técnico two
    // notifications a second apart for the same event.
    //
    // Shape matches what Flutter's `ServiceRepository.assignTechnician`
    // writes, so manual and automatic assignment are indistinguishable to
    // the client.
    await snap.ref.collection('mensajes').add({
      userId: 'system',
      nombreUsuario: 'ServiTec',
      mensaje: `Técnico asignado: ${best.nombre}`,
      tipo: 'sistema',
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      leido: false,
      metadata: {
        event: 'technician_assigned',
        tecnicoId: best.uid,
        tipoAsignacion: 'automatica',
      },
    });

    // eslint-disable-next-line no-console
    console.log(
      `Auto-assigned ${best.nombre} (${best.uid}) to ${servicioId} — score ${best.score.toFixed(1)}`,
    );
  },
);
