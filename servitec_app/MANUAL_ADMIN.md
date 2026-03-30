# Manual del Administrador — ServiTec
## Guía de Operación Diaria para Edgar Daniel Godoy Montalvo

**Versión:** 1.0 | **Fecha:** Marzo 2026

---

## 1. Acceso al Panel de Administración

### Iniciar sesión
1. Abrir la app ServiTec en tu teléfono
2. Ingresar tu email y contraseña de administrador
3. Si aparece "Verificar identidad", confirmar con tu huella digital o PIN
4. Serás redirigido automáticamente al **Panel de Administración**

> **Nota:** Solo las cuentas con rol `admin` pueden acceder al panel. Si por error llegas a la pantalla de cliente, cierra sesión y vuelve a ingresar.

---

## 2. Panel Principal (AdminPage)

### ¿Qué ves en el panel?

```
┌─────────────────────────────────┐
│ Panel de Administración         │
│ ServiTec Dashboard              │
├─────────────────────────────────┤
│ [Pendientes: 5] [Activos: 3] [Completados: 47]  │
├─────────────────────────────────┤
│ Filtros: Todos | Pendientes | Asignados | ...   │
│ Filtros de categoría: Plomería | Electricidad... │
│ [🔍 Buscar por cliente o título]                 │
├─────────────────────────────────┤
│ Lista de servicios (20 por página)              │
│ [Cargar más...]                                 │
└─────────────────────────────────┘
```

### Tarjetas de resumen
- **Pendientes** (amarillo): servicios sin técnico asignado → requieren tu atención
- **Activos** (azul): servicios en progreso actualmente
- **Completados** (verde): servicios terminados este período

---

## 3. Filtrar Servicios

### Por estado
Toca cualquier chip de filtro en la segunda fila:
- **Todos** — muestra todos los servicios
- **Pendientes** — solo los que esperan asignación
- **Asignados** — técnico asignado, trabajo no iniciado
- **En Progreso** — técnico trabajando actualmente
- **Completados** — trabajo terminado

### Por categoría
En la tercera fila de chips, selecciona una categoría:
- 🔧 Plomería, ⚡ Electricidad, ❄️ Aire Acondicionado, etc.

### Buscar un servicio específico
1. Toca el campo de búsqueda "Buscar por cliente o título..."
2. Escribe el nombre del cliente, título del servicio, o ID del servicio
3. Los resultados se filtran en tiempo real

### Ver más servicios
La lista muestra **20 servicios por página**. Si hay más:
- Desliza hasta el final de la lista
- Toca "**Cargar más (X restantes)**"

---

## 4. Asignar un Técnico Manualmente

### Cuándo asignar manualmente
- La asignación automática falló (recibirás una notificación push)
- Quieres asignar un técnico específico por cualquier razón
- El servicio tiene requerimientos especiales

### Pasos para asignar
1. Toca el servicio que dice "Pendiente" (en amarillo)
2. En la pantalla de detalle, toca "**Asignar Técnico**"
3. Verás la lista de técnicos disponibles con:
   - Nombre y especialidades
   - Calificación promedio ⭐
   - Número de servicios activos (carga de trabajo actual)
4. Toca el técnico que quieres asignar
5. Confirma la asignación
6. El técnico recibirá una notificación push automáticamente

---

## 5. Dashboard Financiero

### Cómo acceder
Desde el panel principal → ícono de finanzas en la barra inferior (o botón "Dashboard Financiero")

### Filtrar por período
En la parte superior, usa el selector de período:
- **Esta Semana** — desde el lunes de la semana actual
- **Este Mes** — desde el día 1 del mes actual
- **Este Año** — desde el 1 de enero
- **Todo** — histórico completo

### Métricas que verás
| Métrica | Descripción |
|---------|-------------|
| Comisión Total | Lo que ganó la plataforma en el período |
| Ingresos Totales | Total cobrado a clientes |
| Pagado a Técnicos | Total transferido a técnicos (neto) |
| Transacciones | Cantidad de pagos completados |

### Gráfico de distribución
El gráfico de pie muestra cómo se distribuye cada peso cobrado:
- 🔵 Plataforma (tu comisión, ~15%)
- 🟢 Técnicos (~83%)
- ⚫ Stripe (fee de procesamiento, ~2%)

### Lista de transacciones
Muestra las últimas 20 transacciones del período seleccionado con desglose completo:
- Total cobrado al cliente
- Tu comisión (+)
- Fee de Stripe (-)
- Pagado al técnico

---

## 6. Gestionar Técnicos

### Ver lista de técnicos
Panel principal → ícono de personas → "Técnicos"

Verás cada técnico con:
- Nombre y foto de perfil
- Especialidades
- Calificación promedio y número de reseñas
- Estado: Disponible / No disponible
- Servicios completados

### Activar/Desactivar un técnico
1. Toca el técnico en la lista
2. Usa el toggle "**Activo**" para habilitar o deshabilitar al técnico
3. Un técnico desactivado NO aparecerá en la asignación automática

### Aprobar documentos de un técnico nuevo
(Cuando el Hito 9 esté implementado)
1. Panel → "Validación de Documentos"
2. Revisa los documentos subidos (INE, CURP, etc.)
3. Aprueba o rechaza con comentario

---

## 7. Gestionar Tarifas

### Cómo acceder
Panel principal → ícono de configuración (engranaje) en la esquina superior derecha → "Configurar Tarifas"

### Modificar una tarifa
1. Selecciona la categoría (Plomería, Electricidad, etc.)
2. Edita los campos:
   - **Tarifa Base** ($): precio mínimo del servicio
   - **Multiplicador Urgente** (×): factor para servicios urgentes (ej: 1.5 = 50% más caro)
   - **Recargo por Km** ($): cobro adicional por distancia sobre la base
3. Toca "Guardar"

> **Importante:** Los cambios de tarifa afectan los NUEVOS servicios. Los servicios ya creados mantienen la estimación original.

### Cambiar el porcentaje de comisión
1. Tarifas → "Configuración de Comisiones"
2. Ingresa el nuevo porcentaje (por defecto: 15%)
3. Guarda
4. El nuevo porcentaje aplica desde el siguiente pago procesado

---

## 8. Agregar un Nuevo Técnico

### Proceso de registro
El técnico debe:
1. Descargar la app ServiTec
2. Registrarse con su email (seleccionar "Soy técnico")
3. Completar su perfil con especialidades y disponibilidad

### Tu responsabilidad como admin
1. Panel → "Técnicos" → buscar al nuevo técnico
2. Verificar que los datos sean correctos
3. Asegurarte de que `activo = true` esté habilitado
4. Si tienes el Hito 9, revisar y aprobar sus documentos

---

## 9. Solución de Problemas Frecuentes (FAQ)

### ❓ Un servicio lleva horas como "Pendiente" sin técnico

**Causa probable:** No hay técnicos disponibles con esa especialidad.
**Solución:**
1. Revisar si hay técnicos con la categoría correcta en la lista de técnicos
2. Verificar que al menos uno tenga `disponible = true`
3. Asignar manualmente desde el detalle del servicio

---

### ❓ Un cliente dice que pagó pero el servicio sigue en "Completado" (no "Pagado")

**Causa probable:** El webhook de Stripe tardó en procesar.
**Solución:**
1. Esperar 5-10 minutos y refrescar
2. Si persiste, revisar el Dashboard de Stripe para confirmar el pago
3. Si el pago existe en Stripe pero no en Firestore, contactar al desarrollador

---

### ❓ Un técnico no recibe notificaciones push

**Causa probable:** El técnico cerró sesión o desinstaló la app.
**Solución:**
1. Pedirle que abra la app y vuelva a iniciar sesión
2. Asegurarse de que la app tenga permisos de notificación en el teléfono
3. El FCM token se actualiza automáticamente al iniciar sesión

---

### ❓ La app va lenta o tarda en cargar

**Causa probable:** Conexión de internet del dispositivo.
**Solución:**
1. Verificar conexión WiFi/datos móviles
2. Cerrar y volver a abrir la app
3. Si persiste, revisar el estado de Firebase en status.firebase.google.com

---

### ❓ Quiero ver el historial completo de un servicio específico

1. Buscar el servicio por nombre de cliente o ID
2. Tocar para ver el detalle
3. En el detalle verás: estado actual, historial de cambios, mensajes del chat, información del pago

---

## 10. Contactos de Soporte

| Servicio | Contacto |
|----------|---------|
| Soporte técnico app | JunJun Mabod (desarrollador) |
| Soporte Firebase | console.firebase.google.com |
| Soporte Stripe | dashboard.stripe.com → Support |
| Emergencias técnicas | WhatsApp al desarrollador |
