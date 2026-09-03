#!/usr/bin/env node
/**
 * Provisions the ServiTec admin account.
 *
 * The client asked for the simplest possible thing: an admin email and
 * password that already exist, so signing in on the normal login screen lands
 * straight on the admin panel — no activation code, no extra screen, no
 * hand-editing `users/{uid}.rol` in the Firestore console.
 *
 * That means the account has to be created somewhere outside the app, because
 * firestore.rules deliberately forbid a client from ever writing
 * `rol: 'admin'` on its own document (see the users/{userId} create rule).
 * This script is that "somewhere": it runs as a step in the deploy workflow,
 * with the same Admin SDK credentials the function deploy already uses, so
 * the Admin SDK bypasses rules legitimately.
 *
 * Idempotent by design — it runs on every deploy:
 *   - creates the Auth user if the email is new
 *   - resets the password if the account already exists, so rotating the
 *     password is just "change the secret and redeploy"
 *   - upserts users/{uid} with rol: 'admin' and activo: true
 *
 * Reads ADMIN_EMAIL and ADMIN_PASSWORD from the environment. If either is
 * missing it exits 0 without doing anything, so a deploy is never blocked by
 * an unconfigured admin account.
 */

const admin = require('firebase-admin');

async function main() {
  const email = (process.env.ADMIN_EMAIL || '').trim();
  const password = process.env.ADMIN_PASSWORD || '';

  if (!email || !password) {
    console.log(
      'ADMIN_EMAIL / ADMIN_PASSWORD not set — skipping admin provisioning.',
    );
    return;
  }
  if (password.length < 6) {
    // Firebase itself rejects shorter passwords; failing here gives a clearer
    // message than a raw auth/weak-password further down.
    throw new Error('ADMIN_PASSWORD must be at least 6 characters.');
  }

  admin.initializeApp();
  const auth = admin.auth();
  const db = admin.firestore();

  let user;
  try {
    user = await auth.getUserByEmail(email);
    // Already exists: realign the password with the secret rather than
    // leaving a stale one nobody remembers.
    await auth.updateUser(user.uid, { password, emailVerified: true });
    console.log(`Admin auth user already existed, password reset: ${email}`);
  } catch (err) {
    if (err.code !== 'auth/user-not-found') throw err;
    user = await auth.createUser({
      email,
      password,
      emailVerified: true,
      displayName: 'ServiTec Admin',
    });
    console.log(`Admin auth user created: ${email}`);
  }

  const ref = db.collection('users').doc(user.uid);
  const snap = await ref.get();

  // merge:true so re-running never clobbers a profile photo, phone number or
  // anything else the admin has since edited in the app.
  await ref.set(
    {
      uid: user.uid,
      email,
      rol: 'admin',
      activo: true,
      // Only seed the display fields when the document is new; on an existing
      // account these are the admin's own to change.
      ...(snap.exists
        ? {}
        : {
            nombre: 'ServiTec',
            apellido: 'Admin',
            telefono: '',
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            // The off-platform disclosure modal is aimed at clientes and
            // técnicos; pre-accepting it keeps it from greeting the admin.
            disclosureAcceptedAt: admin.firestore.FieldValue.serverTimestamp(),
          }),
    },
    { merge: true },
  );

  console.log(
    snap.exists
      ? `Admin profile updated (rol=admin): ${user.uid}`
      : `Admin profile created (rol=admin): ${user.uid}`,
  );
  console.log('Sign in on the app login screen with this email and password.');
}

main().catch((err) => {
  console.error('Admin provisioning failed:', err.message || err);
  process.exit(1);
});
