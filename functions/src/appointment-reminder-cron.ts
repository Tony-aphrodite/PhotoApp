/**
 * Hourly cron — reminds both parties about an appointment a day ahead.
 *
 * Each run looks at the hour-wide window starting 24 hours from now, so every
 * appointment is caught exactly once by the run that falls a day before it.
 * `recordatorioEnviadoAt` is written after a successful fan-out and checked on
 * the way in, so a retry (or a schedule change that overlaps windows) can't
 * notify the same people twice.
 *
 * Schedule: on the hour, every hour, Mexico City time.
 *
 * The query filters on `fechaHora` alone — a single-field range Firestore
 * indexes automatically. `estado` is filtered in memory instead of in the
 * query, which keeps this off the composite-index list for the sake of the
 * handful of documents an hour window holds.
 */

import { onSchedule } from 'firebase-functions/v2/scheduler';
import { db, admin } from './lib/admin';
import { sendPushToUsers } from './lib/push';

/** Appointments in these states are still expected to happen. */
const ACTIVE_ESTADOS = new Set(['programada', 'confirmada']);

export const appointmentReminderCron = onSchedule(
  {
    schedule: '0 * * * *',
    timeZone: 'America/Mexico_City',
    region: 'us-central1',
  },
  async () => {
    const now = Date.now();
    const windowStart = new Date(now + 24 * 60 * 60 * 1000);
    const windowEnd = new Date(now + 25 * 60 * 60 * 1000);

    const due = await db
      .collection('citas')
      .where('fechaHora', '>=', windowStart)
      .where('fechaHora', '<', windowEnd)
      .get();

    let sent = 0;

    for (const doc of due.docs) {
      const cita = doc.data();

      if (!ACTIVE_ESTADOS.has(cita.estado)) continue;
      if (cita.recordatorioEnviadoAt) continue;

      const fechaHora: Date =
        cita.fechaHora?.toDate?.() ?? new Date(cita.fechaHora);

      // Service title makes the notification actionable; fall back to a
      // generic line rather than skipping the reminder if it's unreadable.
      let titulo = 'tu servicio';
      if (cita.servicioId) {
        const serviceSnap = await db
          .collection('servicios')
          .doc(cita.servicioId)
          .get();
        titulo = (serviceSnap.data()?.titulo as string) || titulo;
      }

      // 24-hour, to match the HH:mm the agenda screen renders.
      const hora = fechaHora.toLocaleTimeString('es-MX', {
        hour: '2-digit',
        minute: '2-digit',
        hour12: false,
        timeZone: 'America/Mexico_City',
      });
      const lugar = cita.tipo === 'taller' ? 'en el taller' : 'a domicilio';

      await sendPushToUsers([cita.clienteId, cita.tecnicoId], {
        title: 'Recordatorio de cita',
        body: `Mañana a las ${hora}, ${lugar} — ${titulo}`,
        data: {
          type: 'appointment_reminder',
          citaId: doc.id,
          servicioId: cita.servicioId ?? '',
        },
      });

      await doc.ref.update({
        recordatorioEnviadoAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      sent++;
    }

    // eslint-disable-next-line no-console
    console.log(
      `Appointment reminders: ${sent} sent of ${due.size} in window ` +
        `${windowStart.toISOString()} → ${windowEnd.toISOString()}`,
    );
  },
);
