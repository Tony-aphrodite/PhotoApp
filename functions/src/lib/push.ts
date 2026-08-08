/**
 * FCM push delivery.
 *
 * Tokens live on `users/{uid}.fcmToken`, written by the Flutter
 * `NotificationService.saveTokenToUser` on every sign-in. A user with no token
 * (permission denied, or never signed in since the feature shipped) is a silent
 * no-op — never an error, since pushes are best-effort next to the Firestore
 * stream the app already listens on.
 */

import { db, admin } from './admin';

export interface PushPayload {
  title: string;
  body: string;
  /** Extra key/value pairs for client-side routing. Values are coerced to
   * strings — FCM rejects any non-string data value. */
  data?: Record<string, string | number | boolean | null | undefined>;
}

/** FCM error codes that mean the token is permanently dead. */
const DEAD_TOKEN_CODES = new Set([
  'messaging/invalid-registration-token',
  'messaging/registration-token-not-registered',
  'messaging/invalid-argument',
]);

/**
 * Send a notification to one user. Resolves `true` when FCM accepted the
 * message, `false` when there was no token or delivery failed.
 */
export async function sendPushToUser(
  uid: string,
  payload: PushPayload,
): Promise<boolean> {
  if (!uid) return false;

  const userSnap = await db.collection('users').doc(uid).get();
  const token = userSnap.data()?.fcmToken as string | undefined;
  if (!token) return false;

  const data: Record<string, string> = {};
  for (const [key, value] of Object.entries(payload.data ?? {})) {
    if (value !== undefined && value !== null) data[key] = String(value);
  }

  try {
    await admin.messaging().send({
      token,
      notification: { title: payload.title, body: payload.body },
      data,
      android: {
        priority: 'high',
        notification: { channelId: 'servitec_default', sound: 'default' },
      },
      apns: {
        payload: { aps: { sound: 'default', badge: 1 } },
      },
    });
    return true;
  } catch (err: any) {
    if (DEAD_TOKEN_CODES.has(err?.errorInfo?.code || err?.code)) {
      // Stop retrying a token the device will never answer on again.
      await db
        .collection('users')
        .doc(uid)
        .update({ fcmToken: admin.firestore.FieldValue.delete() })
        .catch(() => undefined);
    } else {
      // eslint-disable-next-line no-console
      console.error(`sendPushToUser(${uid}) failed`, err?.message || err);
    }
    return false;
  }
}

/** Fan out the same notification to several users, skipping falsy uids. */
export async function sendPushToUsers(
  uids: Array<string | undefined | null>,
  payload: PushPayload,
): Promise<void> {
  const targets = uids.filter((u): u is string => !!u);
  await Promise.all(targets.map((uid) => sendPushToUser(uid, payload)));
}
