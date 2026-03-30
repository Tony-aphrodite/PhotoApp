/**
 * ServiTec Cloud Functions
 *
 * Deploy: firebase deploy --only functions
 *
 * Required env vars:
 *   firebase functions:config:set stripe.secret_key="sk_test_..."
 *   firebase functions:config:set stripe.webhook_secret="whsec_..."
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();

const db = admin.firestore();

// Lazy-load Stripe to avoid cold start overhead
let stripe: any;
function getStripe() {
  if (!stripe) {
    const Stripe = require("stripe");
    stripe = new Stripe(functions.config().stripe.secret_key);
  }
  return stripe;
}

/**
 * Create a Stripe PaymentIntent
 * Called by the Flutter app when client initiates payment
 */
export const createPaymentIntent = functions.https.onRequest(
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method not allowed");
      return;
    }

    try {
      const { servicioId, amount, currency } = req.body;

      if (!servicioId || !amount) {
        res.status(400).send({ error: "Missing servicioId or amount" });
        return;
      }

      // Verify service exists and is in correct state
      const serviceDoc = await db
        .collection("servicios")
        .doc(servicioId)
        .get();

      if (!serviceDoc.exists) {
        res.status(404).send({ error: "Service not found" });
        return;
      }

      const serviceData = serviceDoc.data()!;
      if (
        serviceData.estado !== "pago_pendiente" &&
        serviceData.estado !== "completado"
      ) {
        res
          .status(400)
          .send({ error: "Service is not ready for payment" });
        return;
      }

      // Create PaymentIntent
      const paymentIntent = await getStripe().paymentIntents.create({
        amount: Math.round(amount), // already in cents from client
        currency: currency || "usd",
        metadata: {
          servicioId,
          clienteId: serviceData.clienteId,
          tecnicoId: serviceData.tecnicoId || "",
        },
      });

      res.status(200).send({
        clientSecret: paymentIntent.client_secret,
        paymentIntentId: paymentIntent.id,
      });
    } catch (error: any) {
      console.error("Error creating PaymentIntent:", error);
      res.status(500).send({ error: error.message });
    }
  }
);

/**
 * Handle Stripe Webhook events
 * Processes payment_intent.succeeded and payment_intent.failed
 */
export const handleStripeWebhook = functions.https.onRequest(
  async (req, res) => {
    const sig = req.headers["stripe-signature"] as string;
    const webhookSecret = functions.config().stripe.webhook_secret;

    let event;
    try {
      event = getStripe().webhooks.constructEvent(
        req.rawBody,
        sig,
        webhookSecret
      );
    } catch (err: any) {
      console.error("Webhook signature verification failed:", err.message);
      res.status(400).send(`Webhook Error: ${err.message}`);
      return;
    }

    try {
      switch (event.type) {
        case "payment_intent.succeeded":
          await handlePaymentSuccess(event.data.object);
          break;
        case "payment_intent.failed":
          await handlePaymentFailed(event.data.object);
          break;
        default:
          console.log(`Unhandled event type: ${event.type}`);
      }

      res.status(200).send({ received: true });
    } catch (error: any) {
      console.error("Error processing webhook:", error);
      res.status(500).send({ error: error.message });
    }
  }
);

/**
 * Handle successful payment
 * Includes idempotency check to prevent duplicate processing from webhook retries
 */
async function handlePaymentSuccess(paymentIntent: any) {
  const { servicioId, clienteId, tecnicoId } = paymentIntent.metadata;

  if (!servicioId) {
    console.error("No servicioId in payment metadata");
    return;
  }

  // --- IDEMPOTENCY CHECK ---
  // Verify this payment hasn't already been processed
  const existingTx = await db
    .collection("transacciones")
    .where("stripePaymentIntentId", "==", paymentIntent.id)
    .limit(1)
    .get();

  if (!existingTx.empty) {
    console.log(
      `Payment already processed for PaymentIntent: ${paymentIntent.id}. Skipping duplicate.`
    );
    return;
  }

  // Verify service is in a valid state for payment processing
  const serviceDoc = await db.collection("servicios").doc(servicioId).get();
  if (!serviceDoc.exists) {
    console.error(`Service ${servicioId} not found during payment processing`);
    return;
  }

  const serviceData = serviceDoc.data()!;
  if (serviceData.estado === "pagado") {
    console.log(`Service ${servicioId} already marked as paid. Skipping.`);
    return;
  }

  // --- COMMISSION CALCULATION ---
  // Get commission config from admin settings
  const configDoc = await db
    .collection("configuracion")
    .doc("comisiones")
    .get();
  const porcentajePlataforma = configDoc.exists
    ? configDoc.data()?.porcentajePlataforma || 15
    : 15;

  const montoTotal = paymentIntent.amount / 100; // cents to dollars
  const comisionPlataforma = parseFloat(
    (montoTotal * (porcentajePlataforma / 100)).toFixed(2)
  );
  const comisionStripe = parseFloat((montoTotal * 0.029 + 0.3).toFixed(2));
  const montoTecnico = parseFloat(
    (montoTotal - comisionPlataforma - comisionStripe).toFixed(2)
  );

  // --- ATOMIC BATCH WRITE ---
  const batch = db.batch();

  // Create transaction record with full financial breakdown
  const txRef = db.collection("transacciones").doc();
  batch.set(txRef, {
    servicioId,
    clienteId,
    tecnicoId,
    montoTotal,
    comisionPlataforma,
    comisionStripe,
    montoTecnico,
    porcentajeComision: porcentajePlataforma,
    stripePaymentIntentId: paymentIntent.id,
    stripeChargeId: paymentIntent.latest_charge || null,
    estado: "completado",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    completedAt: admin.firestore.FieldValue.serverTimestamp(),
    metadata: {
      metodoPago: "tarjeta",
      moneda: paymentIntent.currency || "usd",
    },
  });

  // Update service with payment information
  const serviceRef = db.collection("servicios").doc(servicioId);
  batch.update(serviceRef, {
    estado: "pagado",
    montoPagado: montoTotal,
    comisionPlataforma,
    montoTecnico,
    estadoPago: "pagado",
    stripePaymentIntentId: paymentIntent.id,
    stripePaymentStatus: "succeeded",
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Update technician's completed service count
  if (tecnicoId) {
    const techRef = db.collection("users").doc(tecnicoId);
    batch.update(techRef, {
      serviciosCompletados: admin.firestore.FieldValue.increment(1),
    });
  }

  await batch.commit();

  // --- STRUCTURED LOG for auditing ---
  const logEntry = {
    type: "TRANSACTION_COMPLETED",
    transaccionId: txRef.id,
    servicioId,
    clienteId,
    tecnicoId,
    montoTotal,
    comisionPlataforma,
    comisionStripe,
    montoTecnico,
    porcentajeComision: porcentajePlataforma,
    stripePaymentIntentId: paymentIntent.id,
    estado: "completado",
    timestamp: new Date().toISOString(),
  };

  console.log("FINANCIAL_LOG:", JSON.stringify(logEntry));

  // --- SEND NOTIFICATIONS ---
  await sendPaymentNotifications(servicioId, clienteId, tecnicoId, montoTotal, montoTecnico);
}

/**
 * Send push notifications after successful payment
 */
async function sendPaymentNotifications(
  servicioId: string,
  clienteId: string,
  tecnicoId: string,
  montoTotal: number,
  montoTecnico: number
) {
  try {
    // Notify client: payment confirmed
    if (clienteId) {
      const clientDoc = await db.collection("users").doc(clienteId).get();
      const clientToken = clientDoc.data()?.fcmToken;
      if (clientToken) {
        await admin.messaging().send({
          token: clientToken,
          notification: {
            title: "Pago Confirmado",
            body: `Tu pago de $${montoTotal.toFixed(2)} ha sido procesado exitosamente.`,
          },
          data: { servicioId, type: "payment_confirmed" },
        });
      }
    }

    // Notify technician: payment received
    if (tecnicoId) {
      const techDoc = await db.collection("users").doc(tecnicoId).get();
      const techToken = techDoc.data()?.fcmToken;
      if (techToken) {
        await admin.messaging().send({
          token: techToken,
          notification: {
            title: "Pago Recibido",
            body: `Has recibido $${montoTecnico.toFixed(2)} por tu servicio completado.`,
          },
          data: { servicioId, type: "payment_received" },
        });
      }
    }
  } catch (error: any) {
    // Notification failures should not block payment processing
    console.error("Error sending payment notifications:", error.message);
  }
}

/**
 * Handle failed payment
 * Updates service status and notifies the client to retry
 */
async function handlePaymentFailed(paymentIntent: any) {
  const { servicioId, clienteId } = paymentIntent.metadata;

  if (!servicioId) return;

  await db.collection("servicios").doc(servicioId).update({
    stripePaymentStatus: "failed",
    estadoPago: "fallido",
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Log failed payment for monitoring
  console.log("FINANCIAL_LOG:", JSON.stringify({
    type: "PAYMENT_FAILED",
    servicioId,
    clienteId,
    stripePaymentIntentId: paymentIntent.id,
    failureMessage: paymentIntent.last_payment_error?.message || "Unknown error",
    timestamp: new Date().toISOString(),
  }));

  // Notify client about failed payment
  if (clienteId) {
    try {
      const clientDoc = await db.collection("users").doc(clienteId).get();
      const clientToken = clientDoc.data()?.fcmToken;
      if (clientToken) {
        await admin.messaging().send({
          token: clientToken,
          notification: {
            title: "Error en el Pago",
            body: "Tu pago no pudo ser procesado. Por favor, intenta de nuevo.",
          },
          data: { servicioId, type: "payment_failed" },
        });
      }
    } catch (error: any) {
      console.error("Error sending failure notification:", error.message);
    }
  }
}

/**
 * Auto-assign technician when service is created with tipoAsignacion = "automatica"
 * Triggered on service creation
 */
export const onServiceCreated = functions.firestore
  .document("servicios/{servicioId}")
  .onCreate(async (snap, context) => {
    const data = snap.data();

    if (data.tipoAsignacion !== "automatica") return;
    if (data.estado !== "pendiente") return;

    // Find best available technician
    const techSnap = await db
      .collection("users")
      .where("rol", "==", "tecnico")
      .where("disponible", "==", true)
      .where("activo", "==", true)
      .where("especialidades", "array-contains", data.categoria)
      .get();

    if (techSnap.empty) {
      console.log(`No technicians available for category: ${data.categoria}`);
      // Notify admin: auto-assignment failed, manual intervention required
      await notifyAdminNoTechnicianAvailable(
        context.params.servicioId,
        data.categoria,
        data.descripcion || "Sin descripción"
      );
      return;
    }

    // Score technicians (simplified)
    let bestTech: any = null;
    let bestScore = -1;

    for (const doc of techSnap.docs) {
      const tech = doc.data();
      let score = 0;
      score += (tech.calificacionPromedio || 0) * 8;
      score += Math.max(0, 30 - (tech.serviciosCompletados || 0) > 50 ? 0 : 10);
      score += Math.min(10, tech.serviciosCompletados || 0);

      if (score > bestScore) {
        bestScore = score;
        bestTech = { id: doc.id, ...tech };
      }
    }

    if (bestTech) {
      await snap.ref.update({
        tecnicoId: bestTech.id,
        tecnicoNombre: `${bestTech.nombre} ${bestTech.apellido}`,
        estado: "asignado",
        asignadoAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(
        `Auto-assigned technician ${bestTech.nombre} to service ${context.params.servicioId}`
      );

      // Notify assigned technician via push
      await notifyTechnicianAssigned(
        bestTech.id,
        bestTech.fcmToken,
        context.params.servicioId,
        data.categoria,
        data.descripcion || "Nuevo servicio asignado"
      );
    }
  });

/**
 * Send push notification to the auto-assigned technician
 */
async function notifyTechnicianAssigned(
  technicianId: string,
  fcmToken: string | undefined,
  servicioId: string,
  categoria: string,
  descripcion: string
) {
  try {
    let token = fcmToken;

    // Refresh token from DB in case it was updated
    if (!token) {
      const techDoc = await db.collection("users").doc(technicianId).get();
      token = techDoc.data()?.fcmToken;
    }

    if (!token) {
      console.log(`Technician ${technicianId} has no FCM token — skipping push notification`);
      return;
    }

    await admin.messaging().send({
      token,
      notification: {
        title: "Nuevo Servicio Asignado",
        body: `${categoria}: ${descripcion}`,
      },
      data: {
        servicioId,
        type: "service_assigned",
        categoria,
      },
      android: {
        priority: "high",
      },
      apns: {
        payload: {
          aps: { sound: "default", badge: 1 },
        },
      },
    });

    console.log(`Push notification sent to technician ${technicianId} for service ${servicioId}`);
  } catch (error: any) {
    console.error("Error sending technician assignment notification:", error.message);
  }
}

/**
 * Notify all admins when auto-assignment fails (no technician available)
 */
async function notifyAdminNoTechnicianAvailable(
  servicioId: string,
  categoria: string,
  descripcion: string
) {
  try {
    // Find all admin users
    const adminSnap = await db
      .collection("users")
      .where("rol", "==", "admin")
      .where("activo", "==", true)
      .get();

    const notifications = adminSnap.docs
      .map((doc) => doc.data()?.fcmToken)
      .filter(Boolean)
      .map((token: string) =>
        admin.messaging().send({
          token,
          notification: {
            title: "Asignación Automática Fallida",
            body: `Sin técnicos disponibles para ${categoria}. Asignación manual requerida.`,
          },
          data: {
            servicioId,
            type: "auto_assign_failed",
            categoria,
          },
          android: { priority: "high" },
          apns: { payload: { aps: { sound: "default", badge: 1 } } },
        })
      );

    await Promise.allSettled(notifications);

    console.log(`Admin fallback notifications sent for service ${servicioId} (${categoria})`);
  } catch (error: any) {
    console.error("Error sending admin fallback notification:", error.message);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PLACEHOLDER FUNCTIONS — Ready for future implementation
// ─────────────────────────────────────────────────────────────────────────────

/**
 * [PLACEHOLDER] sendAdvancedNotification
 * Future feature: Send notifications with dynamic content, deep links,
 * and action buttons (e.g. "View service", "Accept", "Reject").
 *
 * Triggered by: HTTPS callable from Flutter app
 * Requires: notification template ID, target user IDs, deep link URL
 */
export const sendAdvancedNotification = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Authentication required"
      );
    }

    // TODO: Implement
    // 1. Load notification template from Firestore (templates/{templateId})
    // 2. Render dynamic content with data variables
    // 3. Resolve target user FCM tokens
    // 4. Send with deep link and action buttons
    // 5. Log delivery status per recipient

    console.log("[PLACEHOLDER] sendAdvancedNotification called — not yet implemented", data);
    return { success: false, message: "Not yet implemented" };
  }
);

/**
 * [PLACEHOLDER] generateMonthlyReport
 * Future feature: Auto-generate monthly financial report for the admin.
 * Runs on the 1st of each month at 08:00 Mexico City time.
 *
 * Triggered by: Cloud Scheduler (cron: "0 8 1 * *")
 * Outputs: PDF report saved to Firebase Storage + email to admin
 */
export const generateMonthlyReport = functions.pubsub
  .schedule("0 8 1 * *")
  .timeZone("America/Mexico_City")
  .onRun(async (_context) => {
    // TODO: Implement
    // 1. Query all transactions for the previous month
    // 2. Calculate aggregates (total revenue, commission, per-technician breakdown)
    // 3. Generate PDF using a template
    // 4. Upload PDF to Firebase Storage: reports/{year}/{month}/reporte_financiero.pdf
    // 5. Send email to admin with PDF attached
    // 6. Save report metadata to Firestore: reportes/{year-month}

    console.log("[PLACEHOLDER] generateMonthlyReport — not yet implemented");
    return null;
  });

/**
 * [PLACEHOLDER] cleanupExpiredServices
 * Future feature: Archive services cancelled more than 30 days ago
 * to keep the main collection lean and reduce query costs.
 *
 * Triggered by: Cloud Scheduler (cron: "0 3 * * *") — daily at 03:00 AM
 * Effect: Moves old cancelled services to servicios_archivados collection
 */
export const cleanupExpiredServices = functions.pubsub
  .schedule("0 3 * * *")
  .timeZone("America/Mexico_City")
  .onRun(async (_context) => {
    // TODO: Implement
    // 1. Query servicios where estado = "cancelado" AND updatedAt < 30 days ago
    // 2. For each: copy document to servicios_archivados/{id}
    // 3. Delete original from servicios/{id}
    // 4. Log count of archived services

    const cutoff = new Date();
    cutoff.setDate(cutoff.getDate() - 30);

    const expiredSnap = await db
      .collection("servicios")
      .where("estado", "==", "cancelado")
      .where("updatedAt", "<", cutoff)
      .get();

    console.log(
      `[PLACEHOLDER] cleanupExpiredServices — found ${expiredSnap.size} candidates (not yet archiving)`
    );
    return null;
  });
