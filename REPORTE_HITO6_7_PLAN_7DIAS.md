# REPORTE DE IMPLEMENTACIÓN: HITO 6 + HITO 7
## Plan de Ejecución — 7 Días

**Proyecto:** Servicios Domicilio MVP
**Desarrollador:** JunJun Mabod
**Cliente:** Edgar Daniel Godoy Montalvo
**Período:** 7 días calendario
**Presupuesto:** $700 (Hito 6: $500 + Hito 7: $200)
**Fecha de inicio estimada:** 19 de marzo de 2026
**Fecha de entrega estimada:** 25 de marzo de 2026

---

## 📋 RESUMEN EJECUTIVO

Este reporte detalla el plan de implementación para los Hitos 6 y 7 del proyecto Servicios Domicilio MVP. Estos dos hitos representan la fase final del contrato original y son críticos porque transforman la aplicación de un prototipo funcional a un **sistema de negocio real con flujo de dinero, transparencia financiera y estabilidad en producción**.

El Hito 6 se centra en construir la **capa financiera** del sistema: cada vez que un cliente paga por un servicio, el sistema debe calcular automáticamente cuánto gana la plataforma (comisión), cuánto cobra Stripe (procesamiento), y cuánto recibe el técnico. Tanto el técnico como el administrador necesitan pantallas dedicadas para visualizar esta información financiera en tiempo real.

El Hito 7 se enfoca en **preparar el sistema para el mundo real**: asignación automática de técnicos, optimización de velocidad de carga, pruebas de seguridad exhaustivas, y la entrega formal del proyecto con toda la documentación necesaria para que Edgar pueda operar el negocio de forma independiente.

**Prerrequisito crítico:** El Hito 5 (integración de pagos con Stripe) debe estar completamente funcional antes de iniciar este plan, ya que el sistema de comisiones depende directamente del flujo de pagos.

---

## 📅 CRONOGRAMA DÍA POR DÍA

---

### DÍA 1 — Sistema de Cálculo Automático de Comisiones
**Enfoque:** Construir la lógica central de negocio que determina la distribución del dinero

#### ¿Por qué es importante?

Este es el corazón financiero del negocio de Edgar. Cada vez que un cliente paga un servicio a través de Stripe, el sistema debe responder automáticamente a tres preguntas fundamentales:

1. **¿Cuánto gana la plataforma?** — La comisión de Edgar (15% configurable)
2. **¿Cuánto cobra Stripe?** — El costo del procesamiento de pagos (2.9% + $0.30 por transacción)
3. **¿Cuánto recibe el técnico?** — Lo que queda después de ambas deducciones

Sin este cálculo automático, Edgar tendría que hacer estos cálculos manualmente para cada servicio, lo cual es inviable a medida que el negocio escala.

#### ¿Cómo funciona técnicamente?

Se creará una **Cloud Function** en Firebase que se activa automáticamente cada vez que una transacción cambia su estado a "completado" (es decir, cuando Stripe confirma que el pago fue exitoso). Esta función:

1. **Escucha** el evento de pago exitoso a través del webhook de Stripe
2. **Lee** el monto total del servicio desde la colección `transacciones`
3. **Calcula** el desglose financiero aplicando la fórmula:

```
Ejemplo con un servicio de Plomería de $400:

Monto Total del Servicio:                    $400.00
─────────────────────────────────────────────────────
Comisión de la Plataforma (15%):            - $60.00
Comisión de Stripe (2.9% + $0.30):          - $11.90
─────────────────────────────────────────────────────
Monto Neto para el Técnico:                  $328.10
```

4. **Guarda** el desglose en dos lugares simultáneamente:
   - En el documento de `transacciones/{id}`: campos `comisionPlataforma`, `comisionStripe`, `montoTecnico`
   - En el documento de `servicios/{id}`: campos `comisionPlataforma`, `montoTecnico`, `estadoPago = "pagado"`

5. **Registra** un log estructurado en Cloud Logging de Google Cloud Platform para auditoría y trazabilidad financiera

#### ¿Qué pasa si algo falla?

La Cloud Function incluirá manejo de errores robusto:
- Si el cálculo falla, la transacción se marca como `error_calculo` y se genera una alerta
- Si Firestore no responde, la función reintenta automáticamente (hasta 3 veces, comportamiento nativo de Cloud Functions)
- Todos los errores se registran en Cloud Logging para revisión posterior
- El porcentaje de comisión se lee desde la colección `configuracion/comisiones`, permitiendo a Edgar ajustarlo sin necesidad de modificar código

#### Validaciones implementadas:
- Verificar que el monto no sea negativo o cero antes de calcular
- Verificar que la transacción no haya sido procesada previamente (evitar doble cobro)
- Verificar que el servicioId referenciado existe en Firestore
- Registrar timestamp exacto del cálculo para auditoría

#### Entregables del Día 1:
- Cloud Function `calculateCommission` deployada en Firebase
- Integración completa con webhook de Stripe
- Desglose financiero guardado automáticamente en `transacciones` y `servicios`
- Manejo de errores y reintentos configurado
- Porcentaje de comisión configurable desde Firestore
- Tests con datos de prueba validando cálculos correctos

---

### DÍA 2 — Pantalla "Mis Ganancias" para Técnicos
**Enfoque:** Darle al técnico visibilidad completa sobre sus ingresos y deducciones

#### ¿Por qué es importante?

Los técnicos son el motor del negocio. Si un técnico no puede ver claramente cuánto ha ganado, cuánto le han descontado, y por qué conceptos, pierde confianza en la plataforma. La transparencia financiera es clave para retener a los mejores técnicos.

Esta pantalla le permite al técnico responder preguntas como:
- "¿Cuánto he ganado esta semana?"
- "¿Cuánto me descontaron de comisión en total?"
- "¿Cuántos servicios pagados llevo este mes?"
- "¿Cuál fue el desglose de mi último servicio?"

#### Diseño detallado de la pantalla:

```
┌──────────────────────────────────────────┐
│  ← Mis Ganancias                         │
├──────────────────────────────────────────┤
│                                          │
│  ┌─────────────┐  ┌─────────────┐       │
│  │  💰 Total   │  │  ✅ Neto    │       │
│  │  Facturado  │  │  Recibido   │       │
│  │  $5,200.00  │  │  $4,160.00  │       │
│  │  12 servicios│  │  después de │       │
│  │             │  │  comisiones  │       │
│  └─────────────┘  └─────────────┘       │
│                                          │
│  ┌─────────────┐  ┌─────────────┐       │
│  │  📊 Comisión│  │  📋 Servicios│      │
│  │  Descontada │  │  Pagados    │       │
│  │  -$780.00   │  │     12      │       │
│  │  15% promedio│  │  este período│      │
│  └─────────────┘  └─────────────┘       │
│                                          │
│  Período: [Esta Semana ▼]               │
│           [Este Mes] [Este Año] [Todo]  │
│                                          │
│  ─── Historial de Pagos ───────────     │
│                                          │
│  ┌──────────────────────────────────┐   │
│  │  🔧 Plomería — Fuga de agua     │   │
│  │  Cliente: Carlos Mendoza        │   │
│  │  Fecha: 18 de marzo, 2026       │   │
│  │  ─────────────────────────────   │   │
│  │  Monto Total:         $400.00   │   │
│  │  Comisión Plataforma: -$60.00   │   │
│  │  Comisión Stripe:     -$11.90   │   │
│  │  ─────────────────────────────   │   │
│  │  Tu Ganancia Neta:    $328.10   │   │
│  │                      ✅ Pagado  │   │
│  └──────────────────────────────────┘   │
│                                          │
│  ┌──────────────────────────────────┐   │
│  │  ⚡ Electricidad — Cortocircuito │   │
│  │  Cliente: María López           │   │
│  │  Fecha: 15 de marzo, 2026       │   │
│  │  ─────────────────────────────   │   │
│  │  Monto Total:         $350.00   │   │
│  │  Comisión Plataforma: -$52.50   │   │
│  │  Comisión Stripe:     -$10.45   │   │
│  │  ─────────────────────────────   │   │
│  │  Tu Ganancia Neta:    $287.05   │   │
│  │                      ✅ Pagado  │   │
│  └──────────────────────────────────┘   │
│                                          │
└──────────────────────────────────────────┘
```

#### Implementación técnica en FlutterFlow:

**Consulta de datos (Backend Query):**
- Colección: `transacciones`
- Filtros: `tecnicoId == Authenticated User ID` AND `estado == "completado"`
- Orden: `createdAt` Descendente
- Para filtro por período: agregar filtro adicional de `createdAt >= fechaInicio`

**Tarjetas de resumen (cálculos agregados):**
- Total Facturado: suma de todos los `montoTotal` del período
- Neto Recibido: suma de todos los `montoTecnico` del período
- Comisión Descontada: suma de todos los `comisionPlataforma` del período
- Servicios Pagados: conteo de documentos en el período

**Filtro por período:**
- DropDown con opciones: Esta Semana, Este Mes, Este Año, Todo
- Al cambiar selección, la query se actualiza dinámicamente recalculando las fechas de inicio/fin
- "Esta Semana" = desde el lunes de la semana actual
- "Este Mes" = desde el día 1 del mes actual
- "Este Año" = desde el 1 de enero del año actual

**Navegación:**
- Acceso desde HomeTecnicoPage → nuevo botón "💰 Mis Ganancias"
- AppBar con botón de retroceso para volver

#### Entregables del Día 2:
- Página MisGananciasPage completa y funcional
- 4 tarjetas de resumen financiero con datos en tiempo real
- Lista detallada de cada transacción con desglose completo
- Filtro dinámico por período (semana/mes/año/todo)
- Navegación integrada desde HomeTecnicoPage
- Diseño limpio y profesional con colores indicativos (verde para ganancias, rojo para deducciones)

---

### DÍA 3 — Dashboard Financiero para el Administrador
**Enfoque:** Darle a Edgar una vista ejecutiva completa del flujo de dinero en su plataforma

#### ¿Por qué es importante?

Edgar, como dueño del negocio, necesita poder responder en cualquier momento:
- "¿Cuánto dinero ha movido mi plataforma en total?"
- "¿Cuánto he ganado en comisiones esta semana?"
- "¿Cuánto he pagado a los técnicos?"
- "¿Cuántas transacciones se han completado?"
- "¿Cuál técnico genera más ingresos?"
- "¿Hay alguna transacción con problemas?"

Este dashboard es la herramienta de gestión financiera central que Edgar usará diariamente para tomar decisiones de negocio.

#### Diseño detallado de la pantalla:

```
┌──────────────────────────────────────────┐
│  📊 Dashboard Financiero                 │
├──────────────────────────────────────────┤
│                                          │
│  ┌─────────────┐  ┌─────────────┐       │
│  │  💵 Ingresos│  │  🏦 Comisión│       │
│  │  Totales    │  │  Ganada     │       │
│  │  $12,500.00 │  │  $1,875.00  │       │
│  │  35 servicios│  │  15% prom.  │       │
│  └─────────────┘  └─────────────┘       │
│                                          │
│  ┌─────────────┐  ┌─────────────┐       │
│  │  👷 Pagado a│  │  📈 Trans-  │       │
│  │  Técnicos   │  │  acciones   │       │
│  │  $10,250.00 │  │     35      │       │
│  │  neto de com.│  │  completadas│       │
│  └─────────────┘  └─────────────┘       │
│                                          │
│  Período: [Esta Semana ▼]               │
│                                          │
│  ─── Transacciones Recientes ─────────  │
│                                          │
│  ┌──────────────────────────────────┐   │
│  │  #SRV-2024031801                 │   │
│  │  🔧 Plomería — Fuga de agua     │   │
│  │  ─────────────────────────────   │   │
│  │  Cliente:  Carlos Mendoza        │   │
│  │  Técnico:  Juan Pérez            │   │
│  │  ─────────────────────────────   │   │
│  │  Total Cobrado:       $400.00    │   │
│  │  Tu Comisión (15%):   +$60.00    │   │
│  │  Stripe (2.9%+$0.30): -$11.90   │   │
│  │  Pagado al Técnico:   $328.10    │   │
│  │  ─────────────────────────────   │   │
│  │  18/Mar/2026 14:32  ✅ Completada│   │
│  └──────────────────────────────────┘   │
│                                          │
│  ┌──────────────────────────────────┐   │
│  │  #SRV-2024031502                 │   │
│  │  ⚡ Electricidad — Instalación   │   │
│  │  ─────────────────────────────   │   │
│  │  Cliente:  María López           │   │
│  │  Técnico:  Pedro Ramírez         │   │
│  │  ─────────────────────────────   │   │
│  │  Total Cobrado:       $350.00    │   │
│  │  Tu Comisión (15%):   +$52.50    │   │
│  │  Stripe (2.9%+$0.30): -$10.45   │   │
│  │  Pagado al Técnico:   $287.05    │   │
│  │  ─────────────────────────────   │   │
│  │  15/Mar/2026 10:15  ✅ Completada│   │
│  └──────────────────────────────────┘   │
│                                          │
└──────────────────────────────────────────┘
```

#### Sistema de Logs Financieros:

Además del dashboard visual, se implementará una Cloud Function dedicada exclusivamente al registro de logs financieros. Cada transacción generará un registro estructurado en Cloud Logging de Google Cloud Platform con el siguiente formato:

```json
{
  "type": "TRANSACTION_COMPLETED",
  "transaccionId": "txn_abc123",
  "servicioId": "srv_xyz789",
  "clienteId": "usr_client01",
  "tecnicoId": "usr_tech01",
  "montoTotal": 400.00,
  "comisionPlataforma": 60.00,
  "comisionStripe": 11.90,
  "montoTecnico": 328.10,
  "porcentajeComision": 15,
  "estado": "completado",
  "metodoPago": "card",
  "timestamp": "2026-03-18T14:32:00Z"
}
```

Estos logs permiten:
- Auditoría completa de cada transacción
- Detección de anomalías o errores en cálculos
- Base para reportes fiscales futuros
- Evidencia en caso de disputas con técnicos o clientes

#### Navegación:
- Nuevo botón "📊 Dashboard Financiero" en AdminPage
- Solo visible para usuarios con rol "admin"

#### Entregables del Día 3:
- DashboardFinancieroPage completa con métricas en tiempo real
- 4 tarjetas de KPIs financieros
- Lista detallada de transacciones con desglose por servicio
- Filtro por período temporal
- Cloud Function de logs financieros deployada en Firebase
- Logs estructurados en Cloud Logging de GCP
- Navegación desde AdminPage

---

### DÍA 4 — Preparación Stripe Connect + Asignación Automática de Técnicos
**Enfoque:** Preparar la infraestructura para pagos directos a técnicos + Construir el algoritmo inteligente de asignación

#### Parte A: Preparación para Stripe Connect

##### ¿Qué es Stripe Connect y por qué prepararlo ahora?

Actualmente, todos los pagos van a la cuenta de Stripe de Edgar (la plataforma). Luego, Edgar tendría que transferir manualmente el dinero a cada técnico. Esto no es escalable.

**Stripe Connect** permite que cada técnico tenga su propia cuenta de Stripe vinculada a la plataforma. Cuando un cliente paga, el dinero se divide automáticamente:
- 15% va directo a Edgar (comisión)
- 85% va directo al técnico (menos fees de Stripe)

Aunque no implementaremos Stripe Connect completo en este hito, **prepararemos toda la infraestructura** para que la migración futura sea sencilla:

- Campo `stripeConnectAccountId` agregado a la colección `users` para técnicos
- Documentación completa del proceso de migración
- Flujo de onboarding documentado (cómo un técnico conectaría su cuenta bancaria)
- Estimación de tiempo y costo para la implementación completa

##### Documentación de Migración:

Se generará un documento técnico que incluye:
1. Pasos para activar Stripe Connect en la cuenta principal
2. Flujo de onboarding para técnicos (formulario KYC requerido por Stripe)
3. Cambios necesarios en Cloud Functions (de PaymentIntent simple a PaymentIntent con `transfer_data`)
4. Consideraciones legales y fiscales (cada país tiene regulaciones diferentes)
5. Timeline estimado: 1-2 semanas adicionales de desarrollo

#### Parte B: Algoritmo de Asignación Automática de Técnicos

##### ¿Cómo funciona actualmente?

Actualmente, la asignación de técnicos es 100% manual: Edgar entra al panel de administración, revisa los técnicos disponibles, y asigna uno manualmente. Esto funciona para pocos servicios, pero no escala.

##### ¿Cómo funcionará con la asignación automática?

Se creará una Cloud Function que se activa automáticamente cuando un nuevo servicio se crea con `tipoAsignacion == "automatica"`. El algoritmo sigue estos pasos:

**Paso 1 — Filtrado inicial:**
- Buscar solo técnicos con `rol == "tecnico"`
- Que estén `disponible == true`
- Que tengan la especialidad requerida (`especialidades` contiene la `categoria` del servicio)
- Que tengan `estadoValidacion == "aprobado"` (cuando se implemente Hito 9)

**Paso 2 — Ranking por calificación:**
- Ordenar los técnicos filtrados por `calificacionPromedio` de mayor a menor
- En caso de empate, priorizar al que tenga menos servicios activos (menor carga de trabajo)

**Paso 3 — Asignación:**
- Seleccionar al técnico mejor calificado
- Actualizar el servicio: `tecnicoId`, `tecnicoNombre`, `tecnicoTelefono`, `estado = "asignado"`, `asignadoAt`
- Enviar notificación push al técnico seleccionado

**Paso 4 — Fallback:**
- Si no hay técnicos disponibles con esa especialidad, el servicio queda como `pendiente`
- Se envía notificación al administrador: "Servicio sin técnico disponible — requiere asignación manual"
- Edgar puede entonces asignar manualmente desde el panel de admin

##### Escenario de ejemplo:

```
Nuevo servicio creado:
  Categoría: Plomería
  tipoAsignacion: "automatica"

Técnicos disponibles con especialidad "plomeria":
  1. Juan Pérez    — ⭐ 4.8 — 2 servicios activos — disponible ✅
  2. Pedro López   — ⭐ 4.5 — 1 servicio activo  — disponible ✅
  3. Carlos Ruiz   — ⭐ 4.2 — 0 servicios activos — disponible ✅
  4. Miguel Torres — ⭐ 4.9 — 5 servicios activos — NO disponible ❌

Resultado: Juan Pérez asignado (mejor rating entre los disponibles)
Notificación push enviada a Juan Pérez
```

##### Preparación para geolocalización futura:

Aunque en este hito el algoritmo no incluye proximidad geográfica (requiere GeoHash, que es más complejo), se dejará documentado y preparado para que en una fase futura se agregue como factor adicional de ranking.

#### Entregables del Día 4:
- Campo `stripeConnectAccountId` en colección users
- Documento de migración a Stripe Connect (completo y detallado)
- Cloud Function `autoAssignTechnician` deployada
- Algoritmo de asignación por calificación + disponibilidad + especialidad
- Manejo de fallback cuando no hay técnicos disponibles
- Notificación push al técnico asignado
- Notificación al admin cuando asignación automática falla
- Tests validando diferentes escenarios de asignación

---

### DÍA 5 — Optimización de Rendimiento y Velocidad
**Enfoque:** Asegurar que la aplicación sea rápida, eficiente y no genere costos innecesarios en Firebase

#### ¿Por qué es crítico optimizar ahora?

Firebase cobra por cada lectura, escritura y almacenamiento. Una aplicación mal optimizada puede generar miles de lecturas innecesarias, lo que significa:
- **Costos elevados** para Edgar en la factura mensual de Firebase
- **Lentitud** para los usuarios (especialmente en conexiones móviles)
- **Mala experiencia** que causa abandono de la app

El objetivo es que **todas las pantallas carguen en menos de 2 segundos**, incluso con cientos de servicios y técnicos en la base de datos.

#### Índices Compuestos en Firestore:

Firestore requiere índices compuestos para queries con múltiples filtros. Sin estos índices, las consultas fallan o son extremadamente lentas. Se crearán y verificarán los siguientes 9 índices:

| # | Colección | Campos | Propósito |
|---|-----------|--------|-----------|
| 1 | servicios | estado + createdAt (DESC) | AdminPage: filtrar por estado, ordenar por fecha |
| 2 | servicios | tecnicoId + estado + createdAt (DESC) | HomeTecnicoPage: servicios del técnico |
| 3 | servicios | clienteId + createdAt (DESC) | HomeClientePage: servicios del cliente |
| 4 | servicios | categoria + estado + createdAt (DESC) | AdminPage: filtrar por categoría y estado |
| 5 | users | rol + disponible + calificacionPromedio (DESC) | AsignarTecnicoPage: técnicos disponibles |
| 6 | transacciones | tecnicoId + estado + createdAt (DESC) | MisGananciasPage: transacciones del técnico |
| 7 | transacciones | estado + createdAt (DESC) | DashboardFinanciero: transacciones recientes |
| 8 | mensajes | servicioId + createdAt (ASC) | ChatPage: mensajes de un servicio |
| 9 | resenas | tecnicoId + createdAt (DESC) | PerfilTecnico: reseñas del técnico |

#### Paginación en listas:

Actualmente, las listas cargan TODOS los documentos de una vez. Con 500 servicios, eso significa 500 lecturas instantáneas. Implementaremos paginación:

- **AdminPage**: 20 servicios por página, botón "Cargar más"
- **HomeClientePage**: 10 servicios, scroll infinito
- **HomeTecnicoPage**: 15 servicios, scroll infinito
- **ChatPage**: 50 mensajes iniciales, lazy load de mensajes anteriores al hacer scroll hacia arriba
- **MisGananciasPage**: 15 transacciones por página

#### Caché de datos estáticos:

Los datos que cambian raramente (como las tarifas por categoría) se almacenarán en caché local para evitar lecturas repetitivas a Firestore:

- `tarifas` → se lee una vez y se cachea por 24 horas
- `configuracion/comisiones` → se lee una vez y se cachea por 1 hora
- Esto puede reducir las lecturas de Firestore hasta en un 30-40%

#### Reducción de lecturas redundantes:

- Identificar y eliminar queries duplicadas (misma consulta ejecutada múltiples veces en una pantalla)
- Usar `Document from Reference` en lugar de queries completas cuando ya tenemos la referencia
- Denormalizar datos frecuentemente consultados (ejemplo: `tecnicoNombre` en servicios para no tener que leer la colección users)

#### Entregables del Día 5:
- 9 índices compuestos creados y deployados en Firebase
- Paginación implementada en las 5 listas principales
- Sistema de caché configurado para datos estáticos
- Lazy loading en ChatPage para mensajes antiguos
- Lecturas redundantes eliminadas
- Verificación: todas las pantallas cargan en < 2 segundos
- Estimación de ahorro en lecturas de Firestore documentada

---

### DÍA 6 — Testing Completo de Seguridad
**Enfoque:** Verificar que ningún usuario pueda acceder a datos que no le pertenecen, ni realizar acciones no autorizadas

#### ¿Por qué es crítico el testing de seguridad?

Esta aplicación maneja **datos personales** (nombres, teléfonos, direcciones) y **dinero real** (pagos con tarjeta de crédito). Una vulnerabilidad de seguridad podría significar:
- Un cliente viendo los datos personales de otro cliente
- Un técnico modificando sus propias calificaciones
- Un usuario no autenticado accediendo a información sensible
- Alguien creándose una cuenta de administrador sin autorización
- Manipulación de montos de transacciones

#### Plan de testing detallado:

##### Test 1: Aislamiento de datos entre clientes
- **Qué probamos:** ¿Puede el Cliente A ver los servicios, mensajes o datos del Cliente B?
- **Cómo:** Iniciar sesión como Cliente A, intentar acceder directamente a documentos de Cliente B usando la API de Firestore
- **Resultado esperado:** Acceso denegado (403 Forbidden)
- **Regla de Firestore que protege:** `request.auth.uid == resource.data.clienteId`

##### Test 2: Aislamiento de datos entre técnicos
- **Qué probamos:** ¿Puede el Técnico A modificar servicios asignados al Técnico B?
- **Cómo:** Iniciar sesión como Técnico A, intentar actualizar un documento de servicio asignado a Técnico B
- **Resultado esperado:** Escritura denegada
- **Regla de Firestore que protege:** `request.auth.uid == resource.data.tecnicoId`

##### Test 3: Acceso sin autenticación
- **Qué probamos:** ¿Puede alguien sin cuenta acceder a cualquier colección?
- **Cómo:** Hacer peticiones a Firestore sin token de autenticación
- **Resultado esperado:** Acceso denegado en todas las colecciones (excepto lectura pública de reseñas)

##### Test 4: Creación no autorizada de administrador
- **Qué probamos:** ¿Puede alguien registrarse como administrador desde la app?
- **Cómo:** Intentar crear un documento en users con `rol: "admin"` desde el formulario de registro
- **Resultado esperado:** El campo `rol` se fuerza a "cliente" en la creación; solo se puede cambiar manualmente en Firebase Console
- **Protección:** Regla de Firestore que no permite escribir `rol: "admin"` excepto desde Cloud Functions o Console

##### Test 5: Tokens expirados
- **Qué probamos:** ¿Funciona correctamente la expiración de sesión?
- **Cómo:** Usar un token de autenticación expirado para acceder a datos
- **Resultado esperado:** Acceso denegado, redirección a login

##### Test 6: Manipulación de transacciones
- **Qué probamos:** ¿Puede un cliente o técnico crear/modificar transacciones directamente?
- **Cómo:** Intentar crear un documento en la colección `transacciones` desde la app
- **Resultado esperado:** Escritura denegada — solo Cloud Functions pueden crear/modificar transacciones

##### Test 7: Manipulación de calificaciones
- **Qué probamos:** ¿Puede un técnico modificar su propia `calificacionPromedio`?
- **Cómo:** Intentar actualizar el campo `calificacionPromedio` en su documento de usuario
- **Resultado esperado:** Escritura denegada para ese campo específico

#### Cloud Functions Placeholder:

Se crearán funciones placeholder (estructura lista, lógica básica) para funcionalidades futuras:
- `sendAdvancedNotification`: para notificaciones con contenido dinámico y deep links
- `generateMonthlyReport`: para reportes financieros mensuales automáticos
- `cleanupExpiredServices`: para archivar servicios cancelados después de 30 días

#### Entregables del Día 6:
- 7 test cases de seguridad ejecutados y documentados
- Todas las vulnerabilidades encontradas corregidas inmediatamente
- Reporte de seguridad formal con resultados de cada test
- Firestore Rules verificadas y actualizadas si es necesario
- 3 Cloud Functions placeholder deployadas para desarrollo futuro
- Documento de recomendaciones de seguridad para mantenimiento continuo

---

### DÍA 7 — Documentación Completa + Entrega Final del Proyecto
**Enfoque:** Preparar todo para que Edgar pueda operar su negocio de forma independiente

#### ¿Por qué es el día más importante?

De nada sirve construir un sistema perfecto si el dueño del negocio no sabe cómo usarlo. Este día se dedica a crear toda la documentación necesaria para que Edgar pueda:
- Operar el día a día sin ayuda del desarrollador
- Entender qué hacer cuando algo sale mal
- Saber cómo agregar nuevas categorías de servicio o técnicos
- Tener claridad sobre qué funcionalidades futuras están disponibles y cuánto costarían

#### Documentos a entregar:

##### 1. MANUAL_ADMIN.md — Manual del Administrador
Guía paso a paso con capturas de pantalla para todas las operaciones diarias:
- Cómo acceder al panel de administración
- Cómo filtrar servicios por estado y categoría
- Cómo buscar un servicio específico
- Cómo asignar un técnico manualmente a un servicio
- Cómo revisar el dashboard financiero
- Cómo interpretar las métricas de comisiones e ingresos
- Cómo agregar una nueva categoría de servicio
- Cómo modificar tarifas de servicio
- Cómo agregar un nuevo técnico al sistema
- Cómo cambiar el porcentaje de comisión
- Solución de problemas frecuentes (FAQ)

##### 2. GUIA_OPERACION.md — Guía de Operación del Sistema
Documentación técnica del flujo completo:
- Ciclo de vida de un servicio: desde creación hasta pago
- Diagrama de estados del servicio con todas las transiciones posibles
- Roles y permisos detallados (qué puede hacer cada tipo de usuario)
- Flujo de pagos: desde que el cliente paga hasta que el técnico recibe su parte
- Cómo funciona la asignación automática vs manual
- Monitoreo recomendado: qué métricas revisar diariamente
- Plan de contingencia: qué hacer si Stripe, Firebase o la app tiene problemas

##### 3. ROADMAP_FASE3.md — Plan de Funcionalidades Futuras
Documento que describe las funcionalidades solicitadas por Edgar que no están incluidas en el contrato original:
- Hito 8: Sistema de Diagnóstico y Cotización (detalle completo)
- Hito 9: Validación de Documentos de Técnicos (INE, CURP)
- Hito 10: Sistema de Citas para Taller
- Hito 11: Categorización Avanzada de Servicios
- Estimaciones de tiempo y costo para cada hito
- Orden de prioridad recomendado
- Dependencias entre hitos

##### 4. Documentación Técnica Actualizada
Actualización del ANALISIS_TECNICO_PROYECTO.md con:
- Estructura final de todas las colecciones de Firestore
- Lista de todas las Cloud Functions deployadas y su propósito
- Índices compuestos creados
- Reglas de seguridad finales
- Servicios de terceros configurados (Stripe, FCM, etc.)

#### Transferencia de ownership:

**FlutterFlow:**
- Transferir el proyecto a la cuenta de FlutterFlow de Edgar
- Verificar que Edgar tiene acceso completo de edición
- Confirmar que el proyecto se puede exportar a código Flutter nativo

**Firebase:**
- Agregar a Edgar como Owner del proyecto Firebase
- Verificar acceso a: Firestore, Authentication, Storage, Cloud Functions, Cloud Messaging
- Configurar alertas de billing (para evitar costos sorpresa)
- Compartir credenciales de API y configuración

#### Smoke Test Final:

Antes de la entrega, se ejecutará un test completo de todas las funcionalidades para verificar que todo funciona correctamente en conjunto:

| # | Flujo | Escenario de Prueba |
|---|-------|---------------------|
| 1 | Cliente | Registrar nuevo cliente → login → crear servicio con categoría plomería |
| 2 | Cliente | Ver lista de "Mis Servicios" → verificar que el nuevo servicio aparece |
| 3 | Cliente | Entrar al detalle del servicio → verificar toda la información |
| 4 | Admin | Login como admin → ver servicio en panel → asignar técnico manualmente |
| 5 | Técnico | Login como técnico → verificar servicio asignado en su lista |
| 6 | Técnico | Recibir notificación push de asignación |
| 7 | Cliente | Contactar técnico por WhatsApp → verificar que se abre con mensaje prellenado |
| 8 | Ambos | Chat interno: enviar mensajes cliente↔técnico → verificar en tiempo real |
| 9 | Cliente | Escribir reseña del técnico (5 estrellas + comentario) |
| 10 | Cliente | Pagar servicio con Stripe (tarjeta de test) |
| 11 | Sistema | Verificar que comisión se calculó automáticamente |
| 12 | Técnico | Ver "Mis Ganancias" → verificar desglose correcto |
| 13 | Admin | Ver Dashboard Financiero → verificar transacción registrada |
| 14 | Sistema | Crear servicio con asignación automática → verificar técnico asignado |

#### Sesión de walkthrough con Edgar:
- Video llamada de 30-60 minutos
- Demostración en vivo de todas las funcionalidades
- Edgar prueba el sistema con guía del desarrollador
- Resolución de dudas en tiempo real
- Grabación del walkthrough para referencia futura

#### Entregables del Día 7:
- Manual del Administrador completo con capturas de pantalla
- Guía de Operación del Sistema con diagramas de flujo
- Roadmap de Fase 3 con estimaciones
- Documentación técnica actualizada
- Proyecto FlutterFlow transferido a cuenta de Edgar
- Proyecto Firebase con Edgar como Owner
- Alertas de billing configuradas
- Smoke test de 14 escenarios completado exitosamente
- Video walkthrough grabado y entregado
- Sesión de Q&A completada

---

## 📊 RESUMEN EJECUTIVO POR DÍA

| Día | Enfoque Principal | Hito | Valor para el Negocio |
|-----|-------------------|------|----------------------|
| 1 | Cálculo de comisiones | H6 | El dinero se distribuye automáticamente |
| 2 | Pantalla de ganancias (técnico) | H6 | Técnicos ven cuánto ganan — genera confianza |
| 3 | Dashboard financiero (admin) | H6 | Edgar controla su negocio con datos reales |
| 4 | Stripe Connect prep + auto-asignación | H6+H7 | Prepara pagos directos + escala la asignación |
| 5 | Optimización de velocidad | H7 | App rápida = usuarios contentos + menor costo Firebase |
| 6 | Testing de seguridad | H7 | Protección de datos personales y dinero |
| 7 | Documentación + entrega | H7 | Edgar opera su negocio de forma independiente |

---

## ⚠️ RIESGOS Y MITIGACIONES

| Riesgo | Probabilidad | Impacto | Plan de Mitigación |
|--------|-------------|---------|-------------------|
| Hito 5 (Stripe) tiene bugs pendientes | Media | Alto | Verificar al 100% antes de iniciar Día 1. Si hay bugs, resolverlos como prerrequisito. |
| Cloud Functions con errores en producción | Media | Alto | Testing exhaustivo en Día 1 con múltiples escenarios. Monitoreo activo las primeras 48 horas. |
| Índices de Firestore tardan en deployar | Baja | Medio | Crear índices temprano en Día 5 (pueden tardar minutos a horas en activarse). |
| Vulnerabilidades de seguridad críticas encontradas | Media | Alto | Se reserva tiempo en Día 6 para correcciones. Si son mayores, se extiende un día adicional. |
| Edgar no disponible para la sesión de transfer | Baja | Medio | Coordinar horario con 48h de anticipación. Tener plan B: transfer asincrónico con video tutorial. |
| Stripe Connect requiere verificación KYC adicional | Baja | Bajo | Solo se prepara la infraestructura en este hito, la activación completa queda para fase futura. |

---

## 📋 PREREQUISITOS ANTES DE INICIAR

1. ✅ Hito 5 (Stripe) completamente funcional y testeado
2. ✅ Cloud Functions de Stripe (createPaymentIntent, handleStripeWebhook) deployadas
3. ✅ Colección `transacciones` creada y recibiendo datos de pagos
4. ✅ Acceso a Firebase Console con permisos de deploy de Cloud Functions
5. ✅ Cuenta de Edgar lista para recibir transfer de FlutterFlow y Firebase
6. ✅ Horario coordinado con Edgar para sesión de walkthrough (Día 7)

---

## 💰 PRESUPUESTO

| Concepto | Monto | Detalle |
|----------|-------|---------|
| Hito 6: Comisión Automática + Dashboard Financiero | $500 | Cloud Functions, MisGanancias, Dashboard Admin, Stripe Connect prep |
| Hito 7: Escalamiento + Seguridad + Entrega | $200 | Auto-asignación, índices, security testing, documentación, transfer |
| **Total Hitos 6+7** | **$700** | |
| **Total Acumulado Proyecto (Hitos 1-7)** | **$3,000** | Completación del contrato original |

**Método de pago:** Según acuerdo en Workana (escrow)
**Condición de liberación:** Cumplimiento de todos los criterios de aceptación de ambos hitos + smoke test exitoso + transfer completado

---

*Documento generado el 18 de marzo de 2026*
*Proyecto: Servicios Domicilio MVP — Fase 2 Final*
*Versión: 2.0*
