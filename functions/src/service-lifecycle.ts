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
import { ACTIVE_WORK_STATES } from './lib/service-flow-rules';
import { FLUJO, PAGO } from './lib/visit-rules';
import { categoryFlow } from './lib/visit-store';

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

/**
 * Técnicos who are active, available, hold the required specialty, and have
 * verified their email.
 *
 * Verification lives on the Auth user, not the profile, so it is looked up in
 * one batched getUsers() call per 100 candidates. An unverified técnico is held
 * on the app's verification screen and could not act on a job it was given.
 */
async function eligibleTechnicians(
  categoria: string,
  requiresPayouts = false,
): Promise<FirebaseFirestore.QueryDocumentSnapshot[]> {
  const snap = await db
    .collection('users')
    .where('rol', '==', 'tecnico')
    .where('disponible', '==', true)
    .where('activo', '==', true)
    .where('especialidades', 'array-contains', categoria)
    .get();

  const verified = new Set<string>();
  for (let i = 0; i < snap.docs.length; i += 100) {
    const chunk = snap.docs.slice(i, i + 100).map((d) => ({ uid: d.id }));
    const { users } = await admin.auth().getUsers(chunk);
    users.filter((u) => u.emailVerified).forEach((u) => verified.add(u.uid));
  }
  // A diagnostic visit is paid up front to the técnico's Stripe account, so
  // only técnicos who can receive it may take one.
  return snap.docs.filter((d) =>
    verified.has(d.id) && (!requiresPayouts || !!d.get('stripeConnectAccountId')));
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

    // The flow (standard or with a paid diagnostic visit) and the visit fee
    // come from the category config — set here, server-side, so the cliente
    // cannot choose a cheaper flow. categoryFlow() is cached per instance.
    const cat = await categoryFlow(categoria);
    const diag = cat.flujo === FLUJO.diagnostico;
    const flowFields = diag
      ? { flujo: FLUJO.diagnostico, visita: { precio: cat.precioDiagnostico, pagoEstado: PAGO.sinAutorizar } }
      : { flujo: FLUJO.estandar };

    const candidates = await eligibleTechnicians(categoria, diag);

    if (candidates.length === 0 || tipoAsignacion !== 'automatica') {
      // No assignment happens here, so this is the one write that records the flow.
      await snap.ref.update(flowFields);
    }

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
        estado: 'pendiente',
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
        // count() aggregation: billed as one read per 1,000 matches instead
        // of one read per service in flight.
        const active = await db
          .collection('servicios')
          .where('tecnicoId', '==', doc.id)
          .where('estado', 'in', ACTIVE_WORK_STATES)
          .count()
          .get();
        workloads.set(doc.id, active.data().count);
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
      ...flowFields,
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
