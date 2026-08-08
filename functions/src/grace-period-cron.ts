/**
 * Daily cron — enforces the fiscal grace period.
 *
 * Transitions técnicos from `grace_period` to `suspended` when their
 * `graciaExpiraAt` is in the past and their CSD is still not uploaded
 * (facturapi.status remains `grace_period` or `pending_csd`).
 *
 * Schedule: 06:00 America/Mexico_City every day.
 */

import { onSchedule } from 'firebase-functions/v2/scheduler';
import { db } from './lib/admin';

export const gracePeriodDailyCron = onSchedule(
  {
    schedule: '0 6 * * *',
    timeZone: 'America/Mexico_City',
    region: 'us-central1',
  },
  async () => {
    const now = new Date();

    const stale = await db
      .collection('users')
      .where('rol', '==', 'tecnico')
      .where('graciaExpiraAt', '<', now)
      .get();

    let suspended = 0;
    for (const doc of stale.docs) {
      const data = doc.data();
      const status: string | undefined = data.facturapi?.status;
      if (status && status !== 'active' && status !== 'suspended') {
        await doc.ref.update({
          'facturapi.status': 'suspended',
          'activo': false,
        });
        suspended++;
      }
    }

    // eslint-disable-next-line no-console
    console.log(`Grace period cron: ${suspended} técnicos suspended`);
  },
);
