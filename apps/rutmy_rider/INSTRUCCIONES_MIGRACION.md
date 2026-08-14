# 🚀 Instrucciones de Migración - Sistema VIP

## ⚡ Pasos Rápidos

### 1. Aplicar Migración SQL en Supabase

**Opción A: Dashboard Web (Recomendado)**

1. Ve a: https://supabase.com/dashboard
2. Selecciona tu proyecto: `TU_PROYECTO_REF`
3. Click en **SQL Editor** (menú izquierdo)
4. Click en **New Query**
5. Abre el archivo: `flutter_app/supabase/migrations/003_planes_y_costos.sql`
6. **Copia TODO el contenido** del archivo
7. **Pega** en el editor SQL de Supabase
8. Click en **Run** (o presiona Ctrl+Enter)
9. ✅ Verifica que aparezca: "Success. No rows returned"

**Opción B: Supabase CLI**

```bash
cd flutter_app
supabase db push
```

### 2. Verificar Tablas Creadas

En Supabase Dashboard → **Table Editor**:

- ✅ `costos_operativos` (debe tener 5 filas de ejemplo)
- ✅ `documentos_validacion` (vacía por ahora)
- ✅ `perfiles` (debe tener nuevas columnas: `plan_conductor`, `fecha_ingreso`, etc.)

### 3. Verificar Vistas y Funciones

En Supabase Dashboard → **Database** → **Views**:

- ✅ `resumen_costos`
- ✅ `estadisticas_conductores`

En **Functions**:

- ✅ `calcular_comision(monto_viaje, conductor_id)`

### 4. Ejecutar la App Flutter

```bash
cd flutter_app
flutter run
```

---

## 🧪 Testing Rápido

### Test 1: Plan VIP (2 minutos)

```
1. Login como conductor
2. Click "MI PLAN DE TRABAJO" (botón azul)
3. ✅ Se abre pantalla con 2 planes
4. Click "Seleccionar Plan" en VIP
5. ✅ SnackBar: "¡Bienvenido al Plan VIP! 🌟"
6. ✅ Tarjeta VIP marcada como seleccionada
```

**Verificar en Supabase**:
```sql
SELECT nombre, plan_conductor FROM perfiles WHERE rol = 'conductor';
```

Debe mostrar: `plan_conductor = 'vip'`

### Test 2: Gestión Financiera (2 minutos)

```
1. Login como CEO
2. Click botón verde ($) inferior derecho
3. ✅ Se abre pantalla con tabla de costos
4. ✅ Resumen muestra totales
5. Click en lápiz de "Resend"
6. Cambia "Costo Actual" a 6000
7. Click "Guardar"
8. ✅ Tabla actualizada
9. ✅ Resumen recalculado
```

### Test 3: Logros (1 minuto)

```
1. Login como conductor o rider
2. Click en menú (☰)
3. ✅ Drawer se abre
4. ✅ Sección de Logros visible
5. ✅ Muestra: "Llevas X meses en la comunidad Scertta"
6. ✅ Nivel y estadísticas visibles
```

---

## ⚠️ Troubleshooting

### Error: "relation costos_operativos does not exist"

**Causa**: La migración SQL no se aplicó correctamente.

**Solución**:
1. Ve a Supabase Dashboard → SQL Editor
2. Ejecuta:
```sql
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public';
```
3. Si no ves `costos_operativos`, vuelve a aplicar la migración

### Error: "column plan_conductor does not exist"

**Causa**: La columna no se agregó a la tabla `perfiles`.

**Solución**:
```sql
ALTER TABLE perfiles 
ADD COLUMN IF NOT EXISTS plan_conductor TEXT DEFAULT 'comunidad';
```

### Error: "RLS policy violation"

**Causa**: Las políticas de seguridad no permiten el acceso.

**Solución**:
1. Verifica que el usuario tenga rol 'ceo' en la tabla `perfiles`
2. Ejecuta:
```sql
SELECT id, email, rol FROM perfiles WHERE email = 'tu_email@ejemplo.com';
```
3. Si el rol no es 'ceo', actualiza:
```sql
UPDATE perfiles SET rol = 'ceo' WHERE email = 'tu_email@ejemplo.com';
```

### App Crashea al Abrir Plan Selection

**Causa**: Ruta no configurada en `main.dart`.

**Solución**:
Verifica que `main.dart` tenga:
```dart
routes: {
  '/plan-selection': (context) => const PlanSelectionScreen(),
  '/gestion-financiera': (context) => const GestionFinancieraScreen(),
}
```

---

## 📊 Verificación de Datos

### Consulta 1: Ver Planes de Conductores

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

### Consulta 2: Ver Costos Operativos

```sql
SELECT * FROM costos_operativos
ORDER BY costo_actual DESC;
```

### Consulta 3: Ver Resumen de Costos

```sql
SELECT * FROM resumen_costos;
```

### Consulta 4: Ver Estadísticas de Conductores

```sql
SELECT 
  nombre,
  nivel_conductor,
  viajes_completados,
  calificacion_promedio
FROM estadisticas_conductores
ORDER BY viajes_completados DESC;
```

---

## 🎯 Checklist Final

Antes de considerar completada la implementación:

- [ ] Migración SQL aplicada en Supabase
- [ ] Tabla `costos_operativos` tiene 5 filas de ejemplo
- [ ] Tabla `documentos_validacion` existe (puede estar vacía)
- [ ] Columnas nuevas en `perfiles` creadas
- [ ] Vistas `resumen_costos` y `estadisticas_conductores` funcionan
- [ ] Función `calcular_comision` existe
- [ ] App Flutter compila sin errores
- [ ] Ruta `/plan-selection` funciona
- [ ] Ruta `/gestion-financiera` funciona
- [ ] Drawer con logros se abre en Driver/Rider Home
- [ ] CEO puede editar costos desde móvil
- [ ] Conductor puede cambiar de plan

---

## 📞 Soporte

Si encuentras algún error:

1. **Revisa los logs** en la consola de Flutter:
```bash
flutter run --verbose
```

2. **Revisa los logs** en Supabase Dashboard → Logs

3. **Verifica la migración**:
```sql
SELECT * FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('costos_operativos', 'documentos_validacion');
```

---

**¡Todo listo para producción!** ✅
