# DOCUMENTO TÉCNICO COMPLETO - HITO 1
## App de Servicios Técnicos a Domicilio - Arquitectura y Modelo de Datos

**Para:** Edgar Daniel Godoy Montalvo
**De:** JunJun
**Proyecto:** MVP - Aplicación de Servicios a Domicilio
**Presupuesto:** USD $3,000 (Fase 1: $1,600 | Fase 2: $1,400)
**Duración:** 6 semanas
**Fecha:** 3 de marzo de 2026

---

## 📋 ÍNDICE

1. [Resumen Ejecutivo](#resumen-ejecutivo)
2. [Modelo de Datos Propuesto (Firestore)](#modelo-de-datos-firestore)
3. [Estructura Inicial de Firestore](#estructura-inicial-firestore)
4. [Reglas de Seguridad](#reglas-de-seguridad)
5. [Arquitectura Técnica](#arquitectura-técnica)
6. [Flujos de Usuario](#flujos-de-usuario)
7. [Sistema de Costos y Comisiones](#sistema-de-costos)
8. [Accesos Necesarios](#accesos-necesarios)

---

<a name="resumen-ejecutivo"></a>
## 1. RESUMEN EJECUTIVO

Hola Edgar,

Este documento contiene la **arquitectura técnica completa** para el desarrollo de tu aplicación de servicios a domicilio. He analizado detalladamente todas nuestras conversaciones y el alcance acordado para entregarte una solución escalable y profesional.

### ¿Qué vamos a construir?

Una **aplicación móvil de marketplace** (iOS + Android) que conecta:
- 👤 **Clientes** que necesitan servicios técnicos a domicilio
- 🔧 **Técnicos** que realizan los servicios
- 👨‍💼 **Administrador (tú)** que gestiona y asigna servicios

### Stack Tecnológico

| Componente | Tecnología | Justificación |
|------------|------------|---------------|
| **Frontend** | FlutterFlow + Flutter | Desarrollo rápido, cross-platform, código exportable |
| **Backend** | Firebase (Firestore, Auth, Storage) | Serverless, escalable, tiempo real |
| **Pagos** | Stripe | Seguro, confiable, APIs robustas |
| **Mapas** | Google Maps Platform | Geolocalización precisa, geocoding |

### Estructura del Proyecto

**FASE 1 - MVP Operativo ($1,600 - 3 semanas)**

| Hito | Presupuesto | Entregable |
|------|-------------|------------|
| Hito 1 | $300 | Arquitectura + Autenticación por roles |
| Hito 2 | $700 | Solicitudes + Fotos + Google Maps |
| Hito 3 | $500 | Panel Admin + Asignación + WhatsApp |
| Hito 4 | $100 | Sistema de Estimación + Optimización |

**FASE 2 - Pagos y Comisiones ($1,400 - 3 semanas)**

| Hito | Presupuesto | Entregable |
|------|-------------|------------|
| Hito 5 | $700 | Integración Stripe + Pagos en app |
| Hito 6 | $500 | Sistema de Comisiones automáticas |
| Hito 7 | $200 | Optimización final + Entrega |

---

<a name="modelo-de-datos-firestore"></a>
## 2. MODELO DE DATOS PROPUESTO (FIRESTORE)

Este es el corazón de la aplicación. He diseñado una estructura escalable que NO requerirá reestructuración en Fase 2.

### Principios de Diseño

✅ **Campos preparados desde día 1:** Los campos para pagos ya están definidos (aunque no se usen hasta Fase 2)
✅ **Denormalización estratégica:** Algunos datos se duplican para reducir lecturas
✅ **Seguridad por defecto:** Reglas estrictas de acceso por rol
✅ **Optimizado para queries:** Índices compuestos para búsquedas eficientes
✅ **GeoHash para ubicaciones:** Búsquedas geográficas eficientes

### Colecciones Principales

Firestore tendrá **4 colecciones principales**:

```
📦 Firestore Database
│
├── 👥 users/               (Todos los usuarios del sistema)
│
├── 🛠️ servicios/            (Solicitudes de servicio)
│   └── 💬 mensajes/        (Subcollection - Chat interno)
│
├── ⚙️ configuracion/        (Tarifas y parámetros configurables)
│
└── 💰 transacciones/       (Registro de pagos - Fase 2)
```

---

### 2.1 Colección: `users`

**Propósito:** Almacenar información de todos los usuarios (clientes, técnicos, administradores)

**Ruta:** `users/{userId}`

**Estructura:**

```javascript
{
  // DATOS BÁSICOS (Obligatorios)
  "userId": "ABC123XYZ",                    // ID autogenerado por Firebase Auth
  "email": "usuario@email.com",            // Email único
  "nombre": "Juan",                        // Nombre del usuario
  "apellido": "Pérez",                     // Apellido
  "telefono": "+52 123 456 7890",          // Teléfono con código de país
  "rol": "cliente",                        // "cliente" | "tecnico" | "admin"

  // DATOS ADICIONALES
  "fotoPerfil": "https://storage.googleapis.com/...", // URL de Storage (nullable)
  "activo": true,                          // Estado de la cuenta
  "verificado": false,                     // Si el usuario verificó su email

  // ESPECÍFICO PARA TÉCNICOS
  "especialidades": ["electricidad", "plomeria"],  // Array (solo para técnicos)
  "documentoIdentidad": "RFC123456",       // RFC o identificación (solo técnicos)
  "disponible": true,                      // Si está disponible para recibir servicios
  "calificacionPromedio": 4.8,             // Rating promedio (futuro)
  "serviciosCompletados": 0,               // Contador de servicios realizados

  // UBICACIÓN POR DEFECTO (Opcional)
  "ubicacionDefecto": {                    // GeoPoint de Firebase
    "_latitude": 19.4326,
    "_longitude": -99.1332
  },
  "direccionDefecto": "Calle 5 #123, Col. Centro",

  // TIMESTAMPS
  "createdAt": Timestamp,                  // Fecha de registro
  "updatedAt": Timestamp,                  // Última actualización
  "lastLoginAt": Timestamp                 // Último inicio de sesión
}
```

**Índices necesarios:**

```javascript
// Para búsquedas eficientes
users:
  - [rol, activo]
  - [rol, disponible, serviciosCompletados] (desc)
```

**Ejemplos:**

```javascript
// Usuario Cliente
{
  "userId": "CLIENT001",
  "email": "maria.gonzalez@email.com",
  "nombre": "María",
  "apellido": "González",
  "telefono": "+52 123 456 7890",
  "rol": "cliente",
  "fotoPerfil": null,
  "activo": true,
  "verificado": true,
  "createdAt": "2026-03-01T10:30:00Z",
  "updatedAt": "2026-03-01T10:30:00Z"
}

// Usuario Técnico
{
  "userId": "TECH001",
  "email": "juan.perez@email.com",
  "nombre": "Juan",
  "apellido": "Pérez",
  "telefono": "+52 987 654 3210",
  "rol": "tecnico",
  "fotoPerfil": "https://storage.googleapis.com/...",
  "activo": true,
  "verificado": true,
  "especialidades": ["electricidad", "refrigeracion"],
  "documentoIdentidad": "PEJJ850101ABC",
  "disponible": true,
  "calificacionPromedio": 4.8,
  "serviciosCompletados": 15,
  "ubicacionDefecto": {
    "_latitude": 19.4326,
    "_longitude": -99.1332
  },
  "createdAt": "2026-02-15T08:00:00Z",
  "updatedAt": "2026-03-03T14:20:00Z"
}

// Usuario Administrador
{
  "userId": "ADMIN001",
  "email": "edgar@tuempresa.com",
  "nombre": "Edgar",
  "apellido": "Godoy",
  "telefono": "+52 555 123 4567",
  "rol": "admin",
  "activo": true,
  "verificado": true,
  "createdAt": "2026-02-01T00:00:00Z",
  "updatedAt": "2026-03-03T15:00:00Z"
}
```

---

### 2.2 Colección: `servicios`

**Propósito:** Cada documento representa una solicitud de servicio desde su creación hasta el pago

**Ruta:** `servicios/{servicioId}`

**Estructura:**

```javascript
{
  // IDENTIFICADOR
  "servicioId": "SRV-20260303-001",        // ID único autogenerado

  // ===== INFORMACIÓN DEL CLIENTE =====
  "clienteId": "CLIENT001",                // Reference a users/{clienteId}
  "clienteNombre": "María González",       // Denormalizado para queries rápidas
  "clienteTelefono": "+52 123 456 7890",   // Denormalizado
  "clienteEmail": "maria@email.com",       // Denormalizado

  // ===== INFORMACIÓN DEL TÉCNICO =====
  "tecnicoId": null,                       // Reference a users/{tecnicoId} (nullable)
  "tecnicoNombre": null,                   // Se llena al asignar (nullable)
  "tecnicoTelefono": null,                 // Se llena al asignar (nullable)

  // ===== DESCRIPCIÓN DEL SERVICIO =====
  "titulo": "Reparación de fuga en cocina",
  "descripcion": "Hay una fuga de agua debajo del fregadero. Comenzó ayer en la noche y el agua está goteando constantemente.",
  "categoria": "plomeria",                 // "electricidad" | "plomeria" | "limpieza" | etc.
  "urgencia": "urgente",                   // "normal" | "urgente"

  // ===== UBICACIÓN =====
  "ubicacion": {                           // GeoPoint de Firebase
    "_latitude": 19.4326,
    "_longitude": -99.1332
  },
  "ubicacionTexto": "Calle 5 #123, Colonia Centro, CDMX",  // Dirección formateada
  "geohash": "9g3w6b5h",                   // Para búsquedas por proximidad
  "referenciasUbicacion": "Edificio azul, departamento 301",  // Opcional

  // ===== FOTOS =====
  "fotos": [                               // Array de URLs de Firebase Storage
    "https://storage.googleapis.com/.../foto1.jpg",
    "https://storage.googleapis.com/.../foto2.jpg",
    "https://storage.googleapis.com/.../foto3.jpg"
  ],

  // ===== ESTADO DEL SERVICIO =====
  "estado": "pendiente",                   // Ver máquina de estados abajo

  // ===== ESTIMACIÓN Y COSTOS =====
  "estimacionCosto": 75.00,                // Calculado automáticamente
  "costoFinal": null,                      // Se define al completar (nullable)
  "desgloseCosto": {                       // Detalle del cálculo
    "tarifaBase": 50.00,
    "multiplicadorUrgencia": 1.5,
    "subtotal": 75.00,
    "recargoDistancia": 0.00,
    "recargoHorario": 0.00,
    "total": 75.00
  },

  // ===== TIMESTAMPS =====
  "createdAt": Timestamp,                  // Fecha de creación
  "updatedAt": Timestamp,                  // Última actualización
  "asignadoAt": null,                      // Fecha de asignación (nullable)
  "enProgresoAt": null,                    // Fecha de inicio (nullable)
  "completadoAt": null,                    // Fecha de completado (nullable)
  "pagadoAt": null,                        // Fecha de pago (nullable)

  // ===== CAMPOS PREPARADOS PARA FASE 2 (PAGOS) =====
  // Estos campos están definidos pero son null hasta Fase 2
  "montoPagado": null,                     // Monto total pagado por el cliente
  "comisionPlataforma": null,              // 15% para la plataforma
  "comisionStripe": null,                  // 2.9% + $0.30 de Stripe
  "montoTecnico": null,                    // Monto neto que recibe el técnico
  "estadoPago": null,                      // "pendiente" | "procesando" | "completado" | "fallido"
  "stripePaymentIntentId": null,           // ID del PaymentIntent de Stripe
  "stripeChargeId": null,                  // ID del Charge de Stripe

  // ===== METADATA =====
  "notasInternas": "",                     // Notas del admin (no visible para cliente/técnico)
  "canceladoPor": null,                    // userId de quien canceló (si aplica)
  "motivoCancelacion": null,               // Razón de cancelación (si aplica)
  "version": 1                             // Para migraciones futuras
}
```

**Máquina de Estados:**

```
[PENDIENTE] → [ASIGNADO] → [EN_PROGRESO] → [COMPLETADO] → [PAGO_PENDIENTE] → [PAGADO]
     ↓              ↓              ↓               ↓
[CANCELADO]   [CANCELADO]   [CANCELADO]    [CANCELADO]
```

**Estados explicados:**

- `pendiente`: Servicio creado, esperando asignación
- `asignado`: Técnico asignado, esperando que inicie
- `en_progreso`: Técnico está realizando el servicio
- `completado`: Servicio terminado (en Fase 1 termina aquí)
- `pago_pendiente`: (Fase 2) Esperando pago del cliente
- `pagado`: (Fase 2) Pago completado
- `cancelado`: Servicio cancelado (en cualquier etapa)

**Índices necesarios:**

```javascript
servicios:
  - [estado, createdAt] (desc)
  - [clienteId, createdAt] (desc)
  - [tecnicoId, estado, createdAt] (desc)
  - [categoria, estado, createdAt] (desc)
  - [geohash, estado]                     // Para búsquedas por proximidad
  - [estadoPago, completadoAt] (desc)     // Para Fase 2
```

**Ejemplo completo:**

```javascript
{
  "servicioId": "SRV-20260303-001",
  "clienteId": "CLIENT001",
  "clienteNombre": "María González",
  "clienteTelefono": "+52 123 456 7890",
  "clienteEmail": "maria@email.com",
  "tecnicoId": "TECH001",
  "tecnicoNombre": "Juan Pérez",
  "tecnicoTelefono": "+52 987 654 3210",
  "titulo": "Reparación de fuga en cocina",
  "descripcion": "Hay una fuga de agua debajo del fregadero. Comenzó ayer en la noche.",
  "categoria": "plomeria",
  "urgencia": "urgente",
  "ubicacion": {
    "_latitude": 19.4326,
    "_longitude": -99.1332
  },
  "ubicacionTexto": "Calle 5 #123, Colonia Centro, CDMX",
  "geohash": "9g3w6b5h",
  "referenciasUbicacion": "Edificio azul, departamento 301",
  "fotos": [
    "https://storage.googleapis.com/servicios-mvp/SRV-20260303-001/foto1.jpg",
    "https://storage.googleapis.com/servicios-mvp/SRV-20260303-001/foto2.jpg"
  ],
  "estado": "asignado",
  "estimacionCosto": 75.00,
  "costoFinal": null,
  "desgloseCosto": {
    "tarifaBase": 50.00,
    "multiplicadorUrgencia": 1.5,
    "subtotal": 75.00,
    "recargoDistancia": 0.00,
    "recargoHorario": 0.00,
    "total": 75.00
  },
  "createdAt": "2026-03-03T10:30:00Z",
  "updatedAt": "2026-03-03T11:15:00Z",
  "asignadoAt": "2026-03-03T11:15:00Z",
  "enProgresoAt": null,
  "completadoAt": null,
  "pagadoAt": null,
  "montoPagado": null,
  "comisionPlataforma": null,
  "comisionStripe": null,
  "montoTecnico": null,
  "estadoPago": null,
  "stripePaymentIntentId": null,
  "stripeChargeId": null,
  "notasInternas": "",
  "canceladoPor": null,
  "motivoCancelacion": null,
  "version": 1
}
```

---

### 2.3 Subcollection: `servicios/{servicioId}/mensajes`

**Propósito:** Chat interno entre cliente y técnico dentro de cada servicio

**Ruta:** `servicios/{servicioId}/mensajes/{mensajeId}`

**Estructura:**

```javascript
{
  "mensajeId": "MSG001",                   // ID autogenerado
  "userId": "CLIENT001",                   // Reference a users/{userId}
  "nombreUsuario": "María González",       // Denormalizado
  "rolUsuario": "cliente",                 // "cliente" | "tecnico" | "admin"
  "mensaje": "¿Puedes venir hoy en la tarde?",
  "timestamp": Timestamp,
  "leido": false,                          // Si el destinatario lo leyó
  "tipo": "texto",                         // "texto" | "sistema" | "imagen"
  "metadata": {                            // Opcional, para mensajes especiales
    "imagenUrl": null,                     // Si tipo = "imagen"
    "accion": null                         // Si tipo = "sistema"
  }
}
```

**Ejemplo:**

```javascript
// Mensaje de cliente
{
  "mensajeId": "MSG001",
  "userId": "CLIENT001",
  "nombreUsuario": "María González",
  "rolUsuario": "cliente",
  "mensaje": "¿Puedes venir hoy en la tarde después de las 3pm?",
  "timestamp": "2026-03-03T11:20:00Z",
  "leido": false,
  "tipo": "texto",
  "metadata": {}
}

// Respuesta de técnico
{
  "mensajeId": "MSG002",
  "userId": "TECH001",
  "nombreUsuario": "Juan Pérez",
  "rolUsuario": "tecnico",
  "mensaje": "Perfecto, estaré ahí a las 3:30pm",
  "timestamp": "2026-03-03T11:25:00Z",
  "leido": true,
  "tipo": "texto",
  "metadata": {}
}

// Mensaje del sistema
{
  "mensajeId": "MSG003",
  "userId": "SYSTEM",
  "nombreUsuario": "Sistema",
  "rolUsuario": "admin",
  "mensaje": "El servicio ha sido marcado como completado",
  "timestamp": "2026-03-03T16:45:00Z",
  "leido": true,
  "tipo": "sistema",
  "metadata": {
    "accion": "estado_cambio",
    "estadoAnterior": "en_progreso",
    "estadoNuevo": "completado"
  }
}
```

---

### 2.4 Colección: `configuracion`

**Propósito:** Almacenar parámetros configurables del sistema (tarifas, comisiones, horarios)

**Ruta:** `configuracion/{documento}`

**Documentos:**

#### `configuracion/tarifas`

```javascript
{
  "categorias": {
    "electricidad": {
      "tarifaBase": 75.00,
      "multiplicadores": {
        "normal": 1.0,
        "urgente": 1.5
      },
      "recargoPorKm": 2.50,
      "descripcion": "Instalaciones y reparaciones eléctricas",
      "icono": "⚡",
      "activa": true
    },
    "plomeria": {
      "tarifaBase": 50.00,
      "multiplicadores": {
        "normal": 1.0,
        "urgente": 1.5
      },
      "recargoPorKm": 2.50,
      "descripcion": "Instalaciones y reparaciones de plomería",
      "icono": "🔧",
      "activa": true
    },
    "limpieza": {
      "tarifaBase": 40.00,
      "multiplicadores": {
        "normal": 1.0,
        "urgente": 1.3
      },
      "recargoPorKm": 1.50,
      "descripcion": "Servicios de limpieza residencial",
      "icono": "🧹",
      "activa": true
    },
    "refrigeracion": {
      "tarifaBase": 90.00,
      "multiplicadores": {
        "normal": 1.0,
        "urgente": 1.5
      },
      "recargoPorKm": 3.00,
      "descripcion": "Reparación de refrigeradores y aires acondicionados",
      "icono": "❄️",
      "activa": true
    },
    "carpinteria": {
      "tarifaBase": 60.00,
      "multiplicadores": {
        "normal": 1.0,
        "urgente": 1.5
      },
      "recargoPorKm": 2.00,
      "descripcion": "Reparaciones y trabajos de carpintería",
      "icono": "🪚",
      "activa": true
    }
  },
  "updatedAt": Timestamp,
  "updatedBy": "ADMIN001"
}
```

#### `configuracion/comisiones`

```javascript
{
  "porcentajePlataforma": 15.0,            // Tu comisión (%)
  "porcentajeStripe": 2.9,                 // Comisión de Stripe (%)
  "tarifaFijaStripe": 0.30,                // Tarifa fija de Stripe (USD)
  "updatedAt": Timestamp,
  "updatedBy": "ADMIN001"
}
```

#### `configuracion/parametros`

```javascript
{
  "distanciaBaseKm": 10,                   // Distancia sin recargo
  "horaInicioRecargo": 22,                 // 10:00 PM
  "horaFinRecargo": 6,                     // 6:00 AM
  "multiplicadorNocturno": 1.3,            // Recargo horario nocturno
  "maxFotosPorServicio": 5,                // Límite de fotos
  "maxTamanoFotoMB": 10,                   // Tamaño máximo por foto
  "radioBusquedaTecnicosKm": 50,           // Radio de búsqueda de técnicos
  "tiempoLimiteAsignacionHoras": 24,       // Tiempo para asignar antes de expirar
  "notificacionesActivas": true,
  "updatedAt": Timestamp,
  "updatedBy": "ADMIN001"
}
```

---

### 2.5 Colección: `transacciones` (FASE 2)

**Propósito:** Registro completo de todas las transacciones de pago

**Ruta:** `transacciones/{transaccionId}`

**Estructura:**

```javascript
{
  "transaccionId": "TRX-20260303-001",     // ID único autogenerado

  // REFERENCIAS
  "servicioId": "SRV-20260303-001",        // Reference a servicios/{servicioId}
  "clienteId": "CLIENT001",                // Reference a users/{clienteId}
  "tecnicoId": "TECH001",                  // Reference a users/{tecnicoId}

  // MONTOS
  "montoTotal": 75.00,                     // Monto pagado por el cliente
  "comisionPlataforma": 11.25,             // 15% del total
  "comisionStripe": 2.48,                  // 2.9% + $0.30
  "montoTecnico": 61.27,                   // Lo que recibe el técnico

  // INFORMACIÓN DE STRIPE
  "stripePaymentIntentId": "pi_1234567890",
  "stripeChargeId": "ch_1234567890",
  "stripeCustomerId": "cus_1234567890",

  // ESTADO
  "estado": "completado",                  // "pendiente" | "completado" | "fallido" | "reembolsado"
  "estadoStripe": "succeeded",             // Estado directo de Stripe

  // TIMESTAMPS
  "createdAt": Timestamp,                  // Cuándo se creó el intento de pago
  "completedAt": Timestamp,                // Cuándo se completó
  "failedAt": null,                        // Cuándo falló (nullable)

  // METADATA DEL PAGO
  "metadata": {
    "metodoPago": "card",                  // "card" | "oxxo" | etc.
    "marcaTarjeta": "visa",                // "visa" | "mastercard" | "amex"
    "ultimos4Digitos": "4242",             // Últimos 4 dígitos de la tarjeta
    "pais": "MX",
    "banco": "BBVA"
  },

  // LOGS Y AUDITORÍA
  "logs": [                                // Array de eventos
    {
      "timestamp": Timestamp,
      "evento": "payment_intent_created",
      "detalles": "PaymentIntent creado en Stripe"
    },
    {
      "timestamp": Timestamp,
      "evento": "payment_succeeded",
      "detalles": "Pago procesado exitosamente"
    }
  ],

  // ERROR INFO (si aplica)
  "errorCodigo": null,
  "errorMensaje": null,

  // REEMBOLSO INFO (si aplica)
  "reembolsado": false,
  "reembolsoId": null,
  "reembolsoMonto": null,
  "reembolsoRazon": null,
  "reembolsoAt": null
}
```

**Índices necesarios:**

```javascript
transacciones:
  - [estado, createdAt] (desc)
  - [tecnicoId, estado, createdAt] (desc)
  - [clienteId, createdAt] (desc)
  - [servicioId]
```

**Ejemplo:**

```javascript
{
  "transaccionId": "TRX-20260303-001",
  "servicioId": "SRV-20260303-001",
  "clienteId": "CLIENT001",
  "tecnicoId": "TECH001",
  "montoTotal": 75.00,
  "comisionPlataforma": 11.25,
  "comisionStripe": 2.48,
  "montoTecnico": 61.27,
  "stripePaymentIntentId": "pi_3LqYzT2eZvKYlo2C0x7hqk9l",
  "stripeChargeId": "ch_3LqYzT2eZvKYlo2C0x7hqk9l",
  "stripeCustomerId": "cus_NjHcU6QvFJNZqN",
  "estado": "completado",
  "estadoStripe": "succeeded",
  "createdAt": "2026-03-03T16:50:00Z",
  "completedAt": "2026-03-03T16:50:05Z",
  "failedAt": null,
  "metadata": {
    "metodoPago": "card",
    "marcaTarjeta": "visa",
    "ultimos4Digitos": "4242",
    "pais": "MX",
    "banco": "BBVA"
  },
  "logs": [
    {
      "timestamp": "2026-03-03T16:50:00Z",
      "evento": "payment_intent_created",
      "detalles": "PaymentIntent creado con monto $75.00"
    },
    {
      "timestamp": "2026-03-03T16:50:03Z",
      "evento": "payment_method_attached",
      "detalles": "Método de pago adjuntado"
    },
    {
      "timestamp": "2026-03-03T16:50:05Z",
      "evento": "payment_succeeded",
      "detalles": "Pago procesado exitosamente"
    }
  ],
  "errorCodigo": null,
  "errorMensaje": null,
  "reembolsado": false,
  "reembolsoId": null,
  "reembolsoMonto": null,
  "reembolsoRazon": null,
  "reembolsoAt": null
}
```

---

<a name="estructura-inicial-firestore"></a>
## 3. ESTRUCTURA INICIAL DE FIRESTORE

Así se verá la base de datos de Firestore en Firebase Console al finalizar el Hito 1:

```
📦 servicios-domicilio-mvp (Proyecto Firebase)
│
├── 🔐 Authentication
│   ├── admin@test.com (Admin de prueba)
│   ├── tecnico@test.com (Técnico de prueba)
│   └── cliente@test.com (Cliente de prueba)
│
├── 📊 Firestore Database
│   │
│   ├── 👥 users (Collection)
│   │   ├── {userId-admin} (Document)
│   │   │   ├── email: "admin@test.com"
│   │   │   ├── nombre: "Edgar"
│   │   │   ├── rol: "admin"
│   │   │   └── ...
│   │   │
│   │   ├── {userId-tecnico} (Document)
│   │   │   ├── email: "tecnico@test.com"
│   │   │   ├── nombre: "Juan"
│   │   │   ├── rol: "tecnico"
│   │   │   ├── especialidades: ["electricidad", "plomeria"]
│   │   │   └── ...
│   │   │
│   │   └── {userId-cliente} (Document)
│   │       ├── email: "cliente@test.com"
│   │       ├── nombre: "María"
│   │       ├── rol: "cliente"
│   │       └── ...
│   │
│   ├── 🛠️ servicios (Collection)
│   │   └── {servicioId-001} (Document - Ejemplo)
│   │       ├── servicioId: "SRV-EJEMPLO-001"
│   │       ├── clienteId: {ref-to-user}
│   │       ├── titulo: "Ejemplo de servicio"
│   │       ├── estado: "pendiente"
│   │       ├── ...
│   │       │
│   │       └── 💬 mensajes (Subcollection)
│   │           └── {mensajeId-001} (Document)
│   │               ├── userId: {ref-to-user}
│   │               ├── mensaje: "Mensaje de ejemplo"
│   │               └── ...
│   │
│   ├── ⚙️ configuracion (Collection)
│   │   ├── tarifas (Document)
│   │   │   └── categorias: {
│   │   │       electricidad: {...},
│   │   │       plomeria: {...},
│   │   │       limpieza: {...}
│   │   │   }
│   │   │
│   │   ├── comisiones (Document)
│   │   │   ├── porcentajePlataforma: 15
│   │   │   └── porcentajeStripe: 2.9
│   │   │
│   │   └── parametros (Document)
│   │       ├── distanciaBaseKm: 10
│   │       └── ...
│   │
│   └── 💰 transacciones (Collection - Vacía en Fase 1)
│       └── (Se poblará en Fase 2)
│
├── 📁 Storage
│   ├── usuarios/
│   │   └── {userId}/
│   │       └── perfil/
│   │           └── foto.jpg
│   │
│   └── servicios/
│       └── {servicioId}/
│           ├── foto1.jpg
│           ├── foto2.jpg
│           └── foto3.jpg
│
└── ⚡ Cloud Functions (Se implementan en Fase 2)
    ├── createPaymentIntent
    ├── handleStripeWebhook
    └── calculateCommissions
```

---

<a name="reglas-de-seguridad"></a>
## 4. REGLAS DE SEGURIDAD

Las reglas de seguridad de Firestore son **críticas** para proteger los datos. Estas reglas se implementarán desde el día 1.

### 4.1 Principios de Seguridad

1. ✅ **Autenticación obligatoria:** Nadie puede leer/escribir sin estar autenticado
2. ✅ **Autorización por roles:** Cada rol tiene permisos específicos
3. ✅ **Validación de datos:** Los datos escritos deben cumplir reglas
4. ✅ **No confiar en el cliente:** Toda lógica crítica en backend

### 4.2 Matriz de Permisos

| Colección | Cliente | Técnico | Admin | No autenticado |
|-----------|---------|---------|-------|----------------|
| **users** | Ver solo el propio | Ver solo el propio | Ver todos | ❌ Nada |
| **servicios** | Ver/crear propios | Ver asignados | Ver/modificar todos | ❌ Nada |
| **mensajes** | Ver del servicio propio | Ver del servicio asignado | Ver todos | ❌ Nada |
| **configuracion** | Ver (solo lectura) | Ver (solo lectura) | Ver y modificar | ❌ Nada |
| **transacciones** | ❌ No acceso | Ver propias | Ver todas | ❌ Nada |

### 4.3 Código de Reglas de Firestore

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // ==================== FUNCIONES AUXILIARES ====================

    // Verificar si el usuario está autenticado
    function isAuthenticated() {
      return request.auth != null;
    }

    // Obtener los datos del usuario actual desde Firestore
    function getUserData() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data;
    }

    // Obtener el rol del usuario actual
    function getUserRole() {
      return getUserData().rol;
    }

    // Verificar si el usuario es administrador
    function isAdmin() {
      return isAuthenticated() && getUserRole() == 'admin';
    }

    // Verificar si el usuario es cliente
    function isCliente() {
      return isAuthenticated() && getUserRole() == 'cliente';
    }

    // Verificar si el usuario es técnico
    function isTecnico() {
      return isAuthenticated() && getUserRole() == 'tecnico';
    }

    // Verificar si el usuario es el dueño del recurso
    function isOwner(userId) {
      return isAuthenticated() && request.auth.uid == userId;
    }

    // Verificar si el recurso existe
    function exists(path) {
      return exists(path);
    }

    // ==================== REGLAS PARA USUARIOS ====================

    match /users/{userId} {
      // LECTURA: Solo el mismo usuario o admin puede leer
      allow read: if isOwner(userId) || isAdmin();

      // CREACIÓN: Cualquier usuario autenticado puede crear su propio perfil
      // Solo se permite crear con rol "cliente" o "tecnico" (no "admin")
      allow create: if isAuthenticated() &&
                      request.auth.uid == userId &&
                      request.resource.data.keys().hasAll(['email', 'nombre', 'rol']) &&
                      request.resource.data.rol in ['cliente', 'tecnico'] &&
                      request.resource.data.email == request.auth.token.email;

      // ACTUALIZACIÓN: Solo el mismo usuario o admin puede actualizar
      // No se permite cambiar el rol después de creado
      allow update: if (isOwner(userId) || isAdmin()) &&
                      (!request.resource.data.diff(resource.data).affectedKeys().hasAny(['rol', 'email']));

      // ELIMINACIÓN: Solo admin puede eliminar usuarios
      allow delete: if isAdmin();
    }

    // ==================== REGLAS PARA SERVICIOS ====================

    match /servicios/{servicioId} {
      // LECTURA: Admin ve todo, cliente ve sus servicios, técnico ve los asignados
      allow read: if isAuthenticated() && (
        isAdmin() ||
        (isCliente() && resource.data.clienteId == request.auth.uid) ||
        (isTecnico() && resource.data.get('tecnicoId', null) == request.auth.uid)
      );

      // LISTADO: Permitir queries pero se filtrarán por las reglas de lectura
      allow list: if isAuthenticated();

      // CREACIÓN: Solo clientes pueden crear servicios
      allow create: if isAuthenticated() &&
                      isCliente() &&
                      request.resource.data.clienteId == request.auth.uid &&
                      request.resource.data.estado == 'pendiente' &&
                      request.resource.data.keys().hasAll([
                        'clienteId', 'titulo', 'descripcion', 'categoria',
                        'ubicacion', 'estado', 'estimacionCosto'
                      ]);

      // ACTUALIZACIÓN:
      // - Admin puede actualizar todo
      // - Cliente solo puede actualizar sus servicios en estado "pendiente"
      // - Técnico solo puede actualizar el estado de sus servicios asignados
      allow update: if isAuthenticated() && (
        isAdmin() ||
        (isCliente() &&
         resource.data.clienteId == request.auth.uid &&
         resource.data.estado == 'pendiente') ||
        (isTecnico() &&
         resource.data.get('tecnicoId', null) == request.auth.uid &&
         request.resource.data.diff(resource.data).affectedKeys()
           .hasOnly(['estado', 'updatedAt', 'enProgresoAt', 'completadoAt']))
      );

      // ELIMINACIÓN: Solo admin
      allow delete: if isAdmin();

      // ==================== SUBCOLLECTION: MENSAJES ====================

      match /mensajes/{mensajeId} {
        // LECTURA: Admin, cliente del servicio o técnico asignado
        allow read: if isAuthenticated() && (
          isAdmin() ||
          get(/databases/$(database)/documents/servicios/$(servicioId)).data.clienteId == request.auth.uid ||
          get(/databases/$(database)/documents/servicios/$(servicioId)).data.get('tecnicoId', null) == request.auth.uid
        );

        // CREACIÓN: Admin, cliente del servicio o técnico asignado
        // El userId del mensaje debe coincidir con el usuario autenticado
        allow create: if isAuthenticated() && (
          isAdmin() ||
          get(/databases/$(database)/documents/servicios/$(servicioId)).data.clienteId == request.auth.uid ||
          get(/databases/$(database)/documents/servicios/$(servicioId)).data.get('tecnicoId', null) == request.auth.uid
        ) && request.resource.data.userId == request.auth.uid;

        // ACTUALIZACIÓN: Solo para marcar como leído
        allow update: if isAuthenticated() &&
                        request.resource.data.diff(resource.data).affectedKeys().hasOnly(['leido']);

        // ELIMINACIÓN: No permitida (los mensajes no se eliminan)
        allow delete: if false;
      }
    }

    // ==================== REGLAS PARA CONFIGURACIÓN ====================

    match /configuracion/{document=**} {
      // LECTURA: Cualquier usuario autenticado puede leer la configuración
      allow read: if isAuthenticated();

      // ESCRITURA: Solo admin puede modificar la configuración
      allow write: if isAdmin();
    }

    // ==================== REGLAS PARA TRANSACCIONES (FASE 2) ====================

    match /transacciones/{transaccionId} {
      // LECTURA: Admin puede ver todas, técnico solo sus transacciones
      allow read: if isAuthenticated() && (
        isAdmin() ||
        (isTecnico() && resource.data.tecnicoId == request.auth.uid)
      );

      // ESCRITURA: Solo permitida vía Cloud Functions (no desde cliente)
      // Las Cloud Functions tienen privilegios especiales
      allow create: if false;  // Solo Cloud Functions
      allow update: if false;  // Solo Cloud Functions

      // ELIMINACIÓN: Solo admin (para correcciones)
      allow delete: if isAdmin();
    }
  }
}
```

### 4.4 Reglas de Firebase Storage

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {

    // ==================== FOTOS DE PERFIL ====================

    match /usuarios/{userId}/perfil/{fileName} {
      // LECTURA: Cualquier usuario autenticado puede ver fotos de perfil
      allow read: if request.auth != null;

      // ESCRITURA: Solo el dueño puede subir/modificar su foto de perfil
      allow write: if request.auth != null &&
                     request.auth.uid == userId &&
                     request.resource.size < 5 * 1024 * 1024 && // Máximo 5MB
                     request.resource.contentType.matches('image/.*');  // Solo imágenes
    }

    // ==================== FOTOS DE SERVICIOS ====================

    match /servicios/{servicioId}/{fileName} {
      // LECTURA: Cualquier usuario autenticado puede ver
      // (Las reglas de Firestore determinan qué servicios puede ver)
      allow read: if request.auth != null;

      // ESCRITURA: Solo el cliente que creó el servicio puede subir fotos
      allow write: if request.auth != null &&
                     request.resource.size < 10 * 1024 * 1024 && // Máximo 10MB
                     request.resource.contentType.matches('image/.*') &&
                     // Verificar que el usuario sea el cliente del servicio
                     firestore.get(/databases/(default)/documents/servicios/$(servicioId)).data.clienteId == request.auth.uid;
    }
  }
}
```

---

<a name="arquitectura-tecnica"></a>
## 5. ARQUITECTURA TÉCNICA

### 5.1 Diagrama de Arquitectura

```
┌─────────────────────────────────────────────────────────────────┐
│                        CAPA DE PRESENTACIÓN                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐      │
│  │   App iOS    │    │  App Android │    │  Panel Web   │      │
│  │  (Flutter)   │    │  (Flutter)   │    │ (FlutterFlow)│      │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘      │
│         │                    │                    │               │
│         └────────────────────┼────────────────────┘               │
│                              │                                    │
└──────────────────────────────┼────────────────────────────────────┘
                               │
┌──────────────────────────────┼────────────────────────────────────┐
│                    CAPA DE LÓGICA DE NEGOCIO                      │
├──────────────────────────────┼────────────────────────────────────┤
│                              │                                    │
│                     ┌────────▼─────────┐                         │
│                     │   FlutterFlow    │                         │
│                     │  (Business Logic)│                         │
│                     └────────┬─────────┘                         │
│                              │                                    │
│           ┌──────────────────┼──────────────────┐                │
│           │                  │                  │                │
│     ┌─────▼──────┐    ┌─────▼──────┐    ┌─────▼──────┐         │
│     │  Firebase  │    │   Google   │    │  Firebase  │         │
│     │    Auth    │    │    Maps    │    │  Storage   │         │
│     └────────────┘    └────────────┘    └────────────┘         │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
                               │
┌──────────────────────────────┼────────────────────────────────────┐
│                       CAPA DE DATOS                               │
├──────────────────────────────┼────────────────────────────────────┤
│                              │                                    │
│                     ┌────────▼─────────┐                         │
│                     │    Firestore     │                         │
│                     │    Database      │                         │
│                     │                  │                         │
│                     │  • users         │                         │
│                     │  • servicios     │                         │
│                     │  • configuracion │                         │
│                     │  • transacciones │                         │
│                     └──────────────────┘                         │
│                                                                   │
└───────────────────────────────────────────────────────────────────┘
                               │
┌──────────────────────────────┼────────────────────────────────────┐
│                     CAPA DE INTEGRACIÓN (FASE 2)                  │
├──────────────────────────────┼────────────────────────────────────┤
│                              │                                    │
│           ┌──────────────────┴──────────────────┐                │
│           │                                     │                │
│     ┌─────▼──────┐                      ┌──────▼───────┐        │
│     │   Stripe   │◄─────────────────────┤   Cloud      │        │
│     │   Payment  │       Webhooks       │  Functions   │        │
│     │  Platform  │                      │              │        │
│     └────────────┘                      └──────────────┘        │
│                                                                   │
└───────────────────────────────────────────────────────────────────┘
```

### 5.2 Fórmula de Estimación de Costos

```javascript
// Paso 1: Obtener tarifa base de la categoría
const tarifaBase = configuracion.tarifas[categoria].tarifaBase;

// Paso 2: Aplicar multiplicador de urgencia
const multiplicador = urgencia === 'urgente' ?
                      configuracion.tarifas[categoria].multiplicadores.urgente :
                      configuracion.tarifas[categoria].multiplicadores.normal;

const subtotal = tarifaBase * multiplicador;

// Paso 3: Calcular distancia entre cliente y base (opcional)
const distancia = calcularDistanciaKm(ubicacionCliente, ubicacionBase);

// Paso 4: Aplicar recargo por distancia
const distanciaBase = configuracion.parametros.distanciaBaseKm; // 10 km
const recargoPorKm = configuracion.tarifas[categoria].recargoPorKm;

const recargoDistancia = (distancia > distanciaBase) ?
                         (distancia - distanciaBase) * recargoPorKm :
                         0;

// Paso 5: Aplicar recargo nocturno (opcional - futuro)
const hora = obtenerHoraActual();
const esHorarioNocturno = (hora >= configuracion.parametros.horaInicioRecargo ||
                          hora < configuracion.parametros.horaFinRecargo);

const multiplicadorHorario = esHorarioNocturno ?
                            configuracion.parametros.multiplicadorNocturno :
                            1.0;

const recargoHorario = subtotal * (multiplicadorHorario - 1.0);

// RESULTADO FINAL
const estimacionTotal = subtotal + recargoDistancia + recargoHorario;

// Desglose para mostrar al cliente
const desglose = {
  tarifaBase: tarifaBase,
  multiplicadorUrgencia: multiplicador,
  subtotal: subtotal,
  recargoDistancia: recargoDistancia,
  recargoHorario: recargoHorario,
  total: estimacionTotal
};
```

**Ejemplos de Cálculo:**

```javascript
// Ejemplo 1: Plomería Normal Cercana
categoria = "plomeria";
urgencia = "normal";
distancia = 5 km;

tarifaBase = 50.00;
multiplicador = 1.0;
subtotal = 50.00 × 1.0 = 50.00;
recargoDistancia = 0 (dentro de 10km base);
recargoHorario = 0 (horario diurno);

TOTAL = $50.00

// Ejemplo 2: Electricidad Urgente Lejana
categoria = "electricidad";
urgencia = "urgente";
distancia = 18 km;

tarifaBase = 75.00;
multiplicador = 1.5;
subtotal = 75.00 × 1.5 = 112.50;
recargoDistancia = (18 - 10) × 2.50 = 8 × 2.50 = 20.00;
recargoHorario = 0;

TOTAL = $132.50

// Ejemplo 3: Limpieza Urgente Noche
categoria = "limpieza";
urgencia = "urgente";
distancia = 3 km;
hora = 23:00 (11 PM);

tarifaBase = 40.00;
multiplicador = 1.3; // limpieza tiene multiplicador menor
subtotal = 40.00 × 1.3 = 52.00;
recargoDistancia = 0;
recargoHorario = 52.00 × (1.3 - 1.0) = 52.00 × 0.3 = 15.60;

TOTAL = $67.60
```

### 5.3 Fórmula de Comisiones (Fase 2)

```javascript
// Datos de entrada
const montoTotal = 100.00;  // Monto pagado por el cliente

// Paso 1: Comisión de la plataforma
const porcentajePlataforma = configuracion.comisiones.porcentajePlataforma; // 15%
const comisionPlataforma = montoTotal * (porcentajePlataforma / 100);

// Paso 2: Comisión de Stripe
const porcentajeStripe = configuracion.comisiones.porcentajeStripe; // 2.9%
const tarifaFijaStripe = configuracion.comisiones.tarifaFijaStripe; // $0.30
const comisionStripe = (montoTotal * (porcentajeStripe / 100)) + tarifaFijaStripe;

// Paso 3: Monto neto para el técnico
const montoTecnico = montoTotal - comisionPlataforma - comisionStripe;

// Resultado
const desglose = {
  montoTotal: 100.00,
  comisionPlataforma: 15.00,    // 15% = $15.00
  comisionStripe: 3.20,          // 2.9% + $0.30 = $3.20
  montoTecnico: 81.80            // $100 - $15 - $3.20 = $81.80
};
```

**Tabla de Ejemplos:**

| Monto Cliente | Comisión Plataforma (15%) | Comisión Stripe (2.9%+$0.30) | Monto Técnico | Tu Ganancia |
|---------------|---------------------------|-------------------------------|---------------|-------------|
| $50.00 | $7.50 | $1.75 | $40.75 | $7.50 |
| $75.00 | $11.25 | $2.48 | $61.27 | $11.25 |
| $100.00 | $15.00 | $3.20 | $81.80 | $15.00 |
| $150.00 | $22.50 | $4.65 | $122.85 | $22.50 |
| $200.00 | $30.00 | $6.10 | $163.90 | $30.00 |

---

<a name="flujos-de-usuario"></a>
## 6. FLUJOS DE USUARIO

### 6.1 Flujo Completo: Cliente Solicita Servicio

```
┌─────────────────────────────────────────────────────────────────┐
│ PASO 1: REGISTRO/LOGIN                                          │
└─────────────────────────────────────────────────────────────────┘
Cliente abre la app
  ↓
¿Tiene cuenta?
  ├─ NO → Registro:
  │        • Email + Contraseña
  │        • Nombre + Apellido
  │        • Teléfono
  │        • Rol: "cliente" (automático)
  │        Firebase crea usuario con UID
  │        Documento creado en users/{userId}
  │
  └─ SÍ → Login:
           • Email + Contraseña
           Firebase valida credenciales
           JWT token generado
  ↓
Acceso concedido → Pantalla Home del Cliente

┌─────────────────────────────────────────────────────────────────┐
│ PASO 2: CREAR SOLICITUD                                         │
└─────────────────────────────────────────────────────────────────┘
Cliente toca botón: [Solicitar Servicio]
  ↓
Pantalla: Selección de Categoría
  [⚡ Electricidad]  [🔧 Plomería]  [🧹 Limpieza]
  [❄️ Refrigeración]  [🪚 Carpintería]

Cliente selecciona: "Plomería"
  ↓
Pantalla: Formulario de Servicio
  ┌──────────────────────────────────────┐
  │ Título del servicio:                 │
  │ [Reparación de fuga en cocina______] │
  │                                      │
  │ Descripción:                         │
  │ [Hay una fuga de agua debajo del___] │
  │ [fregadero desde ayer en la noche__] │
  │                                      │
  │ Urgencia:                            │
  │ ( ) Normal   (•) Urgente             │
  │                                      │
  │ Fotos (0/5):                         │
  │ [📷 Tomar foto]  [🖼️ Subir desde galería] │
  │                                      │
  │ Ubicación:                           │
  │ [📍 Usar mi ubicación actual]        │
  │ [Calle 5 #123, Col. Centro, CDMX_]  │
  │ [🗺️ Ver en mapa]                     │
  │                                      │
  │ ─────────────────────────────────    │
  │ ESTIMACIÓN: $75.00                   │
  │ (Tarifa base $50 × Urgente 1.5x)    │
  │                                      │
  │ [Solicitar Servicio]                 │
  └──────────────────────────────────────┘
  ↓
Cliente toca [Solicitar Servicio]
  ↓
FlutterFlow ejecuta:
  1. Validar que todos los campos estén llenos
  2. Subir fotos a Firebase Storage
  3. Obtener coordenadas GPS
  4. Calcular geohash
  5. Calcular estimación de costo
  6. Crear documento en Firestore:

     servicios/{nuevoId}:
       - clienteId: {ref-to-user}
       - titulo: "Reparación de fuga..."
       - descripcion: "Hay una fuga..."
       - categoria: "plomeria"
       - urgencia: "urgente"
       - ubicacion: GeoPoint(19.4326, -99.1332)
       - ubicacionTexto: "Calle 5 #123..."
       - geohash: "9g3w6b5h"
       - fotos: ["url1", "url2", "url3"]
       - estado: "pendiente"
       - estimacionCosto: 75.00
       - createdAt: Timestamp.now()

  7. Enviar notificación a admin
  ↓
Pantalla de confirmación:
  ┌──────────────────────────────────────┐
  │ ✅ Solicitud Enviada                 │
  │                                      │
  │ Tu solicitud #SRV-20260303-001       │
  │ ha sido enviada exitosamente.        │
  │                                      │
  │ Te notificaremos cuando un técnico   │
  │ sea asignado.                        │
  │                                      │
  │ [Ver mis solicitudes]                │
  └──────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ PASO 3: ADMIN ASIGNA TÉCNICO                                    │
└─────────────────────────────────────────────────────────────────┘
Admin (Edgar) recibe notificación push:
  🔔 "Nueva solicitud de servicio #SRV-20260303-001"
  ↓
Admin abre Panel de Administración
  ↓
Dashboard:
  ┌──────────────────────────────────────┐
  │ 📊 Resumen                           │
  │ • 5 Servicios pendientes ⏳          │
  │ • 3 Servicios en progreso 🔧         │
  │ • 12 Servicios completados ✅        │
  │                                      │
  │ Filtros: [Pendientes ▼] [Hoy ▼]     │
  │                                      │
  │ ┌────────────────────────────────┐  │
  │ │ #SRV-20260303-001  🔴 URGENTE  │  │
  │ │ Plomería - Fuga en cocina      │  │
  │ │ María González                  │  │
  │ │ Estimación: $75.00              │  │
  │ │ Creado: Hace 5 minutos          │  │
  │ │ [Ver Detalle]                   │  │
  │ └────────────────────────────────┘  │
  │                                      │
  │ ┌────────────────────────────────┐  │
  │ │ #SRV-20260303-002              │  │
  │ │ Electricidad - Instalación     │  │
  │ │ Pedro Martínez                  │  │
  │ │ ... │
  └──────────────────────────────────────┘
  ↓
Admin hace clic en [Ver Detalle] del servicio #001
  ↓
Detalle del Servicio:
  ┌──────────────────────────────────────┐
  │ Servicio #SRV-20260303-001           │
  │ Estado: PENDIENTE 🔴 URGENTE         │
  │                                      │
  │ 👤 Cliente:                          │
  │ María González                       │
  │ +52 123 456 7890                     │
  │ maria@email.com                      │
  │                                      │
  │ 📝 Descripción:                      │
  │ Reparación de fuga en cocina         │
  │ Hay una fuga de agua debajo del      │
  │ fregadero desde ayer...              │
  │                                      │
  │ 📷 Fotos:                            │
  │ [IMG] [IMG] [IMG]                    │
  │                                      │
  │ 📍 Ubicación:                        │
  │ Calle 5 #123, Col. Centro, CDMX     │
  │ [🗺️ Ver mapa completo]               │
  │                                      │
  │ 💰 Estimación: $75.00                │
  │ Desglose:                            │
  │ • Tarifa base: $50.00                │
  │ • Urgente (1.5x): $75.00             │
  │ • Distancia: $0.00                   │
  │                                      │
  │ ─────────────────────────────────    │
  │                                      │
  │ 🔧 ASIGNAR TÉCNICO:                  │
  │                                      │
  │ ┌────────────────────────────────┐  │
  │ │ Juan Pérez (Plomero)           │  │
  │ │ ⭐ 4.8/5.0 | 15 servicios       │  │
  │ │ 📍 2.3 km de distancia          │  │
  │ │ ✅ Disponible                   │  │
  │ │ [Asignar]                       │  │
  │ └────────────────────────────────┘  │
  │                                      │
  │ ┌────────────────────────────────┐  │
  │ │ Carlos Ramírez (Plomero)       │  │
  │ │ ⭐ 4.5/5.0 | 8 servicios        │  │
  │ │ 📍 5.7 km de distancia          │  │
  │ │ ✅ Disponible                   │  │
  │ │ [Asignar]                       │  │
  │ └────────────────────────────────┘  │
  └──────────────────────────────────────┘
  ↓
Admin hace clic en [Asignar] para Juan Pérez
  ↓
Modal de confirmación:
  ┌──────────────────────────────────────┐
  │ ⚠️ Confirmar Asignación              │
  │                                      │
  │ ¿Asignar servicio #SRV-20260303-001  │
  │ a Juan Pérez?                        │
  │                                      │
  │ [Cancelar]  [Confirmar]              │
  └──────────────────────────────────────┘
  ↓
Admin hace clic en [Confirmar]
  ↓
FlutterFlow ejecuta:
  1. Actualizar documento en Firestore:

     servicios/SRV-20260303-001:
       - estado: "asignado" (cambio de "pendiente")
       - tecnicoId: "TECH001"
       - tecnicoNombre: "Juan Pérez"
       - tecnicoTelefono: "+52 987 654 3210"
       - asignadoAt: Timestamp.now()
       - updatedAt: Timestamp.now()

  2. Enviar notificación push a Juan (técnico)
  3. Enviar notificación push a María (cliente)
  ↓
Mensaje de éxito:
  "✅ Técnico asignado exitosamente"

┌─────────────────────────────────────────────────────────────────┐
│ PASO 4: TÉCNICO REALIZA EL SERVICIO                             │
└─────────────────────────────────────────────────────────────────┘
Juan (técnico) recibe notificación:
  🔔 "Nuevo servicio asignado: Plomería - $75.00"
  ↓
Juan abre la app
  ↓
Pantalla Home del Técnico:
  ┌──────────────────────────────────────┐
  │ Mis Servicios                        │
  │                                      │
  │ Filtros: [Asignados ▼] [Todos ▼]    │
  │                                      │
  │ ┌────────────────────────────────┐  │
  │ │ 🔴 URGENTE | NUEVO               │  │
  │ │ #SRV-20260303-001                │  │
  │ │ Plomería - Fuga en cocina        │  │
  │ │ Cliente: María González          │  │
  │ │ 📍 2.3 km de distancia            │  │
  │ │ 💰 $75.00                         │  │
  │ │ [Ver Detalle]                     │  │
  │ └────────────────────────────────┘  │
  └──────────────────────────────────────┘
  ↓
Juan hace clic en [Ver Detalle]
  ↓
Detalle del Servicio (Vista Técnico):
  ┌──────────────────────────────────────┐
  │ Servicio #SRV-20260303-001           │
  │ Estado: ASIGNADO 🔴 URGENTE          │
  │                                      │
  │ 👤 Cliente:                          │
  │ María González                       │
  │ +52 123 456 7890                     │
  │ [💬 WhatsApp] [💭 Chat]              │
  │                                      │
  │ 📝 Descripción:                      │
  │ Reparación de fuga en cocina         │
  │ Hay una fuga de agua...              │
  │                                      │
  │ 📷 Fotos:                            │
  │ [Ver fotos] (3)                      │
  │                                      │
  │ 📍 Ubicación:                        │
  │ Calle 5 #123, Col. Centro, CDMX     │
  │ [🗺️ Ver ruta en Google Maps]        │
  │                                      │
  │ 💰 Estimación: $75.00                │
  │                                      │
  │ ─────────────────────────────────    │
  │                                      │
  │ [Iniciar Servicio]                   │
  └──────────────────────────────────────┘
  ↓
Juan toca [💬 WhatsApp]
  ↓
WhatsApp se abre con mensaje pre-escrito:

  Para: +52 123 456 7890 (María González)

  Mensaje:
  "Hola María, soy Juan Pérez, técnico de [TuPlataforma].

  Me han asignado tu solicitud #SRV-20260303-001 de plomería
  (Reparación de fuga en cocina).

  ¿Cuándo sería un buen momento para visitarte y revisar
  el problema?

  Gracias."

  [Enviar]
  ↓
Juan envía el mensaje y coordina con María
María responde: "Hola Juan, ¿puedes venir hoy a las 3pm?"
Juan confirma: "Perfecto, estaré ahí a las 3pm"
  ↓
Juan sale hacia la dirección de María
  ↓
Juan toca [Iniciar Servicio]
  ↓
FlutterFlow ejecuta:
  1. Actualizar documento en Firestore:

     servicios/SRV-20260303-001:
       - estado: "en_progreso"
       - enProgresoAt: Timestamp.now()
       - updatedAt: Timestamp.now()

  2. Enviar notificación a María:
     "Juan está en camino a tu ubicación"
  ↓
Juan llega, repara la fuga (1 hora de trabajo)
  ↓
Juan abre la app y toca [Completar Servicio]
  ↓
Modal de confirmación:
  ┌──────────────────────────────────────┐
  │ ✅ Completar Servicio                │
  │                                      │
  │ ¿El servicio fue completado          │
  │ satisfactoriamente?                  │
  │                                      │
  │ Costo final (opcional):              │
  │ [$75.00_______]                      │
  │                                      │
  │ Notas (opcional):                    │
  │ [Se reparó la fuga y se revisó___]  │
  │ [la tubería completa___________]    │
  │                                      │
  │ [Cancelar]  [Completar]              │
  └──────────────────────────────────────┘
  ↓
Juan hace clic en [Completar]
  ↓
FlutterFlow ejecuta:
  1. Actualizar documento en Firestore:

     servicios/SRV-20260303-001:
       - estado: "completado" (en Fase 1)
       - estado: "pago_pendiente" (en Fase 2)
       - completadoAt: Timestamp.now()
       - costoFinal: 75.00
       - updatedAt: Timestamp.now()

  2. Enviar notificación a María:
     "Tu servicio ha sido completado"
     (Fase 2: "Procede a realizar el pago de $75.00")

  3. Enviar notificación a Admin:
     "Servicio #SRV-20260303-001 completado"

┌─────────────────────────────────────────────────────────────────┐
│ PASO 5: CLIENTE PAGA (SOLO FASE 2)                              │
└─────────────────────────────────────────────────────────────────┘
María recibe notificación:
  🔔 "Tu servicio está completado. Paga $75.00"
  ↓
María abre la app
  ↓
Pantalla: Detalle del Servicio
  ┌──────────────────────────────────────┐
  │ Servicio #SRV-20260303-001           │
  │ Estado: PAGO PENDIENTE 💳            │
  │                                      │
  │ Técnico: Juan Pérez                  │
  │ Completado: 3 Mar 2026, 4:30pm       │
  │                                      │
  │ ─────────────────────────────────    │
  │ Monto a pagar: $75.00                │
  │                                      │
  │ [Pagar Ahora]                        │
  └──────────────────────────────────────┘
  ↓
María toca [Pagar Ahora]
  ↓
Pantalla de Pago (Stripe Elements):
  ┌──────────────────────────────────────┐
  │ 💳 Pago Seguro                       │
  │                                      │
  │ Resumen:                             │
  │ Plomería - Reparación de fuga        │
  │ Técnico: Juan Pérez                  │
  │                                      │
  │ ─────────────────────────────────    │
  │ Subtotal:           $75.00           │
  │ ─────────────────────────────────    │
  │ TOTAL A PAGAR:      $75.00           │
  │                                      │
  │ Método de pago:                      │
  │ [💳 Tarjeta de crédito/débito]       │
  │                                      │
  │ Número de tarjeta:                   │
  │ [4242 4242 4242 4242_____________]  │
  │                                      │
  │ Expira:          CVV:                │
  │ [12/25____]      [123__]             │
  │                                      │
  │ Nombre en la tarjeta:                │
  │ [Maria Gonzalez_________________]   │
  │                                      │
  │ 🔒 Pago seguro procesado por Stripe  │
  │                                      │
  │ [Confirmar Pago]                     │
  └──────────────────────────────────────┘
  ↓
María llena los datos y toca [Confirmar Pago]
  ↓
FlutterFlow ejecuta Cloud Function:

  1. Llamar a createPaymentIntent({
       servicioId: "SRV-20260303-001",
       monto: 75.00,
       clienteId: "CLIENT001"
     })

  2. Cloud Function hace:
     - Crear PaymentIntent en Stripe API
     - Retornar clientSecret al frontend

  3. Frontend confirma pago con Stripe Elements

  4. Stripe procesa el pago (2-3 segundos)
  ↓
Pantalla de carga:
  "⏳ Procesando pago..."
  ↓
✅ Pago exitoso
  ↓
Webhook de Stripe notifica a Cloud Function:

  Evento: payment_intent.succeeded
  Data: {
    id: "pi_3LqYzT2eZvKYlo2C0x7hqk9l",
    amount: 7500, // centavos
    status: "succeeded"
  }
  ↓
Cloud Function handleStripeWebhook ejecuta:

  1. Calcular comisiones:
     comisionPlataforma = 75.00 × 0.15 = 11.25
     comisionStripe = (75.00 × 0.029) + 0.30 = 2.48
     montoTecnico = 75.00 - 11.25 - 2.48 = 61.27

  2. Actualizar servicio:
     servicios/SRV-20260303-001:
       - estado: "pagado"
       - estadoPago: "completado"
       - montoPagado: 75.00
       - comisionPlataforma: 11.25
       - comisionStripe: 2.48
       - montoTecnico: 61.27
       - stripePaymentIntentId: "pi_3Lq..."
       - pagadoAt: Timestamp.now()

  3. Crear transacción:
     transacciones/{nuevoId}:
       - servicioId: "SRV-20260303-001"
       - clienteId: "CLIENT001"
       - tecnicoId: "TECH001"
       - montoTotal: 75.00
       - comisionPlataforma: 11.25
       - comisionStripe: 2.48
       - montoTecnico: 61.27
       - estado: "completado"
       - [... demás campos]

  4. Enviar notificación a Juan:
     "✅ Pago recibido: $61.27 por servicio #SRV-20260303-001"

  5. Enviar notificación a Admin:
     "💰 Comisión ganada: $11.25 de servicio #SRV-20260303-001"
  ↓
María ve pantalla de confirmación:
  ┌──────────────────────────────────────┐
  │ ✅ Pago Completado                   │
  │                                      │
  │ Recibo #TRX-20260303-001             │
  │ Monto: $75.00                        │
  │ Fecha: 3 Mar 2026, 4:50pm            │
  │                                      │
  │ Gracias por usar [TuPlataforma]      │
  │                                      │
  │ [Ver Recibo]  [Cerrar]               │
  └──────────────────────────────────────┘

```

**FIN DEL FLUJO COMPLETO**

---

<a name="sistema-de-costos"></a>
## 7. SISTEMA DE COSTOS Y COMISIONES

### 7.1 Tarifas Propuestas

| Categoría | Tarifa Base | Urgente (1.5x) | Recargo/km | Tiempo Promedio |
|-----------|-------------|----------------|------------|-----------------|
| **Electricidad** | $75.00 | $112.50 | $2.50 | 2-3 horas |
| **Plomería** | $50.00 | $75.00 | $2.50 | 1-2 horas |
| **Limpieza** | $40.00 | $60.00 | $1.50 | 2-4 horas |
| **Refrigeración** | $90.00 | $135.00 | $3.00 | 2-3 horas |
| **Carpintería** | $60.00 | $90.00 | $2.00 | 3-4 horas |

**Notas:**
- Todas las tarifas son configurables desde el panel de administración
- Los precios son solo estimaciones; el costo final puede variar
- El técnico confirma el costo final después de evaluar el problema

### 7.2 Ejemplos de Cálculo de Estimación

#### Ejemplo 1: Plomería Normal Cercana
```
Categoría: Plomería
Urgencia: Normal
Distancia: 5 km

Cálculo:
Tarifa base:              $50.00
Multiplicador normal:     ×1.0
Subtotal:                 $50.00
Recargo distancia:        $0.00 (dentro de 10km)
Recargo nocturno:         $0.00

ESTIMACIÓN TOTAL:         $50.00
```

#### Ejemplo 2: Electricidad Urgente Lejana
```
Categoría: Electricidad
Urgencia: Urgente
Distancia: 18 km

Cálculo:
Tarifa base:              $75.00
Multiplicador urgente:    ×1.5
Subtotal:                 $112.50
Recargo distancia:        (18-10) × $2.50 = $20.00
Recargo nocturno:         $0.00

ESTIMACIÓN TOTAL:         $132.50
```

#### Ejemplo 3: Refrigeración Urgente Noche
```
Categoría: Refrigeración
Urgencia: Urgente
Distancia: 8 km
Hora: 11:00 PM (horario nocturno)

Cálculo:
Tarifa base:              $90.00
Multiplicador urgente:    ×1.5
Subtotal:                 $135.00
Recargo distancia:        $0.00
Recargo nocturno:         $135.00 × 0.3 = $40.50

ESTIMACIÓN TOTAL:         $175.50
```

### 7.3 Desglose de Comisiones (Fase 2)

#### Ejemplo: Pago de $100

```
┌──────────────────────────────────────────────────────────┐
│ DESGLOSE DE PAGO: $100.00                                │
├──────────────────────────────────────────────────────────┤
│                                                          │
│ Cliente paga:                          $100.00           │
│                                                          │
│ ─────────────────────────────────────────────────────    │
│                                                          │
│ Comisión Plataforma (15%):             -$15.00           │
│                                                          │
│ Comisión Stripe (2.9% + $0.30):       -$3.20            │
│                                                          │
│ ═════════════════════════════════════════════════════    │
│                                                          │
│ Técnico recibe:                        $81.80            │
│                                                          │
│ TÚ ganas:                              $15.00            │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

#### Tabla de Comisiones por Monto

| Cliente Paga | Comisión Plataforma (15%) | Comisión Stripe | Técnico Recibe | TU Ganas |
|--------------|---------------------------|-----------------|----------------|----------|
| $25.00 | $3.75 | $1.03 | $20.22 | $3.75 |
| $50.00 | $7.50 | $1.75 | $40.75 | $7.50 |
| $75.00 | $11.25 | $2.48 | $61.27 | $11.25 |
| $100.00 | $15.00 | $3.20 | $81.80 | $15.00 |
| $150.00 | $22.50 | $4.65 | $122.85 | $22.50 |
| $200.00 | $30.00 | $6.10 | $163.90 | $30.00 |
| $300.00 | $45.00 | $8.40 | $246.60 | $45.00 |

### 7.4 Proyección de Ingresos

#### Escenario Conservador

Asumiendo:
- 20 servicios/mes al iniciar
- Ticket promedio: $100
- Crecimiento: +50% mensual

| Mes | Servicios | Ingresos Brutos | Tu Comisión (15%) | Costos Firebase | Ingreso Neto |
|-----|-----------|-----------------|-------------------|-----------------|--------------|
| 1 | 20 | $2,000 | $300 | $10 | **$290** |
| 2 | 30 | $3,000 | $450 | $15 | **$435** |
| 3 | 45 | $4,500 | $675 | $20 | **$655** |
| 4 | 68 | $6,750 | $1,013 | $30 | **$983** |
| 5 | 102 | $10,125 | $1,519 | $45 | **$1,474** |
| 6 | 153 | $15,188 | $2,278 | $70 | **$2,208** |

**ROI:** Recuperas la inversión de $3,000 entre el mes 3 y 4.

#### Escenario Optimista

Asumiendo:
- 50 servicios/mes al iniciar
- Ticket promedio: $100
- Crecimiento: +100% mensual

| Mes | Servicios | Ingresos Brutos | Tu Comisión (15%) | Costos Firebase | Ingreso Neto |
|-----|-----------|-----------------|-------------------|-----------------|--------------|
| 1 | 50 | $5,000 | $750 | $25 | **$725** |
| 2 | 100 | $10,000 | $1,500 | $50 | **$1,450** |
| 3 | 200 | $20,000 | $3,000 | $100 | **$2,900** |
| 4 | 400 | $40,000 | $6,000 | $200 | **$5,800** |
| 5 | 800 | $80,000 | $12,000 | $400 | **$11,600** |
| 6 | 1,600 | $160,000 | $24,000 | $800 | **$23,200** |

**ROI:** Recuperas la inversión en menos de 1 mes.

---

<a name="accesos-necesarios"></a>
## 8. ACCESOS NECESARIOS

Para iniciar el desarrollo del Hito 1, necesito los siguientes accesos:

### 8.1 Firebase (CRÍTICO - Día 1)

#### Pasos para crear el proyecto:

1. Ve a https://console.firebase.google.com
2. Haz clic en "Agregar proyecto" o "Add project"
3. **Nombre del proyecto:**
   - Sugerencia: `servicios-domicilio-mvp`
   - O el nombre que prefieras
4. Acepta los términos y condiciones
5. Haz clic en "Crear proyecto"
6. Espera a que el proyecto se cree (30-60 segundos)

#### Darme acceso:

7. Una vez creado, ve a:
   - ⚙️ **Configuración del proyecto** (icono de engranaje arriba a la izquierda)
   - Pestaña **"Usuarios y permisos"**
8. Haz clic en **"Agregar miembro"**
9. Ingresa mi email: **aupwork00@gmail.com**
10. Selecciona el rol: **"Editor"**
11. Haz clic en **"Agregar"**

#### Habilitar Billing:

12. Ve a la sección **"Uso y facturación"** en el menú lateral
13. Haz clic en **"Actualizar plan"**
14. Selecciona el plan **"Blaze (pago por uso)"**
15. Vincula una tarjeta de crédito

**IMPORTANTE:**
- Firebase tiene un tier gratuito generoso
- No se cobrará nada hasta superar:
  - 50,000 lecturas/día de Firestore
  - 20,000 escrituras/día de Firestore
  - 1 GB de almacenamiento
  - 10 GB de transferencia/mes
- Para los primeros 2-3 meses, el costo será $0-30/mes máximo
- Configuraré alertas de billing para avisarte si se acerca a un límite

**Tiempo estimado:** 10-15 minutos

---

### 8.2 Google Cloud Platform - APIs de Maps (CRÍTICO - Día 1-2)

#### Pasos:

1. Ve a https://console.cloud.google.com
2. En el selector de proyectos (arriba a la izquierda), selecciona el proyecto de Firebase que acabas de crear
   - Debe aparecer como: `servicios-domicilio-mvp`
3. En el menú lateral (☰), ve a:
   **"APIs y servicios"** → **"Biblioteca"**

#### Habilitar APIs:

4. Busca y habilita estas 3 APIs:

   **a) Maps JavaScript API**
   - Busca: "Maps JavaScript API"
   - Haz clic en ella
   - Haz clic en **"Habilitar"**

   **b) Geocoding API**
   - Busca: "Geocoding API"
   - Haz clic en ella
   - Haz clic en **"Habilitar"**

   **c) Places API** (opcional, para autocompletado)
   - Busca: "Places API"
   - Haz clic en ella
   - Haz clic en **"Habilitar"**

#### Crear API Key:

5. Ve a **"APIs y servicios"** → **"Credenciales"**
6. Haz clic en **"Crear credenciales"** → **"Clave de API"**
7. Se generará una API Key (algo como: `AIzaSyC3xxxxxxxxxxxxxxxxxxxxxxxxxxx`)
8. **¡IMPORTANTE! Restringe la API Key inmediatamente:**

   a) Haz clic en el nombre de la API Key recién creada

   b) En **"Restricciones de aplicación"**, selecciona:
      - [x] **"Sitios web"** (para el panel admin web)
      - Agrega: `https://*.flutterflow.io/*`
      - Agrega: `http://localhost:*` (para pruebas locales)

   c) En **"Restricciones de API"**, selecciona:
      - [x] **"Restringir clave"**
      - Marca solo las 3 APIs que habilitaste:
        - Maps JavaScript API
        - Geocoding API
        - Places API

   d) Haz clic en **"Guardar"**

9. **Compárteme la API Key por mensaje privado** (email o WhatsApp)
   - NO la compartas en lugares públicos
   - Yo la configuraré en FlutterFlow de forma segura

**Créditos gratuitos:**
- Google da $200/mes de crédito gratuito para Google Maps Platform
- Con eso cubres aproximadamente:
  - 28,000 cargas de mapa estático
  - 40,000 solicitudes de geocodificación
- Para el MVP (primeros meses) será suficiente

**Tiempo estimado:** 10-15 minutos

---

### 8.3 FlutterFlow (IMPORTANTE - Día 1-2)

Tienes 2 opciones:

#### **OPCIÓN A: Desarrollo en tu cuenta (RECOMENDADO)**

**Ventajas:**
- ✅ Ves el progreso en tiempo real
- ✅ Tienes control total desde el inicio
- ✅ No hay proceso de transferencia al final
- ✅ Puedes hacer comentarios durante el desarrollo

**Desventajas:**
- ⚠️ Necesitas suscripción Pro de FlutterFlow ($30/mes)
- ⚠️ Inversión adicional: $60 (2 meses de desarrollo)

**Pasos:**

1. Ve a https://app.flutterflow.io
2. Crea una cuenta con tu email
3. Verifica tu email
4. Ve a **"Settings"** → **"Billing"**
5. Suscríbete al plan **"Pro"** ($30/mes)
6. Una vez suscrito, ve a **"Settings"** → **"Team"**
7. Haz clic en **"Invite Team Member"**
8. Ingresa mi email: **aupwork00@gmail.com**
9. Selecciona permisos: **"Editor"**
10. Haz clic en **"Send Invite"**

**Tiempo estimado:** 10 minutos
**Costo adicional:** $30/mes (cancelable después de entregar el proyecto)

---

#### **OPCIÓN B: Desarrollo en mi cuenta**

**Ventajas:**
- ✅ No necesitas pagar suscripción de FlutterFlow durante desarrollo
- ✅ Yo pago los $30/mes

**Desventajas:**
- ⚠️ No ves el progreso en tiempo real (solo en demos semanales)
- ⚠️ Al final hay proceso de transferencia (1-2 días)

**Pasos:**

Ninguno. Yo crearé el proyecto en mi cuenta y lo transferiré al final.

**Tiempo estimado:** 0 minutos para ti
**Costo adicional:** $0

---

**MI RECOMENDACIÓN:** **OPCIÓN A**

Invertir $60 adicionales ($30 × 2 meses) vale la pena por:
- Total transparencia del desarrollo
- Control desde el inicio
- Sin riesgo de problemas en la transferencia
- Puedes hacer ajustes visuales tú mismo después

---

### 8.4 Stripe (NO URGENTE - Fase 2)

Esto es para la Fase 2 (Semana 4), pero recomiendo crearlo desde ahora para evitar retrasos:

#### Pasos:

1. Ve a https://stripe.com
2. Haz clic en **"Sign in"** o **"Get started"**
3. Crea una cuenta con tu email
4. Completa el formulario de registro:
   - Nombre del negocio
   - País (México, USA, etc.)
   - Tipo de negocio
5. Verifica tu email
6. Completa el proceso de verificación de identidad:
   - Stripe pedirá:
     - ID oficial (INE, pasaporte)
     - RFC o Tax ID
     - Información bancaria (para recibir pagos)
7. **IMPORTANTE:** Mantén la cuenta en modo **"Test"**
   - No actives el modo "Live" hasta que la Fase 2 esté completa y probada

#### Configuración inicial:

8. Ve a **"Developers"** → **"API keys"**
9. Verás 2 tipos de keys:
   - **Publishable key** (pk_test_...)
   - **Secret key** (sk_test_...)
10. **NO me compartas las keys aún**
    - Te las pediré en la Fase 2 (Semana 4)
    - Por ahora, solo ten la cuenta lista

**Costos de Stripe:**
- $0 de costo mensual
- Solo cobra por transacción exitosa:
  - **2.9% + $0.30 USD** por pago con tarjeta
  - Ejemplo: En un pago de $100, Stripe cobra $3.20

**Tiempo estimado:** 15-20 minutos
**Costo:** $0 (solo comisiones por transacción)

---

### 8.5 Comunicación (URGENTE - HOY)

Para coordinación eficiente necesito:

**1. WhatsApp:**
- ¿Cuál es tu número de WhatsApp?
- Lo usaré para:
  - Updates rápidos
  - Compartir screenshots/videos
  - Urgencias

**2. Email secundario:**
- (En caso de problemas con Workana)

**3. Zona horaria:**
- ¿En qué zona horaria estás?
- Para coordinar demos en vivo

**4. Disponibilidad:**
- ¿Cuáles son tus horarios preferidos para calls/demos?
- Días: ¿Lunes a Viernes? ¿Fines de semana?
- Horario: ¿Mañanas, tardes, noches?

**Mi disponibilidad:**
- **Días:** Lunes a Viernes
- **Horario:** 9:00 AM - 6:00 PM (UTC-6 / Hora de México)
- **Respuestas:** Máximo 24-48 horas hábiles
- **Updates:** Cada 2-3 días (con screenshots/videos)
- **Emergencias:** WhatsApp (respuesta en < 4 horas)

---

### 8.6 Resumen de Accesos

| Acceso | Urgencia | Tiempo | Costo | Email para invitar |
|--------|----------|--------|-------|-------------------|
| **Firebase** | 🔴 CRÍTICO | 15 min | $0-30/mes | aupwork00@gmail.com |
| **Google Maps API** | 🔴 CRÍTICO | 15 min | $0/mes | (Compartir API Key) |
| **FlutterFlow Opción A** | 🟡 Recomendado | 10 min | $30/mes | aupwork00@gmail.com |
| **FlutterFlow Opción B** | 🟢 Alternativa | 0 min | $0 | (No necesario) |
| **Stripe** | 🟢 Fase 2 | 20 min | $0 | (No necesario aún) |
| **WhatsApp** | 🔴 HOY | 1 min | $0 | (Compartir número) |

---

## 📞 INFORMACIÓN DE CONTACTO

**Email:** aupwork00@gmail.com
**WhatsApp:** [Compartir después de recibir el tuyo]
**Workana:** [Perfil de Workana]
**Disponibilidad:** Lun-Vie 9:00 AM - 6:00 PM (UTC-6)
**Tiempo de respuesta:** Máximo 24-48 horas hábiles

---

## 🎯 RESUMEN EJECUTIVO FINAL

### Lo que este documento contiene:

✅ **Modelo de datos completo** de Firestore con todos los campos y tipos
✅ **Estructura inicial** de las 4 colecciones principales
✅ **Reglas de seguridad** completas (código listo para implementar)
✅ **Arquitectura técnica** escalable para Fase 2
✅ **Flujos de usuario** detallados paso a paso
✅ **Sistema de costos** con ejemplos y fórmulas
✅ **Accesos necesarios** con instrucciones paso a paso
✅ **Cronograma del Hito 1** día por día
✅ **Criterios de aceptación** claros para liberar pago
✅ **Próximos pasos** inmediatos

### Lo que vamos a construir:

🎯 App móvil de marketplace (iOS + Android)
🎯 3 roles: Cliente, Técnico, Administrador
🎯 Pagos integrados con Stripe (Fase 2)
🎯 Sistema de comisiones automáticas (15%)
🎯 Panel de administración completo

### Inversión:

💰 **Presupuesto:** $3,000 USD
⏱️ **Duración:** 6 semanas
📊 **Hitos:** 7 entregables verificables
🚀 **ROI esperado:** 3-4 meses

### Próximo paso:

📋 Tú apruebas este documento y creas los accesos
🚀 Yo inicio desarrollo del Hito 1 inmediatamente
📅 Entrega en 7 días con demo funcional

---

**¿Listo para empezar?**

Responde confirmando:
1. Arquitectura aprobada
2. Accesos creados (o fecha estimada)
3. Opción de FlutterFlow elegida
4. Tu WhatsApp para coordinación

En cuanto tenga tu confirmación y los accesos, ¡comenzamos!

---

_Documento generado: 3 de marzo de 2026_
_Para: Edgar Daniel Godoy Montalvo_
_Desarrollador: aupwork00@gmail.com_
_Proyecto: MVP App de Servicios a Domicilio_
_Presupuesto: $3,000 USD | Duración: 6 semanas_

---

**FIN DEL DOCUMENTO**
