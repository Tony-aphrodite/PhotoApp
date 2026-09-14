/**
 * Keeps one-account-per-phone from locking real people out.
 *
 * Registration claims a phone number without proving the registrant owns it
 * (that would take SMS). So someone can sign up with another person's number,
 * never verify the email, and the rightful owner could never register. Two
 * jobs close that:
 *
 *   unverifiedAccountCleanupCron — daily, deletes accounts that never
 *     verified their email within UNVERIFIED_GRACE_DAYS and never did
 *     anything, releasing their phone number.
 *   onAuthUserDeleted — whenever an Auth user is deleted by any route
 *     (this cron, the Firebase console, the Admin SDK), releases its claim.
 *     Without it, deleting an account in the console left the number
 *     blocked forever.
 *
 * A number squatted by an account that *did* verify an email is released by
 * an admin from the panel (adminReleasePhone).
 */

import * as functionsV1 from 'firebase-functions/v1';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { db, admin } from './lib/admin';
import { releasePhoneClaimsOf } from './lib/phone-claims';

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

    // eslint-disable-next-line no-console
    console.log(
      `Unverified cleanup: ${deleted} removed, ${keptActive} kept because they have services.`,
    );
  },
);

// Auth deletion triggers exist only in the 1st-gen API.
export const onAuthUserDeleted = functionsV1
  .region('us-central1')
  .auth.user()
  .onDelete(async (user) => {
    const released = await releasePhoneClaimsOf(user.uid);
    if (released.length) {
      // eslint-disable-next-line no-console
      console.log(`Released phone claim(s) ${released.join(', ')} of deleted user ${user.uid}`);
    }
  });
