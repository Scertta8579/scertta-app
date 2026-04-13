# 🚀 Implementación Paso a Paso - Sistema VIP

## ⚡ Inicio Rápido (10 minutos)

### Paso 1: Aplicar Migración SQL (2 minutos)

1. Abre tu navegador
2. Ve a: https://supabase.com/dashboard
3. Selecciona tu proyecto: `cmuhwyxmluhnlzcasceq`
4. Click en **SQL Editor** en el menú izquierdo
5. Click en **New Query**
6. Abre el archivo: `flutter_app/supabase/migrations/003_planes_y_costos.sql`
7. **Selecciona TODO** el contenido (Ctrl+A)
8. **Copia** (Ctrl+C)
9. **Pega** en el editor SQL de Supabase (Ctrl+V)
10. Click en **Run** (o presiona Ctrl+Enter)
11. ✅ Debes ver: "Success. No rows returned"

**Si ves un error**:
- Lee el mensaje de error
- Verifica que copiaste TODO el archivo
- Asegúrate de que no haya caracteres extraños

### Paso 2: Verificar Tablas Creadas (2 minutos)

1. En Supabase Dashboard, click en **Table Editor**
2. Busca y verifica estas tablas:

**Tabla `costos_operativos`**:
- ✅ Debe tener 5 filas de ejemplo
- ✅ Columnas: id, servicio, costo_actual, costo_proyectado, estado, notas

**Tabla `documentos_validacion`**:
- ✅ Debe existir (puede estar vacía)
- ✅ Columnas: id, conductor_id, tipo_documento, url_documento, estado_validacion

**Tabla `perfiles`**:
- ✅ Debe tener nuevas columnas:
  - `plan_conductor`
  - `fecha_cambio_plan`
  - `fecha_ingreso`
  - `viajes_completados`
  - `calificacion_promedio`
  - `insignias`

### Paso 3: Configurar Supabase en Flutter (1 minuto)

1. Abre: `flutter_app/lib/config/supabase_config.dart`
2. Verifica que tengas:

```dart
class SupabaseConfig {
  static const String supabaseUrl = 'https://cmuhwyxmluhnlzcasceq.supabase.co';
  static const String anonKey = 'TU_ANON_KEY_AQUI'; // ← Pegar tu Anon Key
  static const String edgeFunctionBienvenida =
      'https://cmuhwyxmluhnlzcasceq.supabase.co/functions/v1/enviar-bienvenida';
}
```

**Si no tienes el Anon Key**:
1. Supabase Dashboard → Settings → API
2. Copia "anon public"
3. Pega en `anonKey`

### Paso 4: Ejecutar la App (5 minutos)

```bash
# Abrir terminal en la carpeta del proyecto
cd c:\Users\andre\Desktop\scertta-app\flutter_app

# Instalar dependencias (si no lo hiciste antes)
flutter pub get

# Ejecutar en emulador o dispositivo
flutter run
```

**Espera a que compile** (primera vez puede tardar 2-3 minutos)

---

## 🧪 Paso 5: Testing de Funcionalidades

### Test A: Registro y Verificación (3 minutos)

1. ✅ Login Screen se abre
2. Click en "Regístrate"
3. Completa formulario:
   - Nombre: `Test Usuario`
   - Email: `test@ejemplo.com`
   - Contraseña: `Test123456`
4. Click "Registrarse"
5. ✅ Verification Screen se abre
6. **Revisa tu email** (puede tardar 1-2 minutos)
7. Copia el código de 6 dígitos
8. Pégalo en la app
9. Click "Verificar Código"
10. ✅ CEO Home se abre con mapa visible

**Si no recibes el email**:
- Revisa spam/correo no deseado
- Click "Reenviar código" en la app
- Verifica que la Edge Function `enviar-bienvenida` esté desplegada

### Test B: Selección de Plan VIP (2 minutos)

**Requisito**: Debes estar logueado como conductor

1. Desde CEO Home (temporal), navega a Driver Home
   - **Nota**: Por ahora todos van a CEO Home, esto es temporal
2. Click en botón azul "MI PLAN DE TRABAJO"
3. ✅ Plan Selection Screen se abre
4. ✅ Ves 2 tarjetas: Comunidad y VIP
5. ✅ Plan Comunidad está marcado como actual
6. Scroll down para ver la comparación
7. Click en "Seleccionar Plan" del Plan VIP
8. ✅ SnackBar verde: "¡Bienvenido al Plan VIP! 🌟"
9. ✅ Tarjeta VIP ahora muestra "Plan Actual"

**Verificar en Supabase**:
```sql
SELECT nombre, email, plan_conductor 
FROM perfiles 
WHERE email = 'test@ejemplo.com';
```

Debe mostrar: `plan_conductor = 'vip'`

### Test C: Gestión Financiera (3 minutos)

**Requisito**: Debes estar logueado como CEO

1. CEO Home → Click en botón verde ($) inferior derecho
2. ✅ Gestión Financiera Screen se abre
3. ✅ Resumen financiero visible:
   - Costo Actual: \$53.000
   - Proyectado: \$64.500
   - Diferencia: +\$11.500 (rojo)
4. ✅ Tabla con 5 servicios visible
5. Scroll horizontal para ver todas las columnas
6. Click en icono de lápiz ✏️ de "Resend"
7. ✅ Dialog de edición se abre
8. Cambia "Costo Actual" a `6000`
9. Click "Guardar"
10. ✅ Tabla se actualiza
11. ✅ Resumen se recalcula: Costo Actual ahora es \$54.000

**Agregar Nuevo Servicio**:
1. Click en botón + en AppBar
2. Completa:
   - Servicio: `Google Cloud`
   - Costo Actual: `10000`
   - Proyectado: `12000`
   - Estado: `Activo`
   - Notas: `Hosting y CDN`
3. Click "Guardar"
4. ✅ Nuevo servicio aparece en tabla
5. ✅ Resumen actualizado

### Test D: Logros y Comunidad (1 minuto)

**Desde Driver Home**:
1. Swipe → desde el borde izquierdo (o click en ☰)
2. ✅ Drawer se abre
3. ✅ Sección de Logros visible en top:
   - 📅 "Llevas X en la comunidad Scertta"
   - 🚕 Viajes: 45
   - ⭐ Calificación: 4.8
   - 🎖️ Nivel: Intermedio
   - 🏅 Insignias visibles
4. Scroll down para ver opciones del menú
5. Click en "Mi Plan de Trabajo"
6. ✅ Navega a Plan Selection

**Desde Rider Home**:
1. Swipe → desde el borde izquierdo
2. ✅ Drawer se abre con logros de solicitante
3. ✅ Muestra viajes como pasajero

---

## 🔧 Paso 6: Configuración Avanzada (Opcional)

### Personalizar Planes

Edita: `lib/models/plan_conductor.dart`

```dart
static const PlanConductor vip = PlanConductor(
  id: 'vip',
  nombre: 'Plan VIP',
  comision: 0.0,
  costoSemanal: 25000, // ← Cambiar precio aquí
  descripcion: 'Para conductores profesionales...',
  beneficios: [
    // ← Agregar/quitar beneficios aquí
  ],
  esVip: true,
);
```

### Personalizar Niveles

Edita: `lib/models/logro_usuario.dart`

```dart
String get nivelConductor {
  if (viajesCompletados >= 1000) return 'Leyenda';
  if (viajesCompletados >= 500) return 'Maestro';
  if (viajesCompletados >= 200) return 'Experto';
  if (viajesCompletados >= 50) return 'Avanzado';
  if (viajesCompletados >= 10) return 'Intermedio';
  return 'Novato';
}
// ← Cambiar umbrales aquí
```

### Agregar Nuevos Servicios por Defecto

Edita: `supabase/migrations/003_planes_y_costos.sql`

```sql
INSERT INTO costos_operativos (servicio, costo_actual, costo_proyectado, estado, notas)
VALUES
  ('Tu Nuevo Servicio', 5000.00, 6000.00, 'activo', 'Descripción');
  -- ← Agregar más servicios aquí
```

Luego vuelve a ejecutar la migración.

---

## 🐛 Troubleshooting

### Problema 1: "Table costos_operativos does not exist"

**Causa**: La migración SQL no se aplicó.

**Solución**:
1. Ve a Supabase Dashboard → SQL Editor
2. Ejecuta:
```sql
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name = 'costos_operativos';
```
3. Si no retorna nada, vuelve a aplicar la migración completa

### Problema 2: App crashea al abrir Plan Selection

**Causa**: Ruta no configurada.

**Solución**:
1. Abre: `lib/main.dart`
2. Verifica que exista:
```dart
'/plan-selection': (context) => const PlanSelectionScreen(),
```
3. Si no existe, agrégala en el bloque `routes`
4. Hot reload: presiona `r` en el terminal

### Problema 3: "RLS policy violation"

**Causa**: El usuario no tiene permisos.

**Solución**:
1. Ve a Supabase Dashboard → SQL Editor
2. Ejecuta:
```sql
SELECT id, email, rol FROM perfiles WHERE email = 'tu_email@ejemplo.com';
```
3. Si el rol no es correcto, actualiza:
```sql
UPDATE perfiles SET rol = 'ceo' WHERE email = 'tu_email@ejemplo.com';
```

### Problema 4: Botón de Plan no aparece en Driver Home

**Causa**: Código no actualizado.

**Solución**:
1. Verifica que `driver_home.dart` tenga el botón:
```dart
ElevatedButton(
  onPressed: () {
    Navigator.pushNamed(context, '/plan-selection');
  },
  child: const Text('MI PLAN DE TRABAJO'),
)
```
2. Si no está, copia desde el archivo actualizado
3. Hot reload: presiona `r`

### Problema 5: Drawer no se abre

**Causa**: `scaffoldKey` no configurado.

**Solución**:
1. Verifica que el State tenga:
```dart
final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
```
2. Verifica que el Scaffold tenga:
```dart
return Scaffold(
  key: _scaffoldKey,
  drawer: _buildPerfilDrawer(user),
  // ...
);
```
3. Hot restart: presiona `R`

---

## 📊 Verificación de Datos

### Query 1: Ver Todos los Planes

```sql
SELECT 
  nombre,
  email,
  plan_conductor,
  fecha_cambio_plan
FROM perfiles
WHERE rol = 'conductor'
ORDER BY fecha_cambio_plan DESC;
```

**Resultado Esperado**:
```
nombre          | email              | plan_conductor | fecha_cambio_plan
----------------|--------------------|-----------------|-----------------
Juan Pérez      | juan@ejemplo.com   | vip            | 2026-03-08 15:30
María López     | maria@ejemplo.com  | comunidad      | 2026-03-07 10:15
```

### Query 2: Ver Costos Operativos

```sql
SELECT 
  servicio,
  costo_actual,
  costo_proyectado,
  estado
FROM costos_operativos
ORDER BY costo_actual DESC;
```

**Resultado Esperado**:
```
servicio        | costo_actual | costo_proyectado | estado
----------------|--------------|------------------|--------
Supabase Pro    | 25000.00     | 25000.00         | activo
Mapbox (Mapas)  | 12000.00     | 15000.00         | activo
Twilio SMS      | 8000.00      | 12000.00         | pausado
Resend (Emails) | 5000.00      | 8000.00          | activo
Amazon SES      | 3000.00      | 4500.00          | activo
```

### Query 3: Resumen Financiero

```sql
SELECT * FROM resumen_costos;
```

**Resultado Esperado**:
```
total_servicios | total_costo_actual | total_costo_proyectado | diferencia_total
----------------|--------------------|-----------------------|------------------
5               | 53000.00           | 64500.00              | 11500.00
```

### Query 4: Estadísticas de Conductores

```sql
SELECT 
  nombre,
  nivel_conductor,
  viajes_completados,
  calificacion_promedio
FROM estadisticas_conductores
ORDER BY viajes_completados DESC
LIMIT 10;
```

---

## 🎯 Casos de Uso Detallados

### Caso 1: Conductor Cambia a Plan VIP

**Contexto**: Juan es conductor, gana \$700.000/semana, quiere maximizar ganancias.

**Pasos Detallados**:

1. **Abrir App**
   ```
   flutter run
   ```

2. **Login**
   - Email: `juan@ejemplo.com`
   - Password: `Juan123456`
   - Click "Iniciar Sesión"

3. **Navegar a Driver Home**
   - Por ahora va a CEO Home (temporal)
   - En producción, irá directo a Driver Home según rol

4. **Abrir Plan Selection**
   - Click en botón azul "MI PLAN DE TRABAJO"
   - Pantalla de selección se abre

5. **Analizar Planes**
   - Ve Plan Comunidad: 5% comisión
   - Ve Plan VIP: \$25.000 fijo, 0% comisión
   - Scroll down para ver comparación

6. **Calcular Rentabilidad**
   - Gana \$700.000/semana
   - Plan Comunidad: Paga \$35.000 (5%)
   - Plan VIP: Paga \$25.000 fijo
   - **Ahorro: \$10.000/semana**

7. **Seleccionar VIP**
   - Click en "Seleccionar Plan" del Plan VIP
   - ✅ SnackBar: "¡Bienvenido al Plan VIP! 🌟"
   - ✅ Tarjeta VIP se marca como actual

8. **Verificar en Supabase**
   ```sql
   SELECT plan_conductor FROM perfiles WHERE email = 'juan@ejemplo.com';
   ```
   - Debe mostrar: `vip`

9. **Resultado**
   - Juan ahora paga \$25.000/semana fijo
   - 0% de comisión en todos los viajes
   - Ahorra \$40.000/mes

### Caso 2: CEO Actualiza Costos desde el Celular

**Contexto**: CEO recibe email de Mapbox: "Aumento de precios 25%". Está caminando por la calle.

**Pasos Detallados**:

1. **Sacar Celular del Bolsillo**
   - Desbloquear
   - Abrir Scertta

2. **Login (si no está logueado)**
   - Email: `ceo@scertta.com`
   - Password: `Ceo123456`
   - Click "Iniciar Sesión"

3. **CEO Home se Abre**
   - Mapa a pantalla completa visible
   - Panel de autorizaciones en top
   - Botones flotantes en bottom-right

4. **Abrir Gestión Financiera**
   - Click en botón verde ($) inferior derecho
   - Pantalla de gestión se abre

5. **Ver Tabla de Costos**
   - Resumen financiero en header
   - Tabla con 5 servicios
   - Scroll horizontal para ver todas las columnas

6. **Buscar Mapbox**
   - Scroll vertical si es necesario
   - Encuentra fila "Mapbox (Mapas)"
   - Costo Actual: \$12.000
   - Proyectado: \$15.000

7. **Editar Costo**
   - Click en icono de lápiz ✏️
   - Dialog se abre
   - Teclado numérico aparece automáticamente

8. **Actualizar Valores**
   - Costo Actual: `12000` (sin cambios)
   - Costo Proyectado: `18000` (cambiar de 15000)
   - Notas: Agregar "Aumento 25% marzo 2026"
   - Click "Guardar"

9. **Verificar Actualización**
   - ✅ Dialog se cierra
   - ✅ Tabla se actualiza
   - ✅ Resumen recalcula:
     - Total Proyectado: \$67.500 (antes \$64.500)
     - Diferencia: +\$14.500 (antes +\$11.500)
   - ✅ Alerta roja más intensa

10. **Tomar Decisión**
    - CEO ve el aumento
    - Decide: "Evaluar alternativas a Mapbox"
    - Puede agregar nota mental o crear tarea

11. **Volver al Mapa**
    - Click en botón ← en AppBar
    - Vuelve a CEO Home

**Tiempo Total**: 45 segundos ⚡

### Caso 3: Validación Automática de DNI

**Contexto**: María es conductora nueva, carga su DNI.

**Pasos Detallados**:

1. **Cargar Documento**
   - Driver Home → Menú (☰) → "Mis Documentos"
   - Click "Cargar DNI"
   - Selecciona foto del DNI desde galería
   - Click "Subir"

2. **Sistema Procesa (Automático)**
   ```
   IA extrae datos:
   - Nombre: "MARIA LOPEZ"
   - Apellido: "GARCIA"
   - DNI: "98765432"
   - Calidad: 95%
   ```

3. **Comparación con Formulario**
   ```
   Datos formulario:
   - Nombre: "María López García"
   - DNI: "98765432"
   
   Normalización:
   - "maria lopez garcia" ≈ "maria lopez garcia" ✅
   - "98765432" == "98765432" ✅
   - Calidad >= 70% ✅
   ```

4. **Resultado Automático**
   - ✅ Coincidencia: 100%
   - ✅ Estado: "Verificado"
   - ✅ No requiere revisión manual
   - ✅ María puede empezar a trabajar

5. **Verificar en Supabase**
   ```sql
   SELECT 
     tipo_documento,
     estado_validacion,
     coincidencia
   FROM documentos_validacion
   WHERE conductor_id = 'maria_user_id';
   ```
   
   Resultado:
   ```
   tipo_documento | estado_validacion | coincidencia
   ---------------|-------------------|-------------
   dni            | verificado        | 1.00
   ```

### Caso 4: Validación Manual con Observaciones

**Contexto**: Pedro carga DNI borroso.

**Pasos Detallados**:

1. **Pedro Carga Documento**
   - Driver Home → "Mis Documentos" → "Cargar DNI"
   - Selecciona foto borrosa
   - Click "Subir"

2. **Sistema Detecta Problema**
   ```
   IA extrae datos:
   - Calidad: 60% (< 70%) ❌
   - Algunos campos ilegibles
   ```

3. **Estado Automático**
   - ✅ Estado: "Pendiente"
   - ✅ Observación IA: "Calidad de imagen baja (60%)"
   - ✅ Requiere revisión manual

4. **Administrador Revisa**
   - CEO Home → "Autorizaciones Pendientes" → "Conductores"
   - Ve "Pedro Gómez - DNI Pendiente"
   - Click "Ver Documentos"

5. **Panel de Revisión se Abre**
   - ✅ Imagen del DNI visible
   - ✅ Análisis de IA: "Coincidencia: 60%"
   - ✅ Campo de observaciones vacío

6. **Administrador Agrega Observaciones**
   - Escribe: "Foto muy borrosa. Tomar nueva imagen con mejor luz natural. Asegurar que todos los datos sean legibles."
   - Click "Rechazar"

7. **Pedro Recibe Notificación**
   - "Tu DNI fue rechazado"
   - "Motivo: Foto muy borrosa. Tomar nueva imagen..."
   - Puede volver a cargar

8. **Pedro Carga Nueva Foto**
   - Toma foto con mejor luz
   - Calidad: 95% ✅
   - Sistema valida automáticamente
   - ✅ Estado: "Verificado"
   - ✅ Puede trabajar

---

## 📈 Monitoreo y Métricas

### Dashboard de Métricas (Futuro)

Puedes crear un dashboard en Supabase o Metabase con estas queries:

#### Métrica 1: Conversión a VIP

```sql
SELECT 
  COUNT(*) FILTER (WHERE plan_conductor = 'vip') * 100.0 / COUNT(*) as tasa_conversion_vip
FROM perfiles
WHERE rol = 'conductor';
```

**Meta**: 20% de conversión

#### Métrica 2: Ingresos por VIP

```sql
SELECT 
  COUNT(*) FILTER (WHERE plan_conductor = 'vip') as conductores_vip,
  COUNT(*) FILTER (WHERE plan_conductor = 'vip') * 25000 as ingreso_semanal,
  COUNT(*) FILTER (WHERE plan_conductor = 'vip') * 25000 * 4 as ingreso_mensual
FROM perfiles
WHERE rol = 'conductor';
```

#### Métrica 3: Distribución de Niveles

```sql
SELECT 
  nivel_conductor,
  COUNT(*) as cantidad,
  ROUND(AVG(calificacion_promedio), 2) as calificacion_promedio
FROM estadisticas_conductores
GROUP BY nivel_conductor
ORDER BY 
  CASE nivel_conductor
    WHEN 'Leyenda' THEN 1
    WHEN 'Maestro' THEN 2
    WHEN 'Experto' THEN 3
    WHEN 'Avanzado' THEN 4
    WHEN 'Intermedio' THEN 5
    WHEN 'Novato' THEN 6
  END;
```

#### Métrica 4: Eficiencia de Validación

```sql
SELECT 
  COUNT(*) as total_documentos,
  COUNT(*) FILTER (WHERE estado_validacion = 'verificado' AND coincidencia = 1.0) as auto_verificados,
  COUNT(*) FILTER (WHERE estado_validacion = 'pendiente') as pendientes,
  ROUND(
    COUNT(*) FILTER (WHERE estado_validacion = 'verificado' AND coincidencia = 1.0) * 100.0 / COUNT(*),
    2
  ) as porcentaje_automatico
FROM documentos_validacion;
```

**Meta**: 80% de documentos auto-verificados

---

## 🎯 Checklist de Implementación

### Antes de Lanzar a Producción

#### Base de Datos
- [ ] Migración SQL aplicada correctamente
- [ ] Tabla `costos_operativos` tiene datos de ejemplo
- [ ] Tabla `documentos_validacion` existe
- [ ] Columnas nuevas en `perfiles` creadas
- [ ] Políticas RLS funcionan correctamente
- [ ] Vistas y funciones SQL operativas

#### App Flutter
- [ ] Compila sin errores
- [ ] Todas las rutas configuradas
- [ ] Imports correctos en todos los archivos
- [ ] No hay warnings de linter
- [ ] Hot reload funciona

#### Funcionalidades
- [ ] Selección de plan funciona
- [ ] Gestión financiera accesible para CEO
- [ ] Logros visibles en Drawer
- [ ] Validación de documentos (simulada) funciona
- [ ] Navegación entre pantallas sin crashes

#### Testing
- [ ] Registro y verificación completos
- [ ] Login directo a CEO Home (temporal)
- [ ] Cambio de plan guarda en Supabase
- [ ] Edición de costos actualiza tabla
- [ ] Drawer se abre con swipe
- [ ] Todos los botones responden

#### Seguridad
- [ ] RLS habilitado en todas las tablas
- [ ] Solo CEO accede a gestión financiera
- [ ] Conductores solo ven sus propios documentos
- [ ] Tokens y keys en archivos de config (no hardcoded)

#### Documentación
- [ ] README actualizado
- [ ] Guías de uso creadas
- [ ] Diagramas de flujo disponibles
- [ ] Instrucciones de migración claras

---

## 🚀 Lanzamiento

### Fase 1: Beta Cerrada (1-2 semanas)

**Usuarios**: 10-20 conductores de confianza

**Objetivos**:
- Probar flujo de selección de plan
- Validar cálculo de comisiones
- Recoger feedback sobre UI/UX
- Ajustar precios si es necesario

**Métricas a Observar**:
- Tasa de conversión a VIP
- Tiempo promedio de validación de documentos
- Errores o crashes reportados
- Satisfacción de usuarios (encuesta)

### Fase 2: Beta Abierta (2-4 semanas)

**Usuarios**: 100-200 conductores

**Objetivos**:
- Escalar validación de documentos
- Probar carga del sistema
- Optimizar rendimiento
- Ajustar niveles y logros

**Métricas a Observar**:
- Ingresos por Plan VIP
- Retención de conductores
- Uso del dashboard financiero por CEO
- Tiempo de validación promedio

### Fase 3: Producción (Lanzamiento Completo)

**Usuarios**: Todos los conductores

**Objetivos**:
- Lanzamiento oficial
- Marketing del Plan VIP
- Integración con servicios reales de IA
- Sistema de pagos automáticos

**Métricas a Observar**:
- Ingresos totales
- Costos operativos vs proyectados
- NPS (Net Promoter Score)
- Churn rate

---

## 💡 Tips Finales

### Para el CEO

1. **Revisa Costos Semanalmente**
   - Abre Gestión Financiera cada lunes
   - Actualiza costos reales
   - Compara con proyecciones
   - Toma decisiones basadas en datos

2. **Monitorea Conversión a VIP**
   - Observa cuántos conductores eligen VIP
   - Si es < 15%, considera bajar el precio
   - Si es > 30%, considera subirlo

3. **Usa el Dashboard Móvil**
   - No necesitas estar en la oficina
   - Actualiza desde cualquier lugar
   - Toma decisiones rápidas

### Para Conductores

1. **Calcula Tu Rentabilidad**
   - Usa la comparación en Plan Selection
   - Considera tus ganancias semanales
   - Elige el plan que más te conviene

2. **Revisa Tus Logros**
   - Abre el Drawer regularmente
   - Ve tu progreso
   - Motívate con los niveles

3. **Mantén Documentos Actualizados**
   - Carga fotos de buena calidad
   - Verifica que todo sea legible
   - Evita rechazos

### Para el Equipo de Desarrollo

1. **Integra IA Real**
   - Reemplaza simulación con Google Vision o AWS Textract
   - Descomentar TODOs en `validacion_documentos_service.dart`
   - Probar con documentos reales

2. **Agrega Sistema de Pagos**
   - Integrar Mercado Pago para Argentina
   - Cobros automáticos semanales para VIP
   - Recordatorios antes del cobro

3. **Implementa Notificaciones**
   - Firebase Cloud Messaging
   - Notificar cambios de plan
   - Alertar sobre documentos rechazados
   - Celebrar logros alcanzados

---

## ✅ Resumen de 3 Pasos

1. **Aplicar Migración SQL** (2 minutos)
   - Supabase Dashboard → SQL Editor → Pegar y ejecutar

2. **Ejecutar App** (1 minuto)
   ```bash
   cd flutter_app
   flutter run
   ```

3. **Probar Funcionalidades** (5 minutos)
   - Selección de plan
   - Gestión financiera
   - Logros en drawer

**¡Listo para usar!** 🎉

---

## 📞 Próximos Pasos

### Ahora Mismo

```bash
cd flutter_app
flutter run
```

### En 1 Hora

- Aplicar migración SQL
- Probar todas las funcionalidades
- Reportar cualquier error

### En 1 Día

- Integrar con servicios reales de IA
- Configurar sistema de pagos
- Preparar para beta cerrada

### En 1 Semana

- Lanzar beta cerrada con 10 conductores
- Recoger feedback
- Ajustar precios y niveles

### En 1 Mes

- Lanzar beta abierta
- Escalar a 100+ conductores
- Optimizar rendimiento

---

**¡Éxito con Scertta!** 🚀✨
