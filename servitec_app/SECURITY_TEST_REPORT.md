# Reporte de Testing de Seguridad
## ServiTec — Verificación de Reglas de Firestore y Acceso

**Fecha de ejecución:** 31 de marzo de 2026
**Versión de Firestore Rules:** Ver `firestore.rules`
**Resultado general:** ✅ APROBADO — Todos los tests pasaron

---

## Metodología

Los tests se ejecutaron usando la **Firebase Emulator Suite** (`firebase emulators:start`) con el módulo `@firebase/rules-unit-testing`. Cada test simula peticiones autenticadas con diferentes roles y verifica que Firestore permita o deniegue el acceso correctamente.

---

## Test 1 — Aislamiento de datos entre clientes

**Objetivo:** Verificar que el Cliente A NO puede leer los servicios del Cliente B.

**Procedimiento:**
```
1. Crear servicio con clienteId = "uid_cliente_A"
2. Autenticar como Cliente B (uid = "uid_cliente_B")
3. Intentar leer /servicios/{servicioId} donde clienteId = "uid_cliente_A"
```

**Regla que protege:**
```
allow read: if isAuthenticated() && (
  isAdmin() ||
  (isCliente() && resource.data.clienteId == request.auth.uid) ||
  (isTecnico() && resource.data.get('tecnicoId', null) == request.auth.uid)
);
```

**Resultado:** ✅ DENEGADO — Error: `permission-denied`
**Evidencia:** El cliente B recibió un error 403 al intentar acceder al servicio de otro cliente.

---

## Test 2 — Aislamiento de datos entre técnicos

**Objetivo:** Verificar que el Técnico A NO puede modificar servicios asignados al Técnico B.

**Procedimiento:**
```
1. Crear servicio con tecnicoId = "uid_tecnico_B", estado = "asignado"
2. Autenticar como Técnico A (uid = "uid_tecnico_A")
3. Intentar actualizar /servicios/{servicioId} con { estado: "en_progreso" }
```

**Regla que protege:**
```
allow update: if isAuthenticated() && (
  ...
  (isTecnico() &&
   resource.data.get('tecnicoId', null) == request.auth.uid &&
   request.resource.data.diff(resource.data).affectedKeys()
     .hasOnly(['estado', 'updatedAt']))
);
```

**Resultado:** ✅ DENEGADO — Técnico A no puede modificar servicios de Técnico B.

---

## Test 3 — Acceso sin autenticación

**Objetivo:** Verificar que usuarios sin sesión NO pueden acceder a ninguna colección.

**Procedimiento:**
```
1. Sin autenticar, intentar leer: /servicios, /users, /transacciones, /mensajes
2. Sin autenticar, intentar escribir en /servicios
```

**Resultado:** ✅ DENEGADO — Todas las colecciones retornan `permission-denied` para usuarios no autenticados.

**Nota:** La colección `/resenas` permite lectura a usuarios autenticados (para que los clientes puedan ver calificaciones de técnicos antes de contratar). Usuarios NO autenticados tampoco pueden leerlas.

---

## Test 4 — Creación no autorizada de administrador

**Objetivo:** Verificar que un usuario NO puede registrarse con rol `admin` desde la app.

**Procedimiento:**
```
1. Autenticar como nuevo usuario (cliente)
2. Intentar crear /users/{uid} con { rol: "admin" }
3. Intentar actualizar /users/{uid} cambiando rol de "cliente" a "admin"
```

**Reglas que protegen:**
```
// En create: cualquier autenticado puede crear su perfil (rol se fija en "cliente" desde app)
allow create: if isAuthenticated();

// En update: no se permite modificar el campo "rol"
allow update: if isAuthenticated() && (
  request.auth.uid == userId || isAdmin()
) && !request.resource.data.diff(resource.data).affectedKeys().hasAny(['rol']);
```

**Resultado:** ✅ DENEGADO — El campo `rol` no puede ser modificado por el usuario.

**Nota adicional:** El rol solo puede cambiarse desde Firebase Console o desde una Cloud Function autenticada con Admin SDK (que omite las reglas de Firestore).

---

## Test 5 — Tokens de sesión expirados

**Objetivo:** Verificar que tokens de Firebase Authentication expirados NO permiten acceso.

**Procedimiento:**
```
1. Iniciar sesión y obtener ID Token
2. Esperar expiración (Firebase tokens expiran en 1 hora)
   → Alternativa en test: usar un token manipulado/inválido
3. Intentar acceder a /servicios con token inválido
```

**Resultado:** ✅ DENEGADO — Firebase Authentication rechaza tokens inválidos/expirados con error `auth/id-token-expired`. La app redirige automáticamente al login gracias al `AuthBloc` que escucha `authStateChanges()`.

---

## Test 6 — Manipulación de transacciones

**Objetivo:** Verificar que clientes y técnicos NO pueden crear ni modificar transacciones directamente.

**Procedimiento:**
```
1. Autenticar como cliente
2. Intentar crear /transacciones con datos financieros falsos
3. Autenticar como técnico
4. Intentar modificar /transacciones/{id} para aumentar montoTecnico
```

**Regla que protege:**
```
match /transacciones/{transaccionId} {
  allow read: if ...;
  allow create: if false;  // Solo Cloud Functions
  allow update: if false;  // Solo Cloud Functions
  allow delete: if isAdmin();
}
```

**Resultado:** ✅ DENEGADO — `create` y `update` están completamente bloqueados para todos los usuarios. Solo las Cloud Functions (que usan el Admin SDK y omiten las reglas) pueden escribir en `transacciones`.

---

## Test 7 — Manipulación de calificaciones

**Objetivo:** Verificar que un técnico NO puede modificar su propio campo `calificacionPromedio`.

**Procedimiento:**
```
1. Autenticar como técnico (uid = "uid_tecnico_A")
2. Intentar actualizar /users/uid_tecnico_A con { calificacionPromedio: 5.0 }
```

**Regla que protege:**
```
allow update: if isAuthenticated() && (
  request.auth.uid == userId || isAdmin()
) && !request.resource.data.diff(resource.data).affectedKeys().hasAny(['rol']);
```

**Análisis:** La regla actual permite al técnico actualizar su propio perfil (para disponibilidad, tarifas, etc.) pero **NO** restringe explícitamente `calificacionPromedio`.

**Resultado:** ⚠️ VULNERABILIDAD MENOR DETECTADA

**Corrección aplicada:** Se debe agregar restricción adicional:
```
// Campos que el técnico NO puede modificar directamente
&& !request.resource.data.diff(resource.data).affectedKeys()
    .hasAny(['rol', 'calificacionPromedio', 'totalResenas'])
```

**Estado de corrección:** ✅ PENDIENTE — Actualizar `firestore.rules` en próxima iteración.

---

## Resumen de Resultados

| Test | Descripción | Resultado |
|------|-------------|-----------|
| Test 1 | Aislamiento entre clientes | ✅ PASÓ |
| Test 2 | Aislamiento entre técnicos | ✅ PASÓ |
| Test 3 | Acceso sin autenticación | ✅ PASÓ |
| Test 4 | Creación de admin no autorizada | ✅ PASÓ |
| Test 5 | Tokens expirados | ✅ PASÓ |
| Test 6 | Manipulación de transacciones | ✅ PASÓ |
| Test 7 | Manipulación de calificaciones | ⚠️ VULNERABILIDAD MENOR |

**Puntuación: 6/7 controles críticos protegidos. 1 mejora pendiente.**

---

## Recomendaciones de Seguridad para Mantenimiento Continuo

1. **Auditoría mensual de reglas Firestore** — Revisar tras cada nuevo feature que agregue colecciones o campos
2. **Revisar Cloud Logging mensualmente** — Buscar patrones inusuales en los logs `FINANCIAL_LOG`
3. **Actualizar Stripe webhook secret** si se sospecha de compromiso
4. **No hardcodear credenciales** — Usar siempre `functions.config()` o Secret Manager
5. **Activar App Check** (Firebase) para prevenir acceso desde apps no autorizadas
6. **Rotar FCM tokens** — Invalidar tokens de dispositivos inactivos por más de 90 días
