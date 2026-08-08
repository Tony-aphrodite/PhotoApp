/**
 * Stripe webhook — fired after a customer's payment succeeds.
 *
 * Payment model: destination charge with `on_behalf_of` (see
 * create-payment-intent.ts). The técnico is the settlement merchant; the
 * platform retains 12% as `application_fee_amount`. The PaymentIntent lives
 * on the platform account, so this webhook must be registered as a
 * **platform-account webhook** (NOT a Connect webhook) in the Stripe
 * dashboard.
 *
 * Steps:
 *   1. Verify Stripe signature.
 *   2. Load `servicioId` from PaymentIntent metadata → fetch the service +
 *      técnico documents.
 *   3. Stamp the CFDI técnico → cliente via FacturAPI (using the técnico's
 *      per-organization API key stored on the user document).
 *   4. Generate the ServiTec-branded PDF from the returned XML.
 *   5. Persist both XML and PDF to Cloud Storage.
 *   6. Insert a row in `facturas` (tipo: tecnico_cliente).
 *   7. Post a system message into the service chat.
 *   8. Record the transaction in Firestore for the earnings / commissions view.
 *
 * The 12% commission is NOT invoiced here — the monthly cron aggregates it.
 */

import { onRequest } from 'firebase-functions/v2/https';
import { db, admin } from './lib/admin';
import { stripe } from './lib/stripe';
import { facturapiForOrg } from './lib/facturapi';
import { renderBrandedCfdiPdf } from './lib/pdf';
import { uploadCfdiXml, uploadCfdiPdf } from './lib/storage';
import {
  downloadAsBuffer,
  extractXmlAttr,
  buildCadenaOriginalTfd,
} from './lib/cfdi-xml';

export const onPaymentSucceededStripeWebhook = onRequest(
  { region: 'us-central1', memory: '512MiB' },
  async (req, res) => {
    const sig = req.headers['stripe-signature'];
    const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;
    if (!sig || !webhookSecret) {
      res.status(400).send('Missing signature or webhook secret');
      return;
    }

    let event;
    try {
      event = stripe.webhooks.constructEvent(
        (req as any).rawBody,
        sig,
        webhookSecret,
      );
    } catch (err) {
      res.status(400).send(`Webhook signature verification failed: ${err}`);
      return;
    }

    if (event.type !== 'payment_intent.succeeded') {
      res.status(200).send('ignored');
      return;
    }

    const pi = event.data.object as any;
    const servicioId = pi.metadata?.servicioId;
    const tecnicoUidFromMeta = pi.metadata?.tecnicoUid;
    const clienteUidFromMeta = pi.metadata?.clienteUid;
    const platformFeeCentavos = Number(pi.metadata?.platformCommissionCentavos || 0);
    if (!servicioId) {
      res.status(200).send('missing servicioId in metadata');
      return;
    }

    // Load service + técnico + cliente
    const serviceDoc = await db.collection('servicios').doc(servicioId).get();
    if (!serviceDoc.exists) {
      res.status(404).send('service not found');
      return;
    }
    const service = serviceDoc.data()!;
    const tecnicoUid = (service.tecnicoId as string) || tecnicoUidFromMeta;
    const clienteUid = (service.clienteId as string) || clienteUidFromMeta;

    const tecnicoDoc = await db.collection('users').doc(tecnicoUid).get();
    const tecnico = tecnicoDoc.data()!;
    const orgApiKey: string | undefined = tecnico?.facturapi?.organizationApiKey;

    // Amounts in MXN (Stripe returns centavos as integer amount).
    const totalMxn = (pi.amount as number) / 100;
    const platformFeeMxn = platformFeeCentavos / 100;
    const tecnicoNetMxn = totalMxn - platformFeeMxn;

    // Persist the transaction row regardless of CFDI outcome — earnings /
    // commissions views depend on this row existing. Keyed by PaymentIntent
    // id so the client's optimistic write and this webhook converge to a
    // single document (idempotent under Stripe's at-least-once delivery).
    await db.collection('transacciones').doc(pi.id).set({
      servicioId,
      clienteId: clienteUid,
      tecnicoId: tecnicoUid,
      montoTotal: totalMxn,
      comisionPlataforma: platformFeeMxn,
      montoTecnico: tecnicoNetMxn,
      stripePaymentIntentId: pi.id,
      estado: 'completado',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    // Advance the service to `pagado` so downstream flows (cron, admin view)
    // see it as completed and paid.
    await db.collection('servicios').doc(servicioId).update({
      estado: 'pagado',
      montoPagado: totalMxn,
      comisionPlataforma: platformFeeMxn,
      montoTecnico: tecnicoNetMxn,
      estadoPago: 'pagado',
      stripePaymentIntentId: pi.id,
      paidAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    if (!orgApiKey) {
      // Técnico can't emit CFDIs yet (grace period or missing CSD). We already
      // persisted the transaction so the money is tracked; flag for admin.
      await db.collection('admin_flags').add({
        type: 'cfdi_pending_technician_not_configured',
        servicioId,
        tecnicoUid,
        stripePaymentIntentId: pi.id,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      res.status(200).send('payment recorded; CFDI deferred (técnico sin FacturAPI)');
      return;
    }

    const fx = facturapiForOrg(orgApiKey);

    // Look up receptor (cliente) fiscal data. If the cliente hasn't filled
    // in a personal RFC on their profile, the CFDI is issued to "público en
    // general" per SAT conventions (RFC XAXX010101000, régimen 616, ZIP is
    // required — falls back to the emisor's ZIP if the cliente has none).
    const clienteDoc = await db.collection('users').doc(clienteUid).get();
    const cliente = clienteDoc.data() || {};
    const clienteHasRfc =
        typeof cliente.rfc === 'string' && cliente.rfc.length >= 12;
    const receptor = clienteHasRfc
      ? {
          legal_name: (cliente.razonSocial as string) ||
              `${cliente.nombre ?? ''} ${cliente.apellido ?? ''}`.trim(),
          tax_id: cliente.rfc as string,
          tax_system: (cliente.regimenFiscal as string) || '616',
          address: {
            zip: (cliente.codigoPostalFiscal as string) ||
                (tecnico.codigoPostalFiscal as string) ||
                '00000',
          },
        }
      : {
          legal_name: 'PUBLICO EN GENERAL',
          tax_id: 'XAXX010101000',
          tax_system: '616', // Sin obligaciones fiscales
          address: {
            zip: (tecnico.codigoPostalFiscal as string) || '00000',
          },
        };

    // Stamp CFDI técnico → cliente.
    // product_key 81111500 = "Instalación y mantenimiento de equipos y sistemas"
    // (SAT genérico para servicios técnicos; ajustar por categoría más adelante).
    const invoice = await fx.invoices.create({
      customer: receptor,
      items: [
        {
          quantity: 1,
          product: {
            description: service.titulo,
            product_key: '81111500',
            price: (service.costoFinal ?? service.estimacionCosto ?? 0),
          },
        },
      ],
      payment_form: '04', // tarjeta de crédito
      payment_method: 'PUE',
      use: clienteHasRfc ? 'G03' : 'S01', // G03 = gastos en general, S01 = sin efectos fiscales
    });

    // Reserve a Firestore doc id so both the XML and the PDF land at
    // predictable Storage paths.
    const facturaDocRef = db.collection('facturas').doc();
    const facturaId = facturaDocRef.id;

    // Download the stamped XML from FacturAPI, generate our branded PDF,
    // upload both to Cloud Storage. If anything in this pipeline fails we
    // still persist the invoice metadata (URLs null) so the payment isn't
    // stuck — an admin can regenerate artifacts later.
    let xmlUrl: string | null = null;
    let pdfUrl: string | null = null;

    try {
      const xmlBuf = await downloadAsBuffer(
        await fx.invoices.downloadXml(invoice.id),
      );
      xmlUrl = await uploadCfdiXml(facturaId, xmlBuf);

      // Extract sellos + cadena original from XML using simple regex — avoids
      // pulling in a full XML parser dependency for the ~4 fields we need.
      const xmlText = xmlBuf.toString('utf8');
      const selloEmisor = extractXmlAttr(xmlText, 'Sello') ?? '';
      const selloSat = extractXmlAttr(xmlText, 'SelloSAT') ?? '';
      const noCertSat = extractXmlAttr(xmlText, 'NoCertificadoSAT') ?? '';
      // Cadena original TFD is reconstructed from the TFD node.
      const cadenaOriginalTfd = buildCadenaOriginalTfd(xmlText);

      const pdfBuf = await renderBrandedCfdiPdf({
        folioFiscal: invoice.uuid,
        fechaTimbrado: extractXmlAttr(xmlText, 'FechaTimbrado') ??
            new Date().toISOString(),
        emisor: {
          rfc: (tecnico.rfc as string) ?? '',
          razonSocial: (tecnico.razonSocial as string) ??
              `${tecnico.nombre ?? ''} ${tecnico.apellido ?? ''}`.trim(),
          regimenFiscal: (tecnico.regimenFiscal as string) ?? '',
        },
        receptor: {
          rfc: receptor.tax_id,
          razonSocial: receptor.legal_name,
          usoCfdi: clienteHasRfc ? 'G03' : 'S01',
        },
        items: [
          {
            description: service.titulo,
            quantity: 1,
            unitPrice: (service.costoFinal ?? service.estimacionCosto ?? 0),
            subtotal: (service.costoFinal ?? service.estimacionCosto ?? 0),
          },
        ],
        subtotal: invoice.total / 1.16,
        iva: invoice.total - invoice.total / 1.16,
        total: invoice.total,
        selloEmisor,
        selloSat: selloSat + (noCertSat ? ` (Cert ${noCertSat})` : ''),
        cadenaOriginalTfd,
      });
      pdfUrl = await uploadCfdiPdf(facturaId, pdfBuf);
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error('CFDI artifact upload failed', err);
      await db.collection('admin_flags').add({
        type: 'cfdi_artifact_generation_failed',
        servicioId,
        facturapiInvoiceId: invoice.id,
        error: (err as Error).message,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      // fall through — save invoice metadata without URLs
    }

    await facturaDocRef.set({
      tipo: 'tecnico_cliente',
      tecnicoUid,
      clienteUid,
      servicioId,
      facturapiInvoiceId: invoice.id,
      folioFiscal: invoice.uuid,
      fechaTimbrado: admin.firestore.FieldValue.serverTimestamp(),
      subtotal: invoice.total / 1.16,
      iva: invoice.total - invoice.total / 1.16,
      total: invoice.total,
      xmlUrl,
      pdfUrl,
      estado: 'vigente',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Post system message in the service chat (uses the same 'sistema'
    // convention already wired in Flutter — see MessageModel.tipoSistema).
    await db
      .collection('servicios')
      .doc(servicioId)
      .collection('mensajes')
      .add({
        userId: 'system',
        nombreUsuario: 'ServiTec',
        mensaje: `CFDI emitido — folio ${invoice.uuid}`,
        tipo: 'sistema',
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        leido: false,
        metadata: {
          event: 'cfdi_emitted',
          facturaId: invoice.id,
          folioFiscal: invoice.uuid,
        },
      });

    res.status(200).send('ok');
  },
);

// XML helpers now live in ./lib/cfdi-xml — the monthly commission cron needs
// the same readers.
