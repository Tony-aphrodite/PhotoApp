/**
 * Monthly cron — issues one CFDI per técnico for the previous month's
 * accumulated 12% platform commission. Line items = one per completed service.
 *
 * Schedule: 05:00 on the 1st of every month (Mexico time).
 *
 * Flow per técnico:
 *   1. Query `servicios` where estado in [pagado] and tecnicoId == uid
 *      and paidAt in previous month, and there's no existing commission
 *      factura for that periodo already.
 *   2. Compute totals and build FacturAPI line items.
 *   3. Stamp CFDI ServiTec → técnico using the parent (ServiTec) FacturAPI org.
 *   4. Generate branded PDF, upload XML + PDF to Storage, insert `facturas` row.
 *
 * This runs under the ServiTec parent org (no per-técnico key needed).
 */

import { onSchedule } from 'firebase-functions/v2/scheduler';
import { db } from './lib/admin';
import { facturapiParent } from './lib/facturapi';
import { platformCommissionPct } from './lib/stripe';

export const monthlyCommissionCron = onSchedule(
  {
    schedule: '0 5 1 * *',
    timeZone: 'America/Mexico_City',
    region: 'us-central1',
    memory: '512MiB',
  },
  async () => {
    const now = new Date();
    const start = new Date(now.getFullYear(), now.getMonth() - 1, 1);
    const end = new Date(now.getFullYear(), now.getMonth(), 1);
    const periodo = `${start.getFullYear()}-${String(start.getMonth() + 1).padStart(2, '0')}`;

    // All técnicos with active FacturAPI orgs
    const tecnicos = await db
      .collection('users')
      .where('rol', '==', 'tecnico')
      .where('facturapi.status', '==', 'active')
      .get();

    const fxParent = facturapiParent();

    for (const tecDoc of tecnicos.docs) {
      const tecnicoUid = tecDoc.id;
      const tecnico = tecDoc.data();

      // Skip if already issued for this periodo
      const existing = await db
        .collection('facturas')
        .where('tipo', '==', 'servitec_comision')
        .where('tecnicoUid', '==', tecnicoUid)
        .where('periodo', '==', periodo)
        .limit(1)
        .get();
      if (!existing.empty) continue;

      // Load paid services in the period
      const services = await db
        .collection('servicios')
        .where('tecnicoId', '==', tecnicoUid)
        .where('estado', '==', 'pagado')
        .where('paidAt', '>=', start)
        .where('paidAt', '<', end)
        .get();

      if (services.empty) continue;

      let subtotal = 0;
      const items: any[] = [];
      services.docs.forEach((sDoc) => {
        const s = sDoc.data();
        const gross = (s.costoFinal ?? s.estimacionCosto ?? 0) as number;
        const commission = +(gross * (platformCommissionPct / 100)).toFixed(2);
        subtotal += commission;
        items.push({
          quantity: 1,
          product: {
            description: `Comisión ${platformCommissionPct}% — ${s.titulo} (${sDoc.id})`,
            product_key: '80141600', // clave SAT: servicios de intermediación
            price: commission / 1.16, // FacturAPI expects pre-tax unit price
          },
        });
      });

      // Stamp CFDI ServiTec → técnico
      // TODO(phase2): confirm the "receptor is a técnico" flow uses the same
      //    createInvoice endpoint under the ServiTec parent org.
      const invoice = await fxParent.invoices.create({
        customer: {
          legal_name: tecnico.razonSocial ?? `${tecnico.nombre} ${tecnico.apellido}`,
          tax_id: tecnico.rfc,
          tax_system: tecnico.regimenFiscal,
          address: { zip: tecnico.codigoPostalFiscal },
        },
        items,
        payment_form: '99', // por definir
        payment_method: 'PUE',
        use: 'G03',
      });

      await db.collection('facturas').add({
        tipo: 'servitec_comision',
        tecnicoUid,
        periodo,
        facturapiInvoiceId: invoice.id,
        folioFiscal: invoice.uuid,
        fechaTimbrado: new Date(),
        subtotal: +(subtotal / 1.16).toFixed(2),
        iva: +(subtotal - subtotal / 1.16).toFixed(2),
        total: +subtotal.toFixed(2),
        xmlUrl: null,
        pdfUrl: null,
        estado: 'vigente',
        createdAt: new Date(),
      });
    }
  },
);
