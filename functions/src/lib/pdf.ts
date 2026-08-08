/**
 * ServiTec-branded CFDI 4.0 "representación impresa".
 *
 * FacturAPI can hand back its own PDF, but it carries FacturAPI's default
 * template. This renders our layout instead, from the data already extracted
 * from the stamped XML, so técnicos hand clients a ServiTec-branded invoice.
 *
 * Content follows the SAT requirements for a printed representation:
 * folio fiscal (UUID), fecha de timbrado, emisor RFC + régimen, receptor RFC +
 * uso, concept lines, subtotal / IVA / total, sello del emisor, sello del SAT,
 * cadena original del complemento de certificación, and the verification QR.
 *
 * Uses PDFKit's built-in Helvetica/Courier so no font files ship with the
 * function bundle.
 */

import PDFDocument from 'pdfkit';
import * as QRCode from 'qrcode';

// Brand palette — mirrors AppTheme in servitec_app/lib/core/theme/app_theme.dart
const BRAND_PRIMARY = '#0A6B6E';
const BRAND_ACCENT = '#14BDAC';
const INK = '#0F1419';
const INK_SOFT = '#536471';
const RULE = '#D9E1E4';

const PAGE_MARGIN = 42;

export interface CfdiParty {
  rfc: string;
  razonSocial: string;
}

export interface CfdiEmisor extends CfdiParty {
  regimenFiscal: string;
}

export interface CfdiReceptor extends CfdiParty {
  usoCfdi: string;
}

export interface CfdiItem {
  description: string;
  quantity: number;
  unitPrice: number;
  subtotal: number;
}

export interface BrandedCfdiInput {
  folioFiscal: string;
  fechaTimbrado: string;
  emisor: CfdiEmisor;
  receptor: CfdiReceptor;
  items: CfdiItem[];
  subtotal: number;
  iva: number;
  total: number;
  selloEmisor: string;
  selloSat: string;
  cadenaOriginalTfd: string;
}

const mxn = new Intl.NumberFormat('es-MX', {
  style: 'currency',
  currency: 'MXN',
  minimumFractionDigits: 2,
});

/** SAT's public CFDI verification endpoint, encoded into the QR. */
function satVerificationUrl(input: BrandedCfdiInput): string {
  // `fe` is the last 8 characters of the emisor's seal.
  const fe = (input.selloEmisor || '').slice(-8);
  const tt = Number.isFinite(input.total) ? input.total.toFixed(6) : '0.000000';
  const params =
    `id=${encodeURIComponent(input.folioFiscal)}` +
    `&re=${encodeURIComponent(input.emisor.rfc)}` +
    `&rr=${encodeURIComponent(input.receptor.rfc)}` +
    `&tt=${tt}` +
    `&fe=${encodeURIComponent(fe)}`;
  return `https://verificacfdi.facturaelectronica.sat.gob.mx/default.aspx?${params}`;
}

/** "2026-08-08T14:05:11" → "08/08/2026 14:05:11". Falls back to the raw
 * string when the stamp isn't parseable. */
function formatStamp(iso: string): string {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return iso || '—';
  const pad = (n: number) => String(n).padStart(2, '0');
  return (
    `${pad(d.getDate())}/${pad(d.getMonth() + 1)}/${d.getFullYear()} ` +
    `${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`
  );
}

export async function renderBrandedCfdiPdf(
  input: BrandedCfdiInput,
): Promise<Buffer> {
  // Generate the QR before opening the document — PDFKit's draw calls are
  // synchronous and we don't want to await mid-render.
  let qrPng: Buffer | null = null;
  try {
    qrPng = await QRCode.toBuffer(satVerificationUrl(input), {
      errorCorrectionLevel: 'M',
      margin: 1,
      width: 260,
    });
  } catch (err) {
    // A missing QR must not cost us the whole invoice.
    // eslint-disable-next-line no-console
    console.error('CFDI QR generation failed', err);
  }

  const doc = new PDFDocument({
    size: 'LETTER',
    margin: PAGE_MARGIN,
    info: {
      Title: `CFDI ${input.folioFiscal}`,
      Author: 'ServiTec',
      Subject: 'Comprobante Fiscal Digital por Internet (CFDI 4.0)',
    },
  });

  const chunks: Buffer[] = [];
  const done = new Promise<Buffer>((resolve, reject) => {
    doc.on('data', (chunk: Buffer) => chunks.push(chunk));
    doc.on('end', () => resolve(Buffer.concat(chunks)));
    doc.on('error', reject);
  });

  const pageWidth = doc.page.width;
  const contentWidth = pageWidth - PAGE_MARGIN * 2;
  const right = PAGE_MARGIN + contentWidth;

  // ---- Header band ----
  doc.rect(0, 0, pageWidth, 92).fill(BRAND_PRIMARY);
  doc.rect(0, 92, pageWidth, 4).fill(BRAND_ACCENT);

  doc
    .fillColor('#FFFFFF')
    .font('Helvetica-Bold')
    .fontSize(24)
    .text('ServiTec', PAGE_MARGIN, 28);
  doc
    .font('Helvetica')
    .fontSize(9)
    .fillColor('#CFE9E7')
    .text('Servicios técnicos a domicilio', PAGE_MARGIN, 58);

  doc
    .font('Helvetica-Bold')
    .fontSize(11)
    .fillColor('#FFFFFF')
    .text('CFDI 4.0', PAGE_MARGIN, 26, { width: contentWidth, align: 'right' });
  doc
    .font('Helvetica')
    .fontSize(8)
    .fillColor('#CFE9E7')
    .text('Comprobante Fiscal Digital por Internet', PAGE_MARGIN, 42, {
      width: contentWidth,
      align: 'right',
    })
    .text(`Timbrado: ${formatStamp(input.fechaTimbrado)}`, PAGE_MARGIN, 56, {
      width: contentWidth,
      align: 'right',
    })
    .text(`Folio fiscal: ${input.folioFiscal}`, PAGE_MARGIN, 70, {
      width: contentWidth,
      align: 'right',
    });

  // ---- Emisor / Receptor ----
  let y = 124;
  const colGap = 18;
  const colWidth = (contentWidth - colGap) / 2;

  const party = (
    x: number,
    heading: string,
    name: string,
    rfc: string,
    extraLabel: string,
    extraValue: string,
  ) => {
    doc
      .font('Helvetica-Bold')
      .fontSize(8)
      .fillColor(BRAND_PRIMARY)
      .text(heading.toUpperCase(), x, y);
    doc
      .font('Helvetica-Bold')
      .fontSize(11)
      .fillColor(INK)
      .text(name || '—', x, y + 14, { width: colWidth });
    const afterName = doc.y + 2;
    doc
      .font('Helvetica')
      .fontSize(9)
      .fillColor(INK_SOFT)
      .text(`RFC: ${rfc || '—'}`, x, afterName, { width: colWidth })
      .text(`${extraLabel}: ${extraValue || '—'}`, x, doc.y, {
        width: colWidth,
      });
  };

  party(
    PAGE_MARGIN,
    'Emisor',
    input.emisor.razonSocial,
    input.emisor.rfc,
    'Régimen fiscal',
    input.emisor.regimenFiscal,
  );
  const emisorBottom = doc.y;

  party(
    PAGE_MARGIN + colWidth + colGap,
    'Receptor',
    input.receptor.razonSocial,
    input.receptor.rfc,
    'Uso CFDI',
    input.receptor.usoCfdi,
  );

  y = Math.max(emisorBottom, doc.y) + 18;

  // ---- Concepts table ----
  const colQtyX = PAGE_MARGIN;
  const colDescX = PAGE_MARGIN + 44;
  const colUnitX = right - 200;
  const colAmountX = right - 96;

  doc.rect(PAGE_MARGIN, y, contentWidth, 22).fill('#F1F5F6');
  doc
    .font('Helvetica-Bold')
    .fontSize(8)
    .fillColor(INK_SOFT)
    .text('CANT.', colQtyX + 6, y + 7)
    .text('CONCEPTO', colDescX, y + 7)
    .text('P. UNITARIO', colUnitX, y + 7, { width: 96, align: 'right' })
    .text('IMPORTE', colAmountX, y + 7, { width: 96, align: 'right' });

  y += 26;

  const items = input.items?.length ? input.items : [];
  if (items.length === 0) {
    doc
      .font('Helvetica-Oblique')
      .fontSize(9)
      .fillColor(INK_SOFT)
      .text('Sin conceptos registrados.', colDescX, y);
    y = doc.y + 8;
  }

  for (const item of items) {
    doc.font('Helvetica').fontSize(9).fillColor(INK);
    const descHeight = doc.heightOfString(item.description || '—', {
      width: colUnitX - colDescX - 10,
    });
    doc.text(String(item.quantity ?? 1), colQtyX + 6, y);
    doc.text(item.description || '—', colDescX, y, {
      width: colUnitX - colDescX - 10,
    });
    doc.text(mxn.format(item.unitPrice ?? 0), colUnitX, y, {
      width: 96,
      align: 'right',
    });
    doc.text(mxn.format(item.subtotal ?? 0), colAmountX, y, {
      width: 96,
      align: 'right',
    });

    y += Math.max(descHeight, 12) + 8;
    doc
      .moveTo(PAGE_MARGIN, y - 4)
      .lineTo(right, y - 4)
      .lineWidth(0.5)
      .strokeColor(RULE)
      .stroke();
  }

  // ---- Totals ----
  y += 6;
  const totalsLabelX = right - 240;
  const totalRow = (label: string, value: number, bold = false) => {
    doc
      .font(bold ? 'Helvetica-Bold' : 'Helvetica')
      .fontSize(bold ? 12 : 9)
      .fillColor(bold ? INK : INK_SOFT)
      .text(label, totalsLabelX, y, { width: 140, align: 'right' })
      .text(mxn.format(value ?? 0), right - 96, y, {
        width: 96,
        align: 'right',
      });
    y += bold ? 22 : 15;
  };

  totalRow('Subtotal', input.subtotal);
  totalRow('IVA (16%)', input.iva);
  doc
    .moveTo(totalsLabelX, y)
    .lineTo(right, y)
    .lineWidth(1)
    .strokeColor(BRAND_ACCENT)
    .stroke();
  y += 8;
  totalRow('Total', input.total, true);

  // ---- Seals + QR ----
  y += 10;
  doc
    .moveTo(PAGE_MARGIN, y)
    .lineTo(right, y)
    .lineWidth(0.5)
    .strokeColor(RULE)
    .stroke();
  y += 12;

  const qrSize = 118;
  if (qrPng) {
    doc.image(qrPng, PAGE_MARGIN, y, { width: qrSize, height: qrSize });
  }

  const sealX = PAGE_MARGIN + qrSize + 16;
  const sealWidth = right - sealX;

  const sealBlock = (label: string, value: string) => {
    doc
      .font('Helvetica-Bold')
      .fontSize(7)
      .fillColor(BRAND_PRIMARY)
      .text(label.toUpperCase(), sealX, doc.y === 0 ? y : doc.y, {
        width: sealWidth,
      });
    doc
      .font('Courier')
      .fontSize(5.5)
      .fillColor(INK_SOFT)
      .text(value || '—', sealX, doc.y + 1, { width: sealWidth, lineGap: 0.5 });
    doc.moveDown(0.4);
  };

  doc.y = y;
  sealBlock('Sello digital del emisor', input.selloEmisor);
  sealBlock('Sello digital del SAT', input.selloSat);
  sealBlock(
    'Cadena original del complemento de certificación digital del SAT',
    input.cadenaOriginalTfd,
  );

  // ---- Footer ----
  const footerY = Math.max(doc.y + 14, y + qrSize + 12);
  doc
    .moveTo(PAGE_MARGIN, footerY)
    .lineTo(right, footerY)
    .lineWidth(0.5)
    .strokeColor(RULE)
    .stroke();
  doc
    .font('Helvetica')
    .fontSize(7)
    .fillColor(INK_SOFT)
    .text(
      'Este documento es una representación impresa de un CFDI. ' +
        'Verifique su autenticidad escaneando el código QR o en ' +
        'verificacfdi.facturaelectronica.sat.gob.mx',
      PAGE_MARGIN,
      footerY + 8,
      { width: contentWidth, align: 'center' },
    );

  doc.end();
  return done;
}
