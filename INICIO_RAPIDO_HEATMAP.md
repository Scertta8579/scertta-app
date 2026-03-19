# 🚀 Inicio Rápido - Mapa de Calor y Sugerencias IA

## ⚡ Pasos para Empezar

### 1. Ejecutar Nueva Migración de Base de Datos

**En Supabase Dashboard:**

1. Ve a [app.supabase.com](https://app.supabase.com)
2. Selecciona tu proyecto
3. Ve a **SQL Editor**
4. Copia y pega el contenido de:
   ```
   supabase/migrations/create_heatmap_tables.sql
   ```
5. Haz clic en **Run** (Ctrl/Cmd + Enter)
6. Verifica que no haya errores

### 2. Generar Datos de Prueba (Opcional)

Para probar el sistema sin datos reales, ejecuta en SQL Editor:

```sql
SELECT generar_datos_prueba_heatmap();
```

Esto creará:
- ✅ 15 solicitudes de viaje en Microcentro
- ✅ 8 solicitudes de viaje en Palermo
- ✅ 3 conductores disponibles en Microcentro
- ✅ 5 conductores disponibles en Palermo

### 3. Verificar Instalación

Ejecuta esta consulta para verificar que todo funciona:

```sql
-- Verificar datos del heatmap
SELECT * FROM obtener_datos_heatmap(60);

-- Verificar análisis de zonas
SELECT * FROM analizar_zonas_demanda(1000, 60);

-- Verificar sugerencias
SELECT * FROM obtener_sugerencias_promociones();
```

### 4. Usar el Mapa de Calor

1. Accede a `http://localhost:3000/ceo-dashboard`
2. Haz clic en **"Mostrar Mapa de Calor"** (botón naranja con 🔥)
3. Verás el mapa coloreado según la demanda:
   - 🔴 Rojo = Alta demanda
   - 🟠 Naranja = Demanda moderada
   - 🟢 Verde = Equilibrado

### 5. Obtener Sugerencias Inteligentes

1. Haz clic en **"Sugerir Promo"** (botón morado con ✨)
2. El sistema analizará automáticamente:
   - Solicitudes de la última hora
   - Conductores disponibles
   - Ratio demanda/oferta
3. Verás un panel con las top 5 zonas que necesitan promociones

### 6. Aplicar una Sugerencia

1. Revisa las sugerencias en el panel
2. Lee la justificación (ej: "Zona crítica con 15 solicitudes y solo 3 conductores")
3. Haz clic en **"Crear Promoción con X%"**
4. El sistema automáticamente:
   - ✅ Dibuja la zona en el mapa
   - ✅ Pre-llena el nombre (ej: "Promo Microcentro")
   - ✅ Pre-llena el descuento sugerido (ej: 25%)
5. Ajusta horarios si es necesario
6. Activa el switch y guarda

## 🎯 Ejemplo Completo

### Escenario: Alta Demanda en Microcentro

```
1. Activar Mapa de Calor
   → Click en "Mostrar Mapa de Calor"
   → Microcentro aparece en rojo intenso

2. Analizar Sugerencias
   → Click en "Sugerir Promo"
   → Sistema muestra:
     • Barrio: Microcentro
     • Solicitudes: 15
     • Conductores: 3
     • Ratio: 5:1
     • Urgencia: CRÍTICO
     • Descuento sugerido: 25%
     • Justificación: "Zona crítica con 15 solicitudes y solo 3 conductores..."

3. Aplicar Sugerencia
   → Click en "Crear Promoción con 25%"
   → Formulario se abre pre-llenado:
     • Nombre: "Promo Microcentro"
     • Descuento: 25%
   → Ajustar horarios: 08:00 - 20:00
   → Activar switch
   → Guardar

4. Resultado
   → Promoción activa en el mapa (zona azul)
   → Conductores reciben notificación
   → Más conductores se dirigen a Microcentro
   → Demanda se equilibra
```

## 🔍 Verificar que Funciona

### Checklist de Verificación

- [ ] Las tablas `solicitudes_viaje` y `conductores_disponibles` existen
- [ ] Las funciones RPC están disponibles
- [ ] El botón "Mostrar Mapa de Calor" aparece
- [ ] El mapa de calor se renderiza correctamente
- [ ] El botón "Sugerir Promo" aparece
- [ ] Las sugerencias se generan correctamente
- [ ] Puedes aplicar una sugerencia con 1 click

### Si algo no funciona:

**El mapa de calor no aparece:**
- Verifica que la migración se ejecutó correctamente
- Revisa que haya datos en `solicitudes_viaje`
- Genera datos de prueba con `generar_datos_prueba_heatmap()`

**No hay sugerencias:**
- Verifica que haya solicitudes recientes (última hora)
- Verifica que haya conductores en `conductores_disponibles`
- Genera datos de prueba

**Error al aplicar sugerencia:**
- Verifica que el token de Mapbox esté configurado
- Revisa la consola del navegador para errores

## 📊 Entender los Colores del Heatmap

| Color | Significado | Acción Recomendada |
|-------|-------------|-------------------|
| 🔴 Rojo Intenso | Demanda crítica (ratio > 3:1) | Activar promoción 25% |
| 🟠 Naranja | Alta demanda (ratio > 2:1) | Activar promoción 20% |
| 🟡 Amarillo | Demanda moderada (ratio > 1:1) | Considerar promoción 15% |
| 🟢 Verde | Equilibrado (ratio ≤ 1:1) | No se necesita acción |
| 🔵 Azul | Baja demanda | No se necesita acción |

## 🧪 Comandos Útiles para Pruebas

### Limpiar Datos de Prueba
```sql
DELETE FROM solicitudes_viaje WHERE created_at > NOW() - INTERVAL '2 hours';
DELETE FROM conductores_disponibles;
```

### Ver Datos del Heatmap
```sql
SELECT * FROM obtener_datos_heatmap(60);
```

### Ver Análisis de Zonas
```sql
SELECT 
  zona_lat,
  zona_lng,
  solicitudes_count,
  conductores_count,
  ratio_demanda,
  nivel_urgencia,
  sugerencia_descuento
FROM analizar_zonas_demanda(1000, 60);
```

### Ver Sugerencias
```sql
SELECT 
  barrio,
  solicitudes,
  conductores,
  ratio,
  urgencia,
  descuento_sugerido,
  justificacion
FROM obtener_sugerencias_promociones();
```

## 🔄 Actualización Automática

El heatmap se actualiza automáticamente cada 30 segundos cuando está activo. Para ver la actualización:

1. Activa el mapa de calor
2. Inserta nuevas solicitudes en la base de datos
3. Espera 30 segundos
4. El mapa se actualizará automáticamente

## 💡 Consejos Pro

1. **Activa el heatmap solo cuando lo necesites** para ahorrar recursos
2. **Genera datos de prueba** antes de presentar el sistema
3. **Usa las sugerencias como guía**, pero ajusta según tu conocimiento del mercado
4. **Monitorea el visualizador de liquidez** después de activar promociones
5. **Desactiva promociones** que no estén funcionando

## 📚 Documentación Completa

- **Documentación Detallada**: `docs/HEATMAP_Y_SUGERENCIAS.md`
- **Arquitectura**: `docs/ARQUITECTURA_PROMOCIONES.md`
- **Migración**: `supabase/migrations/create_heatmap_tables.sql`

## 🎉 ¡Listo para Usar!

Tu sistema de Mapa de Calor y Sugerencias Inteligentes está completamente funcional. Ahora puedes:

✅ Visualizar demanda en tiempo real  
✅ Identificar zonas críticas automáticamente  
✅ Recibir sugerencias inteligentes de promociones  
✅ Aplicar promociones con 1 click  
✅ Equilibrar oferta y demanda eficientemente  

---

**¡Optimiza tu operación con inteligencia artificial!** 🚀
