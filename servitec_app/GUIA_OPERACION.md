# Guía de Operación del Sistema — ServiTec
## Documentación Técnica del Flujo Completo

**Versión:** 1.0 | **Fecha:** Marzo 2026

---

## 1. Ciclo de Vida de un Servicio

Desde que un cliente crea una solicitud hasta que el técnico recibe su pago, el servicio pasa por los siguientes estados:

```
CLIENTE crea solicitud
         │
         ▼
    ┌─────────┐
    │ pendiente│  ← Estado inicial. Sin técnico asignado.
    └─────────┘
         │
    ┌────┴────────────────────────────────┐
    │ Asignación automática               │ Asignación manual (admin)
    │ (tipoAsignacion = "automatica")     │ (tipoAsignacion = "admin")
    └────┬────────────────────────────────┘
         │
         ▼
    ┌─────────┐
    │ asignado │  ← Técnico asignado. Notificación push enviada.
    └─────────┘
         │
         ▼
    ┌────────────┐
    │ en_progreso│  ← Técnico inició el trabajo.
    └────────────┘
         │
         ▼
    ┌───────────┐
    │ completado │  ← Trabajo terminado. Esperando pago.
    └───────────┘
         │
         ▼
    ┌──────────────┐
    │ pago_pendiente│  ← Cliente puede proceder al pago con Stripe.
    └──────────────┘
         │
         ▼
    ┌───────┐
    │ pagado │  ← Stripe confirma pago. Comisión calculada automáticamente.
    └───────┘
```

**Estados alternativos:**
- `cancelado`: El cliente o el admin canceló el servicio antes de completarse.

**Transiciones NO permitidas:**
- `pagado` → cualquier estado (estado final)
- `completado` → `pendiente` (no se puede regresar)
- `en_progreso` → `pendiente` (no se puede regresar)

---

## 2. Diagrama de Roles y Permisos

| Acción | Cliente | Técnico | Admin |
|--------|---------|---------|-------|
| Crear servicio | ✅ | ❌ | ✅ |
| Ver sus propios servicios | ✅ | ✅ | ✅ (todos) |
| Asignar técnico | ❌ | ❌ | ✅ |
| Cambiar estado a "en_progreso" | ❌ | ✅ (solo suyos) | ✅ |
| Cambiar estado a "completado" | ❌ | ✅ (solo suyos) | ✅ |
| Ver transacciones | Solo las suyas | Solo las suyas | ✅ (todas) |
| Crear/modificar transacciones | ❌ | ❌ | ❌ (solo Cloud Functions) |
| Modificar tarifas | ❌ | ❌ | ✅ |
| Ver/aprobar técnicos | ❌ | ❌ | ✅ |
| Escribir reseñas | ✅ (post-pago) | ❌ | ❌ |

---

## 3. Flujo de Pagos Detallado

```
1. Técnico marca servicio como "completado"
         │
2. Admin (o técnico) marca como "pago_pendiente"
         │
3. Cliente abre pantalla de pago en la app
         │
4. App llama Cloud Function `createPaymentIntent`
         │
5. Cloud Function verifica servicio y crea PaymentIntent en Stripe
         │
6. App recibe `clientSecret` y muestra formulario de tarjeta
         │
7. Cliente ingresa datos de tarjeta y confirma pago
         │
8. Stripe procesa el pago
         │
9. Stripe envía evento `payment_intent.succeeded` al webhook
         │
10. Cloud Function `handleStripeWebhook` procesa el evento:
     ├── Verifica idempotencia (¿ya fue procesado?)
     ├── Lee % comisión desde Firestore (configuracion/comisiones)
     ├── Calcula: comisión plataforma + fee Stripe + neto técnico
     ├── Escribe en `transacciones/{id}` (batch atómico)
     ├── Actualiza `servicios/{id}` → estado: "pagado"
     ├── Incrementa serviciosCompletados del técnico
     ├── Registra log en Cloud Logging (FINANCIAL_LOG)
     └── Envía notificaciones push a cliente y técnico

11. Cliente recibe: "Pago Confirmado ✅"
    Técnico recibe: "Pago Recibido - $XXX"
```

---

## 4. Asignación Automática vs Manual

### Asignación Automática
**Cuándo ocurre:** Cliente crea el servicio sin seleccionar técnico (`tipoAsignacion = "automatica"`).

**Algoritmo de scoring:**
```
Score = (calificacionPromedio × 8) + workloadBonus + (experiencia min 10)

Donde:
  workloadBonus = max(0, 30 - (serviciosActivos × 10))
  experiencia = min(10, serviciosCompletados)
```

**Requisitos para ser candidato:**
- `rol = "tecnico"`
- `disponible = true`
- `activo = true`
- `especialidades` contiene la categoría del servicio

**Si no hay técnicos disponibles:**
- El servicio queda como `pendiente`
- El admin recibe notificación push: "Asignación automática fallida"
- El admin debe asignar manualmente

### Asignación Manual (Admin)
El admin puede asignar cualquier técnico en cualquier momento desde el detalle del servicio. El técnico seleccionado recibe notificación push inmediatamente.

---

## 5. Monitoreo Diario Recomendado

### Qué revisar cada mañana (5-10 minutos):

1. **Servicios Pendientes** — ¿Hay servicios sin técnico de más de 2 horas?
   - Panel Admin → filtro "Pendientes"
   - Si hay, asignar manualmente

2. **Transacciones del día anterior** — ¿Se procesaron correctamente?
   - Dashboard Financiero → "Ayer" (usar filtro semanal)
   - Verificar que no haya transacciones en estado `error_calculo`

3. **Notificaciones push recibidas** — ¿Llegaron alertas de fallos?
   - Revisar el inbox de notificaciones del teléfono

### Qué revisar cada semana (15-20 minutos):

1. **KPIs financieros** — Dashboard → "Esta Semana"
2. **Técnicos con baja calificación** — Lista de técnicos, ordenar por rating
3. **Servicios cancelados** — Entender por qué se cancelaron (¿precio? ¿disponibilidad?)

---

## 6. Plan de Contingencia

### Si Stripe tiene problemas (stripe.com/status)

Los pagos no podrán procesarse. Los servicios quedarán en "pago_pendiente" hasta que Stripe se restaure. No se requiere acción manual — los webhooks se reintentan automáticamente por 72 horas.

**Comunicar a clientes:** "Hay un problema temporal con el procesador de pagos. Tu servicio está completo y podrás pagar en cuanto el sistema se restaure."

### Si Firebase tiene problemas (status.firebase.google.com)

La app no cargará datos. Los usuarios verán "cargando..." indefinidamente.

**Acción:** Esperar. Firebase tiene SLA de 99.95% de uptime. Los problemas generalmente se resuelven en menos de 1 hora.

### Si una Cloud Function falla

Los logs aparecen en Google Cloud Console → Cloud Logging.

**Para errores de comisión:** El `stripePaymentStatus` quedará en `succeeded` pero el cálculo no se hará. Contactar al desarrollador para ejecutar manualmente la recalculación.

### Si un técnico tiene un problema con un cliente

1. Abrir el chat del servicio desde el panel admin
2. Revisar el historial de mensajes
3. Si es una disputa de pago, ir a dashboard.stripe.com → Disputes

---

## 7. Estructura de Colecciones Firestore

```
📦 Firestore Database
│
├── users/{userId}
│   ├── email, nombre, apellido, telefono, rol
│   ├── activo, createdAt, ubicacionDefecto
│   ├── fotoPerfil, fcmToken
│   ├── [Técnicos] especialidades, calificacionPromedio, totalResenas
│   ├── [Técnicos] disponible, serviciosCompletados
│   └── [Técnicos] stripeConnectAccountId (para migración futura)
│
├── servicios/{servicioId}
│   ├── clienteId, clienteNombre, titulo, descripcion
│   ├── categoria, urgencia, estado, tipoAsignacion
│   ├── tecnicoId, tecnicoNombre (cuando asignado)
│   ├── ubicacion, fotos[], estimacion, montoPagado
│   ├── comisionPlataforma, montoTecnico, estadoPago
│   ├── createdAt, updatedAt, asignadoAt, completadoAt
│   └── stripePaymentIntentId, stripePaymentStatus
│       └── mensajes/ (subcolección)
│           └── {mensajeId}: userId, mensaje, timestamp, leido, tipo
│
├── transacciones/{transaccionId}
│   ├── servicioId, clienteId, tecnicoId
│   ├── montoTotal, comisionPlataforma, comisionStripe, montoTecnico
│   ├── porcentajeComision, estado, createdAt, completedAt
│   └── stripePaymentIntentId, stripeChargeId
│
├── configuracion/
│   ├── tarifas: { categoria: { tarifaBase, multiplicadorUrgente, recargoPorKm } }
│   └── comisiones: { porcentajePlataforma, porcentajeStripe }
│
└── resenas/{resenaId}
    ├── servicioId, clienteId, tecnicoId
    ├── calificacion (1-5), comentario
    └── createdAt
```

---

## 8. Cloud Functions Deployadas

| Función | Trigger | Propósito |
|---------|---------|-----------|
| `createPaymentIntent` | HTTPS POST | Crea PaymentIntent de Stripe |
| `handleStripeWebhook` | HTTPS POST (webhook) | Procesa eventos de Stripe |
| `onServiceCreated` | Firestore onCreate | Auto-asignación de técnico |
| `sendAdvancedNotification` | HTTPS Callable | [PLACEHOLDER] Notificaciones avanzadas |
| `generateMonthlyReport` | Scheduler (1° de cada mes) | [PLACEHOLDER] Reporte mensual |
| `cleanupExpiredServices` | Scheduler (diario 3AM) | [PLACEHOLDER] Limpieza de servicios |

---

## 9. Índices Compuestos de Firestore

Todos los índices están definidos en `firestore.indexes.json` y se despliegan con `firebase deploy --only firestore:indexes`.

Los índices clave para el rendimiento:
- `servicios`: estado + createdAt (Admin panel)
- `servicios`: tecnicoId + estado + createdAt (Técnico)
- `servicios`: clienteId + createdAt (Cliente)
- `transacciones`: tecnicoId + createdAt (Mis Ganancias)
- `transacciones`: estado + createdAt (Dashboard Financiero)
