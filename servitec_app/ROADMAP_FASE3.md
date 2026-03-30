# Roadmap Fase 3 — Funcionalidades Futuras
## ServiTec — Plan de Expansión Post-MVP

**Fecha de elaboración:** Marzo 2026
**Estado actual del proyecto:** Hitos 1-7 completados (MVP completo)

---

## Resumen de Hitos Disponibles

| Hito | Funcionalidad | Prioridad | Estimación | Dependencias |
|------|---------------|-----------|------------|--------------|
| **H8** | Diagnóstico y Cotización | Alta | $600-800 USD / 2 semanas | Ninguna |
| **H9** | Validación de Documentos | Alta | $400-500 USD / 1.5 semanas | Ninguna |
| **H10** | Sistema de Citas para Taller | Media | $500-700 USD / 2 semanas | H8 recomendado |
| **H11** | Categorización Avanzada | Baja | $300-400 USD / 1 semana | Ninguna |
| **H12** | Stripe Connect (pagos directos) | Media | $650-900 USD / 2 semanas | Ver STRIPE_CONNECT_MIGRATION.md |

---

## Hito 8 — Sistema de Diagnóstico y Cotización

### ¿Qué problema resuelve?

Actualmente, el técnico llega al domicilio, hace el diagnóstico, y el cliente paga el precio estimado. Si el trabajo real es más complejo, hay conflictos. Con el sistema de cotización, el técnico puede:
1. Ir al domicilio y diagnosticar
2. Crear una cotización detallada en la app
3. El cliente aprueba o rechaza ANTES de que el técnico comience
4. Solo si aprueba, se procede al trabajo

### Funcionalidades incluidas

**Para el técnico:**
- Pantalla "Crear Cotización" con:
  - Lista de materiales + costo individual
  - Horas estimadas de trabajo
  - Total automático
  - Fotos del problema (evidencia del diagnóstico)
  - Notas técnicas

**Para el cliente:**
- Notificación push: "Tu técnico envió una cotización"
- Pantalla "Ver Cotización" con desglose completo
- Botones: "Aprobar" / "Rechazar" / "Negociar" (abrir chat)
- Al aprobar: el servicio avanza a "en_progreso"
- Al rechazar: se cancela el servicio (con opción de cobro por diagnóstico)

**Firestore (ya existe en el esquema):**
- Colección `cotizaciones` con campos: items[], montoTotal, estado, fotos[]

**Estimación:** 2 semanas | $600-800 USD

---

## Hito 9 — Validación de Documentos de Técnicos

### ¿Qué problema resuelve?

Cualquier persona puede registrarse como técnico. Sin validación, podrían atender servicios personas sin las credenciales necesarias, lo que genera riesgo legal y de reputación para el negocio de Edgar.

### Funcionalidades incluidas

**Para el técnico:**
- Pantalla "Mis Documentos" donde puede subir:
  - INE (frente y reverso)
  - CURP
  - Certificados de especialidad (ej: licencia de electricista)
  - Comprobante de domicilio
- Estado de validación: pendiente / aprobado / rechazado

**Para el admin:**
- Pantalla "Validación de Documentos" con lista de técnicos pendientes
- Visualización de cada documento en pantalla completa
- Botones: "Aprobar" / "Rechazar con motivo"
- Técnico recibe notificación push del resultado

**Lógica adicional:**
- Solo técnicos con `estadoValidacion = "aprobado"` entran al algoritmo de asignación automática
- El algoritmo ya tiene preparado el filtro `where('estadoValidacion', '==', 'aprobado')`

**Estimación:** 1.5 semanas | $400-500 USD

---

## Hito 10 — Sistema de Citas para Taller

### ¿Qué problema resuelve?

Algunos servicios requieren que el cliente lleve el equipo al taller (reparaciones de electrodomésticos, dispositivos pequeños, etc.). El sistema actual solo soporta servicios a domicilio.

### Funcionalidades incluidas

**Para el cliente:**
- Al crear servicio, seleccionar "Servicio a domicilio" o "Llevar al taller"
- Si taller: seleccionar fecha y hora disponible (calendario)
- Confirmación con dirección del taller

**Para el técnico:**
- Vista de "Mi Agenda" con citas del día/semana
- Notificación 24h antes de cada cita
- Marcar cita como confirmada / no asistió / completada

**Para el admin:**
- Gestión de horarios disponibles del taller
- Vista de agenda consolidada de todos los técnicos

**Firestore (ya existe en el esquema):**
- Colección `citas` con campos: tecnicoId, clienteId, fechaHora, estado, servicioId

**Estimación:** 2 semanas | $500-700 USD

---

## Hito 11 — Categorización Avanzada de Servicios

### ¿Qué problema resuelve?

Actualmente, las categorías son genéricas (Plomería, Electricidad, etc.). En la práctica, dentro de "Plomería" hay subcategorías muy diferentes: reparación de fugas, instalación de tuberías, mantenimiento preventivo. Con subcategorías, el cliente puede describir mejor su problema y el técnico puede especializarse más.

### Funcionalidades incluidas

- Estructura de dos niveles: Categoría → Subcategoría
  - Plomería → Fugas, Instalaciones, Mantenimiento, Desazolve
  - Electricidad → Instalación, Reparación, Mantenimiento, Automatización
- Tags adicionales para descripción rápida
- Filtros de búsqueda mejorados en el panel admin
- Técnicos pueden especificar subcategorías en sus especialidades

**Estimación:** 1 semana | $300-400 USD

---

## Hito 12 — Stripe Connect (Pagos Directos a Técnicos)

Ver documento completo: [STRIPE_CONNECT_MIGRATION.md](STRIPE_CONNECT_MIGRATION.md)

**Resumen:** Automatizar las transferencias a técnicos. Actualmente Edgar transfiere manualmente. Con Stripe Connect, el dinero se divide automáticamente en el momento del pago.

**Estimación:** 2 semanas | $650-900 USD

---

## Orden de Prioridad Recomendado

```
Prioridad 1 (próximos 1-2 meses):
  → H9: Validación de documentos (protección legal + confianza del cliente)
  → H8: Diagnóstico y cotización (elimina conflictos de precio)

Prioridad 2 (próximos 3-4 meses):
  → H12: Stripe Connect (escalar sin transferencias manuales)
  → H10: Sistema de citas (ampliar modelo de negocio)

Prioridad 3 (6+ meses):
  → H11: Categorización avanzada (optimización del matching)
```

---

## Dependencias entre Hitos

```
H8 (Cotización) ────────────────────────────────────────────────────────────────────► Independiente
H9 (Documentos) ────────────────────────────────────────────────────────────────────► Independiente
H10 (Citas) ────── Recomendado tener H8 primero (flujo más completo) ────────────────► H8 opcional
H11 (Categorías) ─────────────────────────────────────────────────────────────────► Independiente
H12 (Stripe Connect) ─────────────────────────────────────────────────────────────► Independiente
```

---

## Presupuesto Total Estimado Fase 3

| Hito | Mínimo | Máximo |
|------|--------|--------|
| H8 Diagnóstico y Cotización | $600 | $800 |
| H9 Validación Documentos | $400 | $500 |
| H10 Citas para Taller | $500 | $700 |
| H11 Categorización Avanzada | $300 | $400 |
| H12 Stripe Connect | $650 | $900 |
| **TOTAL FASE 3** | **$2,450** | **$3,300** |

*Precios estimados en USD. Sujetos a ajuste según requerimientos específicos.*

---

## Notas Adicionales

- Todos los hitos de Fase 3 son **incrementales** — la app sigue funcionando durante el desarrollo
- Cada hito se entrega con testing completo antes de deploy a producción
- El esquema de Firestore ya tiene las colecciones `cotizaciones` y `citas` preparadas
- Los índices para estas colecciones ya están en `firestore.indexes.json`
