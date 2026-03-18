# ANÁLISIS TÉCNICO DEL PROYECTO
## App de Servicios Técnicos a Domicilio - MVP

**Cliente:** Edgar Daniel Godoy Montalvo
**Desarrollador:** JunJun Mabod
**Presupuesto Total:** USD $3,000
**Duración:** 6 semanas
**Fecha de análisis:** 3 de marzo de 2026

---

## 📊 RESUMEN EJECUTIVO

El cliente busca desarrollar una aplicación móvil MVP (Producto Mínimo Viable) para conectar clientes con técnicos de servicios a domicilio. El proyecto está dividido en 2 fases principales con 7 hitos verificables, utilizando FlutterFlow y Firebase como stack tecnológico.

**Objetivo principal:** Lanzar un MVP funcional que permita validar el modelo de negocio, con una arquitectura escalable que evite reestructuraciones costosas en fases futuras.

---

## 🎯 CONTEXTO DEL PROYECTO

### Tipo de Aplicación
Marketplace de servicios a dos caras (two-sided marketplace):
- **Lado demanda:** Clientes que solicitan servicios técnicos
- **Lado oferta:** Técnicos que realizan los servicios
- **Facilitador:** Administrador que gestiona y asigna servicios

### Modelo de Negocio
- Comisión por transacción (15% configurable)
- Pago dentro de la plataforma
- **Modelo híbrido de asignación:**
  - Cliente puede seleccionar técnico manualmente (por rating, precio, especialidad, disponibilidad)
  - Si el cliente no selecciona, el sistema asigna automáticamente al mejor técnico disponible
  - Admin puede asignar manualmente como fallback

### Usuarios del Sistema
1. **Clientes:** Crean solicitudes de servicio, suben fotos, reciben estimaciones, pagan
2. **Técnicos:** Reciben asignaciones, visualizan servicios, se comunican con clientes
3. **Administrador (Edgar):** Gestiona solicitudes, asigna técnicos, configura tarifas

---

## 🔧 STACK TECNOLÓGICO ACORDADO

### Frontend
**FlutterFlow** (Low-code + Flutter nativo)

**Justificación:**
- ✅ Desarrollo visual rápido (60-70% más rápido que código puro)
- ✅ Genera código Flutter nativo exportable
- ✅ Cross-platform real (iOS + Android con una sola base)
- ✅ Integración nativa con Firebase
- ✅ Widgets preconstruidos para mapas, autenticación, chat
- ✅ Permite código personalizado Flutter cuando se necesite
- ✅ Hot reload y preview en tiempo real

**Limitaciones consideradas:**
- ⚠️ Complejidad limitada en lógica de negocio muy avanzada
- ⚠️ Dependencia de la plataforma FlutterFlow
- ⚠️ Curva de aprendizaje para modificaciones futuras

### Backend
**Firebase Suite**

**Componentes utilizados:**

1. **Firebase Authentication**
   - Login con email/password
   - Gestión de roles (cliente/técnico/admin)
   - Tokens JWT automáticos

2. **Cloud Firestore**
   - Base de datos NoSQL en tiempo real
   - Escalabilidad automática
   - Queries con índices compuestos

3. **Firebase Storage**
   - Almacenamiento de fotos de servicios
   - URLs seguras con tokens
   - Compresión automática

4. **Cloud Functions** (Fase 2)
   - Webhooks de Stripe
   - Cálculos backend de comisiones
   - Envío de notificaciones

### Servicios Terceros

1. **Google Maps Platform**
   - Maps JavaScript API
   - Geocoding API
   - Geolocation API

2. **Stripe** (Fase 2)
   - Payment Intents
   - Webhooks
   - Preparación para Stripe Connect (split payments)

3. **WhatsApp Business API**
   - Deep links con contexto
   - Mensajes prellenados

---

## 📐 ARQUITECTURA DE DATOS

### Modelo de Datos Firestore

```
📦 Firestore Database
│
├── 👥 users/
│   └── {userId}
│       ├── email: string
│       ├── nombre: string
│       ├── apellido: string
│       ├── telefono: string
│       ├── rol: string ["cliente" | "tecnico" | "admin"]
│       ├── fotoPerfil: string (URL)
│       ├── activo: boolean
│       ├── createdAt: timestamp
│       ├── ubicacionDefecto: geopoint (opcional)
│       │
│       ├── // Campos exclusivos para técnicos (rol == "tecnico")
│       ├── especialidades: array<string> ["electricidad", "plomeria", "limpieza", ...]
│       ├── calificacionPromedio: number (1.0 - 5.0, default 0)
│       ├── totalResenas: number (default 0)
│       ├── tarifasPorEspecialidad: map
│       │     ├── electricidad: number (ej: 50)
│       │     ├── plomeria: number (ej: 60)
│       │     └── ...
│       ├── disponible: boolean (default true)
│       ├── horarioDisponible: map
│       │     ├── lunes: { inicio: "08:00", fin: "18:00" }
│       │     ├── martes: { inicio: "08:00", fin: "18:00" }
│       │     └── ...
│       ├── serviciosCompletados: number (default 0)
│       └── ultimaAsignacion: timestamp (nullable)
│
├── 🛠️ servicios/
│   └── {servicioId}
│       ├── clienteId: reference → users/{userId}
│       ├── clienteNombre: string (denormalizado)
│       ├── clienteTelefono: string (denormalizado)
│       │
│       ├── tecnicoId: reference → users/{userId} (nullable)
│       ├── tecnicoNombre: string (nullable)
│       │
│       ├── titulo: string
│       ├── descripcion: string
│       ├── categoria: string ["electricidad" | "plomeria" | "limpieza" | ...]
│       ├── urgencia: string ["normal" | "urgente"]
│       │
│       ├── ubicacion: geopoint
│       ├── ubicacionTexto: string (dirección formateada)
│       ├── geohash: string (para búsquedas por proximidad)
│       │
│       ├── fotos: array<string> (URLs de Storage)
│       │
│       ├── estado: string
│       │   ["pendiente" | "asignado" | "en_progreso" |
│       │    "completado" | "cancelado" | "pago_pendiente" | "pagado"]
│       │
│       ├── // Modelo híbrido de asignación
│       ├── tipoAsignacion: string ["cliente" | "automatica" | "admin"]
│       ├── seleccionadoPorCliente: boolean (default false)
│       │
│       ├── estimacionCosto: number
│       ├── costoFinal: number (nullable)
│       │
│       ├── createdAt: timestamp
│       ├── updatedAt: timestamp
│       ├── asignadoAt: timestamp (nullable)
│       ├── completadoAt: timestamp (nullable)
│       │
│       ├── // Campos preparados para Fase 2
│       ├── montoPagado: number (nullable)
│       ├── comisionPlataforma: number (nullable)
│       ├── montoTecnico: number (nullable)
│       ├── estadoPago: string (nullable)
│       ├── stripePaymentIntentId: string (nullable)
│       ├── stripePaymentStatus: string (nullable)
│       │
│       └── 💬 mensajes/ (subcollection)
│           └── {mensajeId}
│               ├── userId: reference → users/{userId}
│               ├── nombreUsuario: string
│               ├── mensaje: string
│               ├── timestamp: timestamp
│               ├── leido: boolean
│               └── tipo: string ["texto" | "sistema"]
│
├── ⭐ resenas/
│   └── {resenaId}
│       ├── servicioId: reference → servicios/{servicioId}
│       ├── clienteId: reference → users/{userId}
│       ├── tecnicoId: reference → users/{userId}
│       ├── calificacion: number (1 - 5)
│       ├── comentario: string
│       ├── createdAt: timestamp
│       └── updatedAt: timestamp
│
├── ⚙️ configuracion/
│   ├── tarifas/
│   │   └── categorias: map
│   │       ├── electricidad:
│   │       │   ├── tarifaBase: 50
│   │       │   ├── multiplicadores:
│   │       │   │   ├── normal: 1.0
│   │       │   │   └── urgente: 1.5
│   │       │   └── recargoPorKm: 2.0
│   │       ├── plomeria: {...}
│   │       └── ...
│   │
│   ├── comisiones/
│   │   ├── porcentajePlataforma: 15
│   │   └── porcentajeStripe: 2.9
│   │
│   └── parametros/
│       ├── distanciaBaseKm: 10
│       ├── horaInicioRecargo: 22
│       └── horaFinRecargo: 6
│
└── 💰 transacciones/ (Fase 2)
    └── {transaccionId}
        ├── servicioId: reference → servicios/{servicioId}
        ├── clienteId: reference → users/{userId}
        ├── tecnicoId: reference → users/{userId}
        │
        ├── montoTotal: number
        ├── comisionPlataforma: number
        ├── comisionStripe: number
        ├── montoTecnico: number
        │
        ├── stripePaymentIntentId: string
        ├── stripeChargeId: string
        ├── estado: string ["pendiente" | "completado" | "fallido" | "reembolsado"]
        │
        ├── createdAt: timestamp
        ├── completedAt: timestamp (nullable)
        │
        └── metadata: map
            ├── metodoPago: string
            ├── ultimos4Digitos: string
            └── marcaTarjeta: string
```

### Índices Compuestos Necesarios

```javascript
// Para queries eficientes
users (técnicos):
  - [rol, disponible, especialidades] // Buscar técnicos disponibles por especialidad
  - [rol, calificacionPromedio] (desc) // Listar técnicos por rating
  - [rol, disponible, calificacionPromedio] (desc) // Técnicos disponibles ordenados por rating

servicios:
  - [estado, createdAt] (desc)
  - [tecnicoId, estado, createdAt] (desc)
  - [clienteId, createdAt] (desc)
  - [categoria, estado, createdAt] (desc)
  - [geohash, estado] // Para búsquedas por proximidad
  - [estado, tipoAsignacion, createdAt] (desc) // Filtrar por tipo de asignación

resenas:
  - [tecnicoId, createdAt] (desc) // Reseñas de un técnico
  - [clienteId, createdAt] (desc) // Reseñas de un cliente
  - [servicioId] // Reseña de un servicio específico

transacciones:
  - [estado, createdAt] (desc)
  - [tecnicoId, createdAt] (desc)
```

### Estrategia de GeoHash para Búsquedas Geográficas

Firestore no soporta índices geoespaciales nativos, por lo que usamos GeoHash:

```dart
// Ejemplo de implementación
import 'package:geoflutterfire2/geoflutterfire2.dart';

GeoFlutterFire geo = GeoFlutterFire();

// Al crear servicio
GeoFirePoint ubicacionGeo = geo.point(
  latitude: ubicacion.latitude,
  longitude: ubicacion.longitude
);

// Query para buscar servicios cercanos (radio 10km)
Stream<List<DocumentSnapshot>> stream = geo.collection(
  collectionRef: FirebaseFirestore.instance.collection('servicios')
)
.within(
  center: ubicacionGeo,
  radius: 10,
  field: 'ubicacion',
  strictMode: true
);
```

---

## 🔒 SEGURIDAD Y REGLAS DE FIRESTORE

### Principios de Seguridad

1. **Autenticación obligatoria:** Ningún acceso sin login
2. **Autorización por roles:** Cada rol ve solo sus datos
3. **Validación de escritura:** Campos requeridos, tipos correctos
4. **No trust client:** Toda lógica crítica en backend
5. **Denormalización segura:** Datos sensibles solo donde necesario

### Reglas de Seguridad Implementadas

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // ===== FUNCIONES AUXILIARES =====

    function isAuthenticated() {
      return request.auth != null;
    }

    function getUserRole() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.rol;
    }

    function isAdmin() {
      return isAuthenticated() && getUserRole() == 'admin';
    }

    function isCliente() {
      return isAuthenticated() && getUserRole() == 'cliente';
    }

    function isTecnico() {
      return isAuthenticated() && getUserRole() == 'tecnico';
    }

    // ===== REGLAS PARA USUARIOS =====

    match /users/{userId} {
      // Lectura: propio perfil, admin, o clientes pueden ver perfiles de técnicos
      // (necesario para modelo híbrido - cliente selecciona técnico)
      allow read: if isAuthenticated() && (
        request.auth.uid == userId ||
        isAdmin() ||
        (isCliente() && resource.data.rol == 'tecnico' && resource.data.activo == true)
      );

      // Listar: clientes pueden buscar técnicos disponibles por especialidad/rating
      allow list: if isAuthenticated() && (
        isAdmin() ||
        isCliente()
      );

      // Creación: cualquier usuario autenticado (para registro)
      allow create: if isAuthenticated();

      // Actualización: propio perfil o admin (no se permite cambiar rol)
      allow update: if isAuthenticated() && (
        request.auth.uid == userId || isAdmin()
      ) && !request.resource.data.diff(resource.data).affectedKeys().hasAny(['rol']);

      // Eliminación: solo admin
      allow delete: if isAdmin();
    }

    // ===== REGLAS PARA SERVICIOS =====

    match /servicios/{servicioId} {
      // Lectura: admin, cliente dueño o técnico asignado
      allow read: if isAuthenticated() && (
        isAdmin() ||
        (isCliente() && resource.data.clienteId == request.auth.uid) ||
        (isTecnico() && resource.data.get('tecnicoId', null) == request.auth.uid)
      );

      // Creación: clientes o admin
      // Debe incluir tipoAsignacion para modelo híbrido
      allow create: if isAuthenticated() && (isCliente() || isAdmin()) &&
                      request.resource.data.estado == 'pendiente' &&
                      request.resource.data.tipoAsignacion in ['cliente', 'automatica', 'admin'];

      // Actualización:
      // - Admin puede todo
      // - Cliente puede actualizar sus servicios pendientes (incluyendo seleccionar técnico)
      // - Técnico solo puede actualizar estado de servicios asignados
      allow update: if isAuthenticated() && (
        isAdmin() ||
        (isCliente() &&
         resource.data.clienteId == request.auth.uid &&
         resource.data.estado == 'pendiente') ||
        (isTecnico() &&
         resource.data.get('tecnicoId', null) == request.auth.uid &&
         request.resource.data.diff(resource.data).affectedKeys().hasOnly(['estado', 'updatedAt']))
      );

      // Eliminación: solo admin
      allow delete: if isAdmin();

      // ===== SUBCOLLECTION MENSAJES =====

      match /mensajes/{mensajeId} {
        allow read: if isAuthenticated() && (
          isAdmin() ||
          get(/databases/$(database)/documents/servicios/$(servicioId)).data.clienteId == request.auth.uid ||
          get(/databases/$(database)/documents/servicios/$(servicioId)).data.get('tecnicoId', null) == request.auth.uid
        );

        allow create: if isAuthenticated() && (
          isAdmin() ||
          get(/databases/$(database)/documents/servicios/$(servicioId)).data.clienteId == request.auth.uid ||
          get(/databases/$(database)/documents/servicios/$(servicioId)).data.get('tecnicoId', null) == request.auth.uid
        ) && request.resource.data.userId == request.auth.uid;

        allow update: if isAuthenticated() &&
                        request.resource.data.diff(resource.data).affectedKeys().hasOnly(['leido']);
      }
    }

    // ===== REGLAS PARA RESEÑAS (MODELO HÍBRIDO) =====

    match /resenas/{resenaId} {
      // Lectura: cualquier usuario autenticado (para ver ratings de técnicos)
      allow read: if isAuthenticated();

      // Creación: solo clientes, para servicios completados
      allow create: if isAuthenticated() &&
                      isCliente() &&
                      request.resource.data.clienteId == request.auth.uid &&
                      request.resource.data.keys().hasAll(['servicioId', 'clienteId', 'tecnicoId', 'calificacion']) &&
                      request.resource.data.calificacion >= 1 &&
                      request.resource.data.calificacion <= 5;

      // Actualización: solo el cliente que la creó (editar comentario)
      allow update: if isAuthenticated() &&
                      resource.data.clienteId == request.auth.uid &&
                      !request.resource.data.diff(resource.data).affectedKeys().hasAny(['servicioId', 'clienteId', 'tecnicoId']);

      // Eliminación: solo admin
      allow delete: if isAdmin();
    }

    // ===== REGLAS PARA CONFIGURACIÓN =====

    match /configuracion/{document=**} {
      allow read: if isAuthenticated();
      allow write: if isAdmin();
    }

    // ===== REGLAS PARA TRANSACCIONES (FASE 2) =====

    match /transacciones/{transaccionId} {
      allow read: if isAuthenticated() && (
        isAdmin() ||
        resource.data.clienteId == request.auth.uid ||
        (isTecnico() && resource.data.tecnicoId == request.auth.uid)
      );

      allow create: if false; // Solo por Cloud Functions
      allow update: if false; // Solo por Cloud Functions
      allow delete: if isAdmin();
    }
  }
}
```

### Reglas de Storage para Fotos

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {

    // Fotos de perfil
    match /usuarios/{userId}/perfil/{fileName} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId &&
                     request.resource.size < 5 * 1024 * 1024 && // Max 5MB
                     request.resource.contentType.matches('image/.*');
    }

    // Fotos de servicios
    match /servicios/{servicioId}/{fileName} {
      allow read: if request.auth != null;

      allow write: if request.auth != null &&
                     request.resource.size < 10 * 1024 * 1024 && // Max 10MB
                     request.resource.contentType.matches('image/.*') &&
                     // Verificar que el usuario sea el cliente del servicio
                     firestore.get(/databases/(default)/documents/servicios/$(servicioId)).data.clienteId == request.auth.uid;
    }
  }
}
```

---

## 📱 FLUJOS DE USUARIO

### Flujo 1: Cliente Crea Solicitud de Servicio (MODELO HÍBRIDO)

```
1. Cliente se registra/inicia sesión
   ↓
2. Cliente toca "Solicitar Servicio"
   ↓
3. Selecciona categoría (electricidad, plomería, etc.)
   ↓
4. Ingresa título y descripción del problema
   ↓
5. Toma/sube fotos del problema (hasta 5 fotos)
   ↓
6. Captura ubicación automáticamente (con ajuste manual)
   ↓
7. Selecciona urgencia (normal/urgente)
   ↓
8. Sistema calcula estimación automática
   ↓
9. Sistema muestra técnicos disponibles para esa categoría
   │   (filtrados por: especialidad, disponibilidad, ubicación)
   │   (ordenados por: calificación, precio, distancia)
   ↓
10. Cliente tiene DOS OPCIONES:
    │
    ├── OPCIÓN A: Seleccionar técnico manualmente
    │   → Cliente elige técnico basándose en:
    │     • Calificación / estrellas
    │     • Precio / tarifa
    │     • Especialidad
    │     • Disponibilidad
    │   → tipoAsignacion = "cliente"
    │   → seleccionadoPorCliente = true
    │   → Estado: "asignado" (directo)
    │   → Técnico recibe notificación
    │
    └── OPCIÓN B: No seleccionar técnico
        → Cliente toca "Dejar que el sistema asigne"
        → tipoAsignacion = "automatica"
        → seleccionadoPorCliente = false
        → Estado: "pendiente"
        → Sistema asigna automáticamente al mejor técnico disponible
           (criterios: proximidad, calificación, carga de trabajo)
        → Si no hay técnico automático, admin asigna manualmente
```

### Flujo 2: Asignación de Técnico (3 VÍAS)

```
VÍA 1 - SELECCIÓN POR CLIENTE (tipoAsignacion = "cliente"):
  → El técnico ya fue asignado en el paso de creación
  → Estado pasa directamente a "asignado"
  → Técnico recibe notificación push

VÍA 2 - ASIGNACIÓN AUTOMÁTICA (tipoAsignacion = "automatica"):
  1. Sistema busca técnicos disponibles con la especialidad requerida
  2. Filtra por disponibilidad horaria y distancia
  3. Ordena por: calificación (desc) + distancia (asc) + carga (asc)
  4. Asigna al mejor candidato automáticamente
  5. Estado cambia a "asignado"
  6. Técnico recibe notificación push

VÍA 3 - ASIGNACIÓN MANUAL POR ADMIN (tipoAsignacion = "admin"):
  1. Admin ve lista de servicios pendientes en panel
  2. Abre detalle de servicio (fotos, ubicación, descripción)
  3. Ve técnicos disponibles con distancia al servicio
  4. Selecciona técnico y asigna
  5. Estado cambia a "asignado"
  6. Técnico recibe notificación push
  7. WhatsApp deep link disponible para contacto
```

### Flujo 3: Técnico Realiza Servicio

```
1. Técnico recibe notificación de asignación
   ↓
2. Ve detalles del servicio en app
   ↓
3. Ve ubicación en mapa con ruta
   ↓
4. Contacta cliente por WhatsApp o chat interno
   ↓
5. Cambia estado a "En Progreso"
   ↓
6. Realiza el servicio
   ↓
7. Cambia estado a "Completado"
   ↓
8. (Fase 2) Cliente paga dentro de la app
```

### Flujo 4: Sistema de Pagos (Fase 2)

```
1. Técnico marca servicio como "Completado"
   ↓
2. Estado cambia a "Pago Pendiente"
   ↓
3. Cliente recibe notificación para pagar
   ↓
4. Cliente ingresa datos de tarjeta (Stripe Elements)
   ↓
5. Backend crea PaymentIntent vía Cloud Function
   ↓
6. Stripe procesa pago
   ↓
7. Webhook notifica éxito/fallo
   ↓
8. Cloud Function calcula comisión (15%)
   ↓
9. Se registra transacción en Firestore
   ↓
10. Estado cambia a "Pagado"
   ↓
11. Técnico puede ver su balance
```

---

## 🗓️ PLAN DE IMPLEMENTACIÓN DETALLADO

### **FASE 1: MVP OPERATIVO**
**Duración:** 3 semanas
**Presupuesto:** $1,600
**Objetivo:** App funcional con gestión manual de servicios

---

#### **HITO 1: Arquitectura + Base Escalable**
**Semana 1 | Presupuesto: $300**

**📋 Tareas:**

1. **Documento Técnico de Arquitectura**
   - Modelo de datos completo Firestore
   - Diagrama de colecciones y relaciones
   - Definición de índices compuestos
   - Estrategia de GeoHash
   - Campos preparados para Fase 2

2. **Configuración Firebase**
   - Crear proyecto Firebase
   - Habilitar Authentication (email/password)
   - Crear base de datos Firestore
   - Habilitar Firebase Storage
   - Configurar reglas de seguridad iniciales

3. **Estructura de Firestore**
   - Crear colecciones: users, servicios, configuracion
   - Definir campos con tipos correctos
   - Implementar campos para roles
   - Preparar campos para pagos futuros
   - Crear colección de configuración de tarifas

4. **Reglas de Seguridad**
   - Implementar funciones auxiliares de roles
   - Reglas de lectura/escritura por colección
   - Reglas de Storage para fotos
   - Testing de reglas con Firebase Emulator

5. **Sistema de Autenticación**
   - Flujo de registro para clientes
   - Flujo de registro para técnicos (con aprobación admin)
   - Login con email/password
   - Asignación de roles en registro
   - Pantallas de bienvenida personalizadas por rol

**✅ Entregables:**
- ✓ Documento técnico en Google Docs/PDF (10-15 páginas)
- ✓ Proyecto Firebase configurado con acceso compartido
- ✓ Estructura Firestore implementada y documentada
- ✓ Reglas de seguridad activas y testeadas
- ✓ Login funcional con 3 roles diferentes
- ✓ Pantallas de bienvenida por rol

**🎯 Criterio de Aceptación:**
Edgar puede registrarse como admin, crear usuarios de prueba (cliente/técnico), y verificar que cada rol solo ve lo permitido según reglas de seguridad.

---

#### **HITO 2: Flujo de Solicitud de Servicio**
**Semana 2 | Presupuesto: $700**

**📋 Tareas:**

1. **Pantalla de Creación de Solicitud**
   - Formulario con validaciones
   - Dropdown de categorías
   - Campo descripción (max 500 caracteres)
   - Selector de urgencia (normal/urgente)
   - Botón de envío con loading state

2. **Sistema de Subida de Fotos**
   - Integración con cámara del dispositivo
   - Integración con galería
   - Preview de fotos antes de subir
   - Límite de 5 fotos por servicio
   - Compresión automática (max 1MB por foto)
   - Subida a Firebase Storage con progress bar
   - Manejo de errores de subida

3. **Integración Google Maps**
   - Widget de mapa en pantalla de creación
   - Captura automática de ubicación actual
   - Pin arrastrable para ajuste manual
   - Geocoding inverso (coordenadas → dirección)
   - Vista de mapa en detalle de servicio
   - Cálculo de distancia entre dos puntos

4. **Sistema de Estados**
   - Implementar máquina de estados
   - Estados: pendiente, asignado, en_progreso, completado, cancelado
   - Colores y badges visuales por estado
   - Timestamps automáticos en cambios de estado
   - Historial de cambios de estado (opcional)

5. **Vista de Técnico**
   - Lista de servicios asignados
   - Filtros por estado
   - Vista de detalle de servicio
   - Botón para cambiar estado
   - Vista de ubicación en mapa

6. **Testing y Refinamiento**
   - Pruebas de creación de servicios
   - Pruebas de subida de fotos múltiples
   - Pruebas de captura de ubicación
   - Pruebas de permisos de geolocalización

**✅ Entregables:**
- ✓ Pantalla funcional de creación de solicitud
- ✓ Sistema de fotos funcional (subida, preview, compresión)
- ✓ Integración Google Maps con pin ajustable
- ✓ Geocoding inverso funcionando
- ✓ Estados de servicio implementados y visibles
- ✓ Vista básica de técnico con servicios asignados

**🎯 Criterio de Aceptación:**
Un cliente puede crear una solicitud completa con fotos, descripción y ubicación. El servicio aparece en Firestore con todos los datos correctos. Un técnico puede ver servicios asignados y cambiar su estado.

---

#### **HITO 3: Panel Admin + Asignación Manual**
**Semana 3 | Presupuesto: $500**

**📋 Tareas:**

1. **Panel de Administración**
   - Vista de lista de todos los servicios
   - Tarjetas con información resumida
   - Filtros por estado (pendiente, asignado, en_progreso, completado)
   - Filtro por categoría
   - Búsqueda por ID o nombre de cliente
   - Vista de detalle expandida

2. **Sistema de Asignación Manual**
   - Lista de técnicos disponibles
   - Indicador de distancia técnico-servicio
   - Indicador de servicios activos por técnico
   - Botón de asignación con confirmación
   - Actualización de estado a "asignado"
   - Registro de tecnicoId y timestamp

3. **Vista por Técnico**
   - Filtro de servicios por técnico específico
   - Estadísticas básicas (completados, en progreso)
   - Historial de servicios por técnico

4. **Integración WhatsApp**
   - Botón "Contactar por WhatsApp" en detalle de servicio
   - Deep link con formato: `https://wa.me/{telefono}?text=Hola, soy {nombre} de {plataforma}. Respecto a tu solicitud #{servicioId}: {descripcionBreve}`
   - Botón visible para cliente y técnico
   - Mensajes contextuales prellenados

5. **Sistema de Notificaciones**
   - Firebase Cloud Messaging (FCM) configurado
   - Notificación al técnico cuando se le asigna servicio
   - Notificación al cliente cuando estado cambia
   - Manejo de permisos de notificaciones
   - Testing en iOS y Android

6. **Chat Interno Básico**
   - Vista de chat dentro de detalle de servicio
   - Subcollection "mensajes" en Firestore
   - Mensajes en tiempo real con listeners
   - Input de texto con botón de envío
   - Indicador de mensaje leído/no leído
   - Badge de mensajes sin leer

**✅ Entregables:**
- ✓ Panel admin funcional con filtros
- ✓ Sistema de asignación manual funcionando
- ✓ WhatsApp deep links contextuales
- ✓ Notificaciones push básicas funcionando
- ✓ Chat interno en tiempo real operativo
- ✓ Vista por técnico con filtros

**🎯 Criterio de Aceptación:**
Edgar (admin) puede ver todos los servicios, filtrarlos, seleccionar uno pendiente, asignar un técnico, y ver que el técnico recibe notificación. El cliente y técnico pueden comunicarse por WhatsApp y por chat interno.

---

#### **HITO 4: Sistema de Estimación + Optimización**
**Semana 3 (final) | Presupuesto: $100**

**📋 Tareas:**

1. **Colección de Configuración de Tarifas**
   - Estructura en Firestore para tarifas por categoría
   - Campos: tarifaBase, multiplicadores, recargoPorKm
   - Valores iniciales de ejemplo
   - Pantalla admin para editar tarifas (opcional)

2. **Lógica de Estimación de Costos**
   - Función en FlutterFlow para calcular costo
   - Fórmula: `(tarifaBase * multiplicadorUrgencia) + (distancia > 10km ? (distancia-10) * recargoPorKm : 0)`
   - Cálculo automático al crear solicitud
   - Mostrar desglose de costos al cliente
   - Actualización en tiempo real si cambia urgencia

3. **Optimización de Queries**
   - Crear índices compuestos en Firestore
   - Implementar paginación en listas largas
   - Lazy loading de imágenes
   - Caché local de datos frecuentes
   - Reducir reads innecesarias

4. **Testing de Seguridad**
   - Verificar reglas de Firestore con Firebase Emulator
   - Intentar accesos no autorizados
   - Verificar que cada rol solo ve sus datos
   - Testing de inyección de datos inválidos
   - Verificar límites de tamaño de archivos

5. **Documentación Final Fase 1**
   - Manual de usuario para Edgar (admin)
   - Guía de operación del sistema
   - Documentación de la estructura de datos
   - Guía de troubleshooting común
   - Lista de pendientes para Fase 2

6. **Entrega y Transferencia**
   - Exportar proyecto FlutterFlow
   - Transferir ownership a cuenta de Edgar
   - Compartir acceso a Firebase Console
   - Sesión de walkthrough en vivo
   - Entrega de documentación completa

**✅ Entregables:**
- ✓ Sistema de estimación automática funcionando
- ✓ Colección de tarifas configurable
- ✓ Queries optimizadas con índices
- ✓ Reglas de seguridad testeadas y validadas
- ✓ Documentación completa entregada
- ✓ Proyecto FlutterFlow y Firebase transferidos

**🎯 Criterio de Aceptación:**
Al crear un servicio, el costo se calcula automáticamente y es correcto según las tarifas configuradas. Edgar tiene acceso completo y editable a FlutterFlow y Firebase. Todas las funcionalidades de Fase 1 funcionan sin errores críticos.

---

### **FASE 2: PAGOS, COMISIÓN Y ESCALABILIDAD**
**Duración:** 3 semanas
**Presupuesto:** $1,400
**Objetivo:** Integración de pagos con retención automática de comisión

---

#### **HITO 5: Integración Stripe Base**
**Semana 4 | Presupuesto: $700**

**📋 Tareas:**

1. **Configuración Stripe**
   - Crear cuenta Stripe (Edgar proporciona)
   - Configurar webhooks
   - Obtener API keys (test y live)
   - Configurar métodos de pago aceptados
   - Configurar moneda (USD/MXN/etc)

2. **Backend con Cloud Functions**
   - Función: `createPaymentIntent`
     - Input: servicioId, monto
     - Output: clientSecret de Stripe
     - Validaciones de seguridad
   - Función: `handleStripeWebhook`
     - Escuchar eventos: payment_intent.succeeded, payment_intent.failed
     - Actualizar Firestore según evento
     - Calcular y registrar comisión
   - Deploy de Cloud Functions

3. **Frontend de Pagos**
   - Integrar Stripe Elements en Flutter
   - Pantalla de pago con monto visible
   - Input de tarjeta seguro (Stripe Elements)
   - Botón "Pagar" con loading state
   - Manejo de errores de pago
   - Confirmación visual de pago exitoso

4. **Estados Adicionales de Pago**
   - Agregar estados: pago_pendiente, pagado, pago_fallido
   - Flujo automático: completado → pago_pendiente
   - Actualización automática vía webhook: pago_pendiente → pagado
   - Vista de estado de pago en detalle de servicio

5. **Registro de Pagos en Firestore**
   - Crear colección "transacciones"
   - Campos: servicioId, monto, comision, stripePaymentIntentId, estado, timestamps
   - Trigger automático al recibir webhook
   - Relación con servicio y usuarios

6. **Testing de Flujo de Pago**
   - Pruebas con tarjetas de test de Stripe
   - Prueba de pago exitoso
   - Prueba de pago fallido
   - Prueba de webhook delivery
   - Verificar creación correcta de transacción

**✅ Entregables:**
- ✓ Cuenta Stripe configurada y conectada
- ✓ Cloud Functions deployadas y funcionando
- ✓ Pantalla de pago funcional con Stripe Elements
- ✓ Webhooks configurados y respondiendo
- ✓ Estados de pago implementados
- ✓ Colección transacciones creada y poblándose

**🎯 Criterio de Aceptación:**
Un cliente puede pagar un servicio completado desde la app. El pago se procesa en Stripe, el webhook notifica a Firebase, se crea la transacción en Firestore, y el estado del servicio cambia a "pagado". Todo esto sucede en menos de 5 segundos.

---

#### **HITO 6: Comisión Automática + Preparación Split**
**Semana 5 | Presupuesto: $500**

**📋 Tareas:**

1. **Lógica de Cálculo de Comisión**
   - Obtener porcentaje de configuración (15% por defecto)
   - Calcular en Cloud Function al recibir webhook
   - Fórmula:
     ```
     comisionPlataforma = montoTotal * (porcentajeComision / 100)
     comisionStripe = montoTotal * 0.029 + 0.30 // 2.9% + $0.30
     montoTecnico = montoTotal - comisionPlataforma - comisionStripe
     ```
   - Guardar desglose en documento de transacción

2. **Registro Automático de Comisiones**
   - Campo `comisionPlataforma` en servicio
   - Campo `montoTecnico` en servicio
   - Actualización automática vía Cloud Function
   - Logs estructurados para auditoría

3. **Vista de Balance para Técnico**
   - Pantalla "Mis Ganancias" en app de técnico
   - Mostrar: total ganado, servicios pagados, comisión deducida
   - Filtro por fecha (semana, mes, año)
   - Lista de servicios con montos desglosados

4. **Vista de Ingresos para Admin**
   - Dashboard con métricas financieras
   - Total comisionado
   - Total pagado a técnicos
   - Gráficas de ingresos por período
   - Exportación a CSV (opcional)

5. **Preparación para Stripe Connect**
   - Documentar estructura para split payments futuro
   - Campos reservados: `stripeConnectAccountId` en técnicos
   - Documentación de migración a Stripe Connect
   - Estimación de tiempo y costo para implementar

6. **Logs Financieros Estructurados**
   - Cloud Function para logging de todas las transacciones
   - Formato estructurado (JSON)
   - Timestamps, IDs, montos, estados
   - Integración con Cloud Logging de GCP

**✅ Entregables:**
- ✓ Cálculo automático de comisiones funcionando
- ✓ Desglose de montos guardado en Firestore
- ✓ Vista de balance para técnico
- ✓ Dashboard financiero para admin
- ✓ Documentación de Stripe Connect preparada
- ✓ Sistema de logs financieros activo

**🎯 Criterio de Aceptación:**
Cuando un pago se completa, la comisión se calcula automáticamente (15%), se registra en la transacción, y aparece correctamente desglosada en las vistas de técnico y admin. Los logs muestran trazabilidad completa.

---

#### **HITO 7: Base para Escalamiento + Hardening**
**Semana 6 | Presupuesto: $200**

**📋 Tareas:**

1. **Modelo Híbrido de Asignación (ya preparado desde Hito 1)**
   - ✅ Estructura de datos para técnicos: especialidades, rating, tarifas, disponibilidad
   - ✅ Campo `tipoAsignacion` en servicios: "cliente" | "automatica" | "admin"
   - ✅ Colección `resenas` para calificaciones de técnicos
   - ✅ Security rules actualizadas para que clientes vean perfiles de técnicos
   - Implementar algoritmo de asignación automática por:
     - Proximidad geográfica (GeoHash)
     - Calificación promedio (desc)
     - Carga de trabajo actual (asc)
     - Disponibilidad horaria
   - Cloud Function para auto-asignación cuando tipoAsignacion == "automatica"

2. **Índices Compuestos Optimizados**
   - Revisar queries más comunes
   - Crear índices compuestos necesarios
   - Índice para búsquedas por geohash + estado
   - Índice para filtros combinados en panel admin
   - Verificar performance con datos de prueba

3. **Preparación para Cloud Functions Avanzadas**
   - Estructura de carpetas para funciones futuras
   - Función placeholder para asignación automática
   - Función placeholder para notificaciones avanzadas
   - Documentación de qué falta implementar

4. **Testing Completo de Seguridad**
   - Penetration testing básico
   - Intentar acceso con tokens expirados
   - Intentar acceso cross-user
   - Verificar que admin no puede ser creado por registro público
   - Testing de límites de rate (Firebase tiene límites nativos)

5. **Optimizaciones de Performance**
   - Implementar caché de datos estáticos (categorías, tarifas)
   - Optimizar carga de imágenes (thumbnails)
   - Implementar pagination en listas largas
   - Lazy loading de mensajes antiguos en chat
   - Reducir lecturas redundantes de Firestore

6. **Documentación de Escalamiento**
   - Documento "Roadmap Fase 3"
   - Lista de features para escalar (asignación auto, ratings, multi-payment)
   - Estimaciones de costo y tiempo
   - Recomendaciones de monitoreo
   - Plan de migración a producción

7. **Entrega Final y Revisión**
   - Walkthrough completo de toda la app
   - Sesión de Q&A con Edgar
   - Transfer completo de ownership
   - Entrega de documentación final
   - Soporte post-entrega (alcance a definir)

**✅ Entregables:**
- ✓ Estructura preparada para asignación automática
- ✓ Índices optimizados creados
- ✓ Placeholders de Cloud Functions futuras
- ✓ Testing de seguridad completo y documentado
- ✓ Performance optimizado (< 2s carga de pantallas)
- ✓ Documentación de roadmap Fase 3
- ✓ Sistema listo para producción

**🎯 Criterio de Aceptación:**
La app está completamente funcional, optimizada, segura y lista para lanzar a usuarios reales. Edgar tiene documentación completa de cómo operar, modificar y escalar el sistema. No hay bugs críticos ni bloqueos en flujos principales.

---

### **FASE 3: REQUERIMIENTOS ADICIONALES DEL CLIENTE**
**Duración:** Por definir
**Presupuesto:** Por negociar (no incluido en contrato original de $3,000)
**Origen:** Solicitud de Edgar Daniel Godoy Montalvo (marzo 2026) - Flujo operativo detallado enviado posterior al contrato inicial

> **Nota:** Los siguientes requerimientos fueron enviados por el cliente después de la firma del contrato original. Representan funcionalidades adicionales que no estaban contempladas en los Hitos 1-7 originales y requieren negociación de presupuesto y timeline adicional.

---

#### **HITO 8: Servicio de Diagnóstico y Sistema de Cotización**
**Duración estimada:** 2 semanas | **Presupuesto estimado:** $800-1,200

**📋 Contexto del Cliente:**
Edgar solicita un flujo donde ciertos servicios requieren diagnóstico previo antes de la reparación. El técnico visita, evalúa el problema, genera una cotización detallada, y el cliente aprueba o rechaza antes de proceder.

**📋 Tareas:**

1. **Flujo de Servicio Diagnóstico**
   - Nuevo tipo de servicio: "diagnóstico" (además de "estándar")
   - Estados adicionales: `diagnostico_pendiente`, `diagnostico_realizado`, `cotizacion_enviada`, `cotizacion_aprobada`, `cotizacion_rechazada`, `en_reparacion`
   - Máquina de estados extendida con transiciones válidas
   - El técnico puede cambiar tipo de servicio de estándar a diagnóstico si lo considera necesario

2. **Sistema de Cotización**
   - Nueva colección `cotizaciones` en Firestore:
     - servicioId (String)
     - tecnicoId (String)
     - items (Array): [{descripcion, tipo (mano_obra/material/pieza), cantidad, precioUnitario, subtotal}]
     - subtotal (Double)
     - impuestos (Double)
     - total (Double)
     - estado (String): pendiente, aprobada, rechazada
     - notasTecnico (String)
     - fechaCreacion (DateTime)
     - fechaRespuesta (DateTime)
   - Pantalla para técnico: crear/editar cotización con items dinámicos
   - Pantalla para cliente: ver cotización detallada con desglose
   - Botones de aprobar/rechazar cotización
   - Notificación push al cliente cuando cotización está lista
   - Notificación push al técnico cuando cliente responde

3. **Pantalla de Creación de Cotización (Técnico)**
   - Formulario dinámico para agregar items
   - Campos: descripción, tipo (mano de obra/material/pieza), cantidad, precio unitario
   - Cálculo automático de subtotales y total
   - Campo de notas/observaciones del técnico
   - Adjuntar fotos del diagnóstico
   - Botón enviar cotización al cliente

4. **Pantalla de Revisión de Cotización (Cliente)**
   - Vista detallada del desglose de costos
   - Fotos del diagnóstico
   - Notas del técnico
   - Botón "Aprobar" → servicio pasa a `en_reparacion`
   - Botón "Rechazar" → servicio pasa a `cotizacion_rechazada`
   - Opción de contactar al técnico para negociar

**✅ Entregables:**
- ✓ Flujo completo de diagnóstico implementado
- ✓ Colección cotizaciones funcional
- ✓ Pantalla de creación de cotización para técnico
- ✓ Pantalla de revisión/aprobación para cliente
- ✓ Notificaciones en cada cambio de estado
- ✓ Estados adicionales integrados en toda la app

**🎯 Criterio de Aceptación:**
Un técnico puede realizar un diagnóstico, crear una cotización detallada con items y precios, enviarla al cliente. El cliente recibe notificación, revisa el desglose, y puede aprobar o rechazar. Al aprobar, el servicio avanza automáticamente al siguiente estado.

---

#### **HITO 9: Validación de Técnicos y Documentación**
**Duración estimada:** 1 semana | **Presupuesto estimado:** $400-600

**📋 Contexto del Cliente:**
Edgar requiere que los técnicos suban documentos de identificación y certificaciones para ser validados antes de poder recibir servicios. El administrador revisa y aprueba/rechaza cada técnico.

**📋 Tareas:**

1. **Sistema de Documentos de Técnico**
   - Campos adicionales en colección `users` (para técnicos):
     - documentoINE (String - URL en Storage)
     - documentoCURP (String - URL en Storage)
     - comprobantedomicilio (String - URL en Storage)
     - certificaciones (Array de URLs)
     - estadoValidacion (String): pendiente, aprobado, rechazado, documentos_faltantes
     - fechaValidacion (DateTime)
     - notasAdmin (String)
   - Subida de documentos a Firebase Storage
   - Restricción: técnicos no validados no aparecen en búsquedas ni pueden ser asignados

2. **Pantalla de Registro de Técnico (extendida)**
   - Formulario multi-paso:
     - Paso 1: Datos personales (nombre, teléfono, email, especialidad)
     - Paso 2: Subir documentos (INE, CURP, comprobante de domicilio)
     - Paso 3: Certificaciones opcionales
     - Paso 4: Confirmación y envío
   - Preview de documentos antes de subir
   - Indicador de progreso de subida
   - Mensaje: "Tu cuenta está en revisión. Te notificaremos cuando sea aprobada."

3. **Panel de Validación (Admin)**
   - Nueva sección en AdminPage: "Técnicos Pendientes de Validación"
   - Lista de técnicos con estadoValidacion == "pendiente"
   - Vista detallada: ver todos los documentos subidos
   - Botones: Aprobar / Rechazar / Solicitar documentos adicionales
   - Campo de notas del administrador
   - Notificación push al técnico con resultado

4. **Filtro de Técnicos Validados**
   - Modificar queries de búsqueda de técnicos: solo mostrar `estadoValidacion == "aprobado"`
   - Modificar AsignarTecnicoPage: solo técnicos aprobados
   - Badge "Verificado ✓" en perfil de técnico

**✅ Entregables:**
- ✓ Sistema de subida de documentos funcional
- ✓ Pantalla de registro extendida para técnicos
- ✓ Panel de validación para administrador
- ✓ Filtro de técnicos por estado de validación
- ✓ Notificaciones de aprobación/rechazo
- ✓ Badge de verificación en perfiles

**🎯 Criterio de Aceptación:**
Un nuevo técnico se registra, sube sus documentos (INE, CURP, comprobante). El administrador recibe notificación, revisa los documentos, y aprueba o rechaza. Solo técnicos aprobados aparecen disponibles para asignación y búsqueda.

---

#### **HITO 10: Citas de Taller y Agenda**
**Duración estimada:** 1.5 semanas | **Presupuesto estimado:** $500-700

**📋 Contexto del Cliente:**
Edgar solicita que algunos técnicos puedan recibir clientes en su taller/local. Se necesita un sistema de citas con calendario para coordinar visitas.

**📋 Tareas:**

1. **Perfil de Taller del Técnico**
   - Campos adicionales en `users` (técnicos):
     - tieneTaller (Boolean)
     - direccionTaller (String)
     - ubicacionTaller (GeoPoint)
     - horarioAtencion (Map): {lunes: {inicio: "09:00", fin: "18:00"}, ...}
     - duracionCitaMinutos (Integer): 30, 60, 90
   - Pantalla de configuración de taller para técnico
   - Mapa con ubicación del taller

2. **Sistema de Citas**
   - Nueva colección `citas` en Firestore:
     - servicioId (String)
     - tecnicoId (String)
     - clienteId (String)
     - fechaHora (DateTime)
     - duracionMinutos (Integer)
     - estado (String): programada, confirmada, completada, cancelada, no_asistio
     - tipo (String): taller, domicilio
     - notas (String)
   - Verificación de disponibilidad (no permitir citas superpuestas)
   - Notificaciones de recordatorio (24h antes, 1h antes)

3. **Pantalla de Agendar Cita (Cliente)**
   - Selección de fecha en calendario
   - Horarios disponibles según configuración del técnico
   - Slots ocupados bloqueados
   - Confirmación de cita con resumen
   - Dirección del taller con mapa

4. **Pantalla de Gestión de Citas (Técnico)**
   - Vista de calendario con citas programadas
   - Lista de citas del día
   - Opciones: confirmar, cancelar, marcar como completada
   - Vista de historial de citas

**✅ Entregables:**
- ✓ Perfil de taller configurado para técnicos
- ✓ Colección citas funcional
- ✓ Pantalla de agendar cita para cliente
- ✓ Pantalla de gestión de citas para técnico
- ✓ Verificación de disponibilidad
- ✓ Notificaciones de recordatorio

**🎯 Criterio de Aceptación:**
Un cliente puede ver técnicos con taller, seleccionar fecha y hora disponible, agendar una cita. El técnico recibe notificación, puede confirmar. Ambos reciben recordatorio antes de la cita. No se permiten citas en horarios ya ocupados.

---

#### **HITO 11: Categorización Avanzada de Servicios**
**Duración estimada:** 0.5 semanas | **Presupuesto estimado:** $200-300

**📋 Contexto del Cliente:**
Edgar requiere una categorización más detallada de servicios, con subcategorías específicas para cada tipo de servicio y precios diferenciados.

**📋 Tareas:**

1. **Estructura de Categorías y Subcategorías**
   - Nueva colección `categorias` en Firestore:
     - nombre (String)
     - subcategorias (Array): [{nombre, descripcion, tarifaBase, tiempoEstimado}]
     - icono (String)
     - activa (Boolean)
   - Migrar datos actuales de `tarifas` a nueva estructura
   - Ejemplo:
     - Plomería → [Fuga de agua, Instalación de tubería, Destape de drenaje, Instalación de calentador]
     - Electricidad → [Corto circuito, Instalación de contactos, Instalación de luminarias, Revisión general]

2. **Selector de Categoría Mejorado (Cliente)**
   - Paso 1: Seleccionar categoría principal (con iconos)
   - Paso 2: Seleccionar subcategoría específica
   - Mostrar precio estimado según subcategoría
   - Descripción breve de cada subcategoría

3. **Panel Admin para Gestionar Categorías**
   - CRUD de categorías y subcategorías
   - Activar/desactivar categorías
   - Editar tarifas por subcategoría

**✅ Entregables:**
- ✓ Estructura de categorías/subcategorías en Firestore
- ✓ Selector mejorado en CreateServicePage
- ✓ Panel admin para gestionar categorías
- ✓ Precios diferenciados por subcategoría

**🎯 Criterio de Aceptación:**
Al crear un servicio, el cliente primero selecciona la categoría principal y luego una subcategoría específica. El precio estimado se ajusta según la subcategoría seleccionada. El administrador puede agregar/editar categorías desde el panel.

---

### RESUMEN FASE 3

| Hito | Funcionalidad | Duración Est. | Presupuesto Est. |
|------|--------------|---------------|-----------------|
| Hito 8 | Diagnóstico + Cotización | 2 semanas | $800-1,200 |
| Hito 9 | Validación de Técnicos | 1 semana | $400-600 |
| Hito 10 | Citas de Taller | 1.5 semanas | $500-700 |
| Hito 11 | Categorización Avanzada | 0.5 semanas | $200-300 |
| **TOTAL FASE 3** | | **5 semanas** | **$1,900-2,800** |

> **Nota importante:** Estos presupuestos son estimaciones iniciales. El presupuesto final dependerá de la complejidad real durante el desarrollo y los requisitos específicos del cliente. Se recomienda negociar antes de iniciar cada hito.

---

## 📊 RESUMEN FINANCIERO

| Fase | Hito | Semana | Presupuesto | Acumulado | % Total |
|------|------|--------|-------------|-----------|---------|
| **Fase 1** | Hito 1: Arquitectura | 1 | $300 | $300 | 6% |
| | Hito 2: Solicitudes | 2 | $700 | $1,000 | 19% |
| | Hito 3: Panel Admin | 3 | $500 | $1,500 | 29% |
| | Hito 4: Estimación | 3 | $100 | $1,600 | 31% |
| **Fase 2** | Hito 5: Stripe | 4 | $700 | $2,300 | 44% |
| | Hito 6: Comisiones | 5 | $500 | $2,800 | 54% |
| | Hito 7: Escalamiento | 6 | $200 | $3,000 | 58% |
| **Fase 3** | Hito 8: Diagnóstico + Cotización | 7-8 | $1,000* | $4,000 | 77% |
| *(Adicional)* | Hito 9: Validación Técnicos | 9 | $500* | $4,500 | 87% |
| | Hito 10: Citas de Taller | 10 | $600* | $5,100 | 98% |
| | Hito 11: Categorización Avanzada | 10 | $250* | $5,350 | 100% |
| **TOTAL** | | **~11 semanas** | **~$5,350** | | |

> *Los montos de Fase 3 son estimaciones promedio, sujetas a negociación con el cliente.
> Contrato original: $3,000 (Fase 1 + Fase 2). Fase 3: ~$2,350 adicionales.

---

## 🎯 ÚLTIMA SOLICITUD DEL CLIENTE

**De:** Edgar Daniel Godoy Montalvo
**Fecha:** 3 de marzo de 2026 (hace 1 hora)
**Contexto:** Proyecto aprobado y pagado en escrow de Workana

### Solicitud Textual:

> "Perfecto, iniciemos con el Hito 1.
>
> Por favor compárteme:
> 1. El documento técnico con el modelo de datos propuesto.
> 2. La estructura inicial de Firestore.
> 3. Qué accesos necesitas de mi parte para comenzar en mis cuentas.
>
> Quiero revisar la arquitectura antes de avanzar con la implementación.
>
> Avancemos."

### Análisis de la Solicitud:

1. **Documento Técnico:** Edgar pide documentación formal de arquitectura
2. **Modelo de Datos:** Quiere ver estructura completa de Firestore antes de código
3. **Accesos:** Pregunta qué credenciales/accesos proveer
4. **Aprobación previa:** Quiere revisar y aprobar arquitectura ANTES de implementar
5. **Tono:** Proactivo y listo para comenzar inmediatamente

### Respuesta Sugerida a Edgar:

```
Hola Edgar,

¡Perfecto! Iniciemos oficialmente con el Hito 1.

Adjunto el **Documento Técnico de Arquitectura** completo que incluye:

✅ Modelo de datos Firestore detallado
✅ Estructura de colecciones y subcollections
✅ Reglas de seguridad implementadas
✅ Índices compuestos necesarios
✅ Flujos de usuario documentados
✅ Estrategia de escalabilidad para Fase 2

**Accesos que necesito de tu parte:**

1. **Firebase:**
   - Crea un proyecto en https://console.firebase.google.com
   - Invítame como Editor: [tu-email@gmail.com]
   - Habilita Billing (necesario para Cloud Functions en Fase 2)

2. **Google Cloud Platform:**
   - Habilita las siguientes APIs en https://console.cloud.google.com:
     - Maps JavaScript API
     - Geocoding API
     - Places API (opcional para autocompletado)
   - Crea una API Key con restricciones de dominio
   - Compárteme la API Key

3. **FlutterFlow:**
   - Opción A: Me das acceso a tu cuenta y creo el proyecto ahí
   - Opción B: Creo el proyecto en mi cuenta y lo transfiero al final
   - Recomiendo Opción A para que veas progreso en tiempo real

4. **Stripe (para Fase 2):**
   - Crea cuenta en https://stripe.com (modo test por ahora)
   - No necesito acceso aún, pero ten cuenta lista

**Próximos pasos inmediatos:**

📌 Por favor revisa el documento adjunto en las próximas 24-48h
📌 Aprueba el modelo de datos o solicita cambios
📌 Provee los accesos listados arriba
📌 En cuanto tenga acceso, inicio la implementación

**Cronograma Hito 1 (esta semana):**
- Día 1-2: Setup inicial + estructura Firestore
- Día 3-4: Reglas de seguridad + testing
- Día 5-7: Sistema de autenticación + pantallas de rol
- Entrega: Viernes de esta semana

¿Alguna pregunta sobre el documento técnico?

Avancemos,
JunJun
```

---

## 💡 RECOMENDACIONES ADICIONALES

### Para Edgar (Cliente):

1. **Validación temprana:** Usa el MVP con usuarios reales (amigos/familia) antes de invertir en marketing
2. **Métricas clave:** Mide tiempo promedio de asignación, tasa de conversión, satisfacción
3. **Iteración:** Recopila feedback y prioriza features para Fase 3
4. **Legal:** Considera términos de servicio, privacidad, y contrato con técnicos
5. **Escalamiento:** Firebase escala automáticamente, pero costos crecen con uso (monitorea)

### Para Desarrollador (JunJun):

1. **Comunicación:** Updates diarios/bi-diarios durante desarrollo
2. **Demos:** Mini-demos en video cada 2-3 días para validación temprana
3. **Testing:** Testing en dispositivos reales, no solo emulador
4. **Rollback:** Usa Git para versionado, commits frecuentes
5. **Buffer:** Reserva 10-15% del tiempo para bugs inesperados

---

## 📝 CONCLUSIONES

### Viabilidad del Proyecto: ✅ ALTA

**Fortalezas:**
- Stack tecnológico apropiado para MVP
- Presupuesto realista para alcance definido
- Timeline alcanzable (6 semanas con sprints de 1 semana)
- Arquitectura escalable desde día 1
- Hitos verificables reducen riesgo

**Riesgos Identificados:**

| Riesgo | Probabilidad | Impacto | Mitigación |
|--------|--------------|---------|------------|
| Retrasos en aprobaciones de Edgar | Media | Medio | Establecer SLA de 48h para feedback |
| Complejidad de Google Maps | Baja | Alto | Usar librerías probadas (geoflutterfire2) |
| Webhooks de Stripe con bugs | Media | Alto | Testing exhaustivo en sandbox |
| Firebase costos inesperados | Baja | Medio | Configurar alertas de billing |
| Scope creep por Edgar | Media | Alto | Contrato claro, cambios = presupuesto extra |

### Probabilidad de Éxito: 85%

**Factores positivos:**
- Desarrollador con experiencia demostrable en proyectos similares
- Cliente comprometido con presupuesto disponible
- Alcance bien definido y documentado
- Tecnologías maduras y probadas

**Factores de atención:**
- Comunicación: JunJun a veces tarda en responder
- Expectativas: Edgar espera calidad alta por presupuesto ajustado
- Timeline: 6 semanas es ajustado, cualquier bloqueo afecta entrega

---

## 📅 PRÓXIMOS PASOS INMEDIATOS

### Para Edgar:
1. ✅ Revisar y aprobar este documento técnico
2. ✅ Crear proyecto Firebase y dar acceso a JunJun
3. ✅ Crear API Key de Google Maps
4. ✅ Decidir si FlutterFlow en su cuenta o transferencia posterior
5. ✅ Establecer canal de comunicación directa (WhatsApp/Telegram/Slack)

### Para JunJun:
1. ✅ Recibir accesos de Edgar
2. ✅ Crear estructura inicial de Firestore
3. ✅ Implementar reglas de seguridad
4. ✅ Setup de FlutterFlow con Firebase
5. ✅ Primera entrega Hito 1 en 7 días

---

**Documento generado:** 3 de marzo de 2026
**Versión:** 1.0
**Elaborado por:** Análisis de proyecto independiente
**Para:** Edgar Daniel Godoy Montalvo & JunJun Mabod

---

## ANEXOS

### Anexo A: Glosario de Términos

- **MVP:** Minimum Viable Product (Producto Mínimo Viable)
- **Firestore:** Base de datos NoSQL de Firebase
- **GeoHash:** Codificación de coordenadas geográficas para búsquedas
- **Deep Link:** Enlace que abre directamente una app con contexto
- **Webhook:** Notificación HTTP automática de un servicio a otro
- **PaymentIntent:** Objeto de Stripe que representa intención de pago
- **Cloud Function:** Función serverless que corre en Google Cloud
- **FlutterFlow:** Plataforma low-code para crear apps Flutter
- **Split Payment:** Dividir un pago entre múltiples receptores

### Anexo B: Enlaces Útiles

- FlutterFlow: https://flutterflow.io
- Firebase Console: https://console.firebase.google.com
- Stripe Dashboard: https://dashboard.stripe.com
- Google Cloud Console: https://console.cloud.google.com
- Firebase Rules Playground: https://firebase.google.com/docs/rules/simulator

### Anexo C: Recursos de Aprendizaje

- FlutterFlow University: https://university.flutterflow.io
- Firebase YouTube: https://www.youtube.com/c/Firebase
- Stripe Docs: https://stripe.com/docs
- Flutter Packages: https://pub.dev

---

**FIN DEL DOCUMENTO**
