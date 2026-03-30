# Guía de Migración a Stripe Connect
## ServiTec — Pagos Directos a Técnicos

**Versión:** 1.0
**Fecha:** Marzo 2026
**Estado:** Preparado — Pendiente de implementación

---

## ¿Qué es Stripe Connect?

Actualmente, el flujo de pagos funciona así:
```
Cliente paga $400 → Cuenta Stripe de Edgar (plataforma)
→ Edgar transfiere manualmente al técnico
```

Con **Stripe Connect**, el dinero se divide automáticamente:
```
Cliente paga $400 → Stripe divide automáticamente:
  → 15% ($60) a cuenta de Edgar (plataforma)
  → 85% ($340) directo a cuenta bancaria del técnico
```

Esto elimina la necesidad de transferencias manuales y reduce el riesgo operativo.

---

## Infraestructura Ya Preparada

El campo `stripeConnectAccountId` ya existe en el modelo `UserModel` y en Firestore (`users/{userId}.stripeConnectAccountId`). Cuando un técnico conecte su cuenta bancaria, este campo se llenará con su Stripe Account ID (formato: `acct_XXXXXXXXXXXXXXXX`).

---

## Pasos de Implementación

### Paso 1 — Activar Stripe Connect en la cuenta principal

1. Ingresar al **Dashboard de Stripe** → `Connect` → `Get started`
2. Seleccionar tipo de cuenta: **Standard** (recomendado para México)
3. Completar el formulario de activación (requiere documentos de la empresa)
4. Stripe revisará y aprobará la solicitud (1-3 días hábiles)

### Paso 2 — Onboarding de técnicos (flujo KYC)

Cada técnico debe conectar su cuenta bancaria. El flujo es:

```
Técnico abre app → "Conectar cuenta bancaria" → Redirect a Stripe Onboarding
→ Técnico ingresa datos bancarios (CLABE interbancaria)
→ Stripe verifica identidad (INE, CURP)
→ stripeConnectAccountId guardado en Firestore
→ Técnico puede recibir pagos directos
```

**Cloud Function necesaria:**
```typescript
export const createStripeConnectLink = functions.https.onCall(async (data, context) => {
  const accountLink = await stripe.accountLinks.create({
    account: data.stripeAccountId, // crear si no existe
    refresh_url: 'https://servi-tec.app/stripe/refresh',
    return_url: 'https://servi-tec.app/stripe/return',
    type: 'account_onboarding',
  });
  return { url: accountLink.url };
});
```

### Paso 3 — Modificar el PaymentIntent (split payment)

**Cambio en Cloud Function `createPaymentIntent`:**

```typescript
// ACTUAL (todo va a la plataforma):
const paymentIntent = await stripe.paymentIntents.create({
  amount: Math.round(amount),
  currency: 'usd',
  metadata: { servicioId, clienteId, tecnicoId },
});

// CON STRIPE CONNECT (split automático):
const techDoc = await db.collection('users').doc(tecnicoId).get();
const stripeConnectAccountId = techDoc.data()?.stripeConnectAccountId;

const paymentIntent = await stripe.paymentIntents.create({
  amount: Math.round(amount),
  currency: 'usd',
  application_fee_amount: Math.round(amount * 0.15), // 15% comisión
  transfer_data: {
    destination: stripeConnectAccountId, // directo al técnico
  },
  metadata: { servicioId, clienteId, tecnicoId },
});
```

### Paso 4 — Actualizar el webhook handler

El `handlePaymentSuccess` no necesita cambios mayores, ya que Stripe registra el split automáticamente. Solo asegurarse de guardar el `stripeConnectAccountId` usado en la transacción.

---

## Consideraciones Legales (México)

| Aspecto | Detalle |
|---------|---------|
| SAT / Facturación | Cada técnico debe ser persona física con actividad empresarial o moral |
| Retención de ISR | Stripe Connect permite configurar retenciones automáticas |
| CLABE interbancaria | Requerida para transferencias en MXN |
| Límite SPEI | Máximo $999,999 MXN por transferencia |
| Comisión Stripe | 2.9% + $0.30 USD + 0.5% adicional por pagos internacionales |

---

## Estimación de Tiempo y Costo

| Fase | Tiempo Estimado | Costo Desarrollo |
|------|----------------|-----------------|
| Activación Stripe Connect | 1-3 días (aprobación Stripe) | Incluido |
| Cloud Functions (split payment) | 2 días | $200-300 USD |
| UI onboarding técnicos | 3 días | $300-400 USD |
| Testing y QA | 2 días | $150-200 USD |
| **Total** | **~2 semanas** | **$650-900 USD** |

---

## Campos Firestore Ya Preparados

```
users/{userId}:
  stripeConnectAccountId: string | null  ← ya existe

transacciones/{txId}:
  stripePaymentIntentId: string           ← ya existe
  stripeChargeId: string | null          ← ya existe
```

**No se requieren cambios de esquema** — todo está preparado.

---

## Próximos Pasos Recomendados

1. **Inmediato:** Crear cuenta Stripe Connect Standard para la plataforma
2. **Semana 1:** Implementar flujo de onboarding para técnicos en la app
3. **Semana 2:** Modificar Cloud Functions para split payment automático
4. **Semana 3:** Testing con tarjetas de prueba de Stripe
5. **Semana 4:** Lanzamiento gradual (primero con 2-3 técnicos piloto)
