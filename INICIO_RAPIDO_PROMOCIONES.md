# 🚀 Inicio Rápido - Gestor de Promociones Geográficas

## ⚡ Pasos para Empezar

### 1. Verificar Dependencias Instaladas ✅

Todas las dependencias ya están instaladas:
- ✅ `@mapbox/mapbox-gl-draw` v1.5.1
- ✅ `mapbox-gl` v3.19.1
- ✅ `react-map-gl` v8.1.0
- ✅ Tipos de TypeScript

### 2. Configurar Variables de Entorno

Asegúrate de tener estas variables en tu archivo `.env.local`:

```env
# Mapbox (requerido para el mapa)
NEXT_PUBLIC_MAPBOX_ACCESS_TOKEN=tu_token_de_mapbox_aqui

# Supabase (ya deberías tenerlas)
NEXT_PUBLIC_SUPABASE_URL=tu_url_de_supabase
NEXT_PUBLIC_SUPABASE_ANON_KEY=tu_key_de_supabase
```

**¿Dónde conseguir el token de Mapbox?**
1. Crea una cuenta en [mapbox.com](https://www.mapbox.com/)
2. Ve a tu Dashboard → Tokens
3. Copia el "Default public token" o crea uno nuevo
4. Pégalo en `.env.local`

### 3. Ejecutar Migración de Base de Datos

**Opción A: Usando Supabase Dashboard (Más Fácil)**

1. Ve a [app.supabase.com](https://app.supabase.com)
2. Selecciona tu proyecto
3. Ve a **Database** → **Extensions**
4. Habilita la extensión `postgis` (si no está habilitada)
5. Ve a **SQL Editor**
6. Copia y pega el contenido de:
   ```
   supabase/migrations/create_promociones_geograficas.sql
   ```
7. Haz clic en **Run** (Ctrl/Cmd + Enter)
8. Verifica que no haya errores

**Opción B: Usando Supabase CLI**

```bash
# Si tienes Supabase CLI instalado
supabase db push
```

### 4. Iniciar el Servidor de Desarrollo

```bash
npm run dev
```

### 5. Acceder al Gestor de Promociones

1. Abre tu navegador en `http://localhost:3000`
2. Inicia sesión con una cuenta que tenga rol `ceo`
3. Navega a `/ceo-dashboard`
4. ¡Verás el Gestor de Promociones Geográficas!

## 🎯 Crear tu Primera Promoción

### Paso 1: Dibujar la Zona
1. Haz clic en el botón **"Dibujar Polígono"**
2. Haz clic en el mapa para crear los puntos del polígono
3. Cierra el polígono haciendo clic en el primer punto

### Paso 2: Configurar la Promoción
1. Se abrirá automáticamente el panel de configuración
2. Completa los campos:
   - **Nombre**: ej. "Promo Microcentro Lunes"
   - **Descuento**: Usa el slider (ej. 20%)
   - **Horario Inicio**: ej. 08:00
   - **Horario Fin**: ej. 20:00
3. Activa el switch "Activar Promoción"
4. Haz clic en **"Guardar Promoción"**

### Paso 3: Verificar
1. La zona aparecerá en el mapa con color azul
2. Verás la promoción en la lista de "Promociones Activas"
3. El "Visualizador de Liquidez" se actualizará

## 🧪 Probar el Sistema

### Opción 1: Usar el Componente de Ejemplo

Puedes crear una página de prueba para verificar que todo funciona:

```typescript
// app/test-promociones/page.tsx
import EjemploIntegracionPromocion from "@/components/EjemploIntegracionPromocion";

export default function TestPromocionesPage() {
  return <EjemploIntegracionPromocion />;
}
```

Luego visita `http://localhost:3000/test-promociones`

### Opción 2: Integrar en Flujo de Viajes

```typescript
import { 
  verificarPromocionEnPunto,
  aplicarDescuentoPromocion 
} from "@/lib/promocionesGeograficas";

// En tu función de solicitud de viaje
async function calcularPrecioViaje(origenLat: number, origenLng: number, precioBase: number) {
  // Verificar si hay promoción activa
  const promocion = await verificarPromocionEnPunto(origenLat, origenLng);
  
  if (promocion) {
    // Aplicar descuento
    const precio = aplicarDescuentoPromocion(precioBase, promocion.porcentaje_descuento);
    
    console.log(`¡Promoción aplicada: ${promocion.nombre}!`);
    console.log(`Precio original: $${precio.precioOriginal}`);
    console.log(`Descuento: $${precio.descuento}`);
    console.log(`Precio final: $${precio.precioFinal}`);
    
    return precio.precioFinal;
  }
  
  return precioBase;
}
```

## 📍 Coordenadas de Prueba (Buenos Aires)

Para probar el sistema, puedes usar estas coordenadas:

| Zona | Latitud | Longitud |
|------|---------|----------|
| Microcentro | -34.603722 | -58.381592 |
| Palermo | -34.588 | -58.425 |
| Recoleta | -34.588 | -58.393 |
| Puerto Madero | -34.610 | -58.365 |
| Belgrano | -34.563 | -58.458 |

## 🔍 Verificar que Todo Funciona

### Checklist de Verificación

- [ ] El mapa se carga correctamente
- [ ] Puedes dibujar polígonos en el mapa
- [ ] El panel de configuración aparece al dibujar
- [ ] Puedes guardar una promoción
- [ ] La promoción aparece en el mapa
- [ ] Puedes activar/desactivar promociones
- [ ] El visualizador de liquidez muestra datos
- [ ] Puedes eliminar promociones

### Si algo no funciona:

1. **El mapa no se carga**
   - Verifica que `NEXT_PUBLIC_MAPBOX_ACCESS_TOKEN` esté configurado
   - Revisa la consola del navegador para errores

2. **Error al guardar promoción**
   - Verifica que la migración de base de datos se ejecutó correctamente
   - Revisa que PostGIS esté habilitado en Supabase

3. **No puedes acceder a /ceo-dashboard**
   - Verifica que tu usuario tenga rol `ceo` en la tabla `perfiles`

## 📚 Documentación Adicional

- **Documentación Completa**: `docs/PROMOCIONES_GEOGRAFICAS.md`
- **Instrucciones de Migración**: `docs/INSTRUCCIONES_MIGRACION.md`
- **Resumen del Proyecto**: `RESUMEN_PROMOCIONES_GEOGRAFICAS.md`

## 🎉 ¡Listo!

Tu sistema de Promociones Geográficas está completamente funcional. Ahora puedes:

✅ Crear zonas de alta demanda  
✅ Configurar descuentos automáticos  
✅ Monitorear el impacto financiero  
✅ Asegurar flujo de caja positivo  

## 💡 Consejos

1. **Empieza con descuentos pequeños** (5-10%) para probar el sistema
2. **Monitorea el visualizador de liquidez** constantemente
3. **Ajusta horarios** según patrones de demanda
4. **Crea múltiples promociones** para diferentes zonas y horarios
5. **Desactiva promociones** que no sean rentables

## 🆘 Soporte

Si encuentras problemas:
1. Revisa la consola del navegador (F12)
2. Revisa los logs de Supabase
3. Verifica las variables de entorno
4. Consulta la documentación en `docs/`

---

**¡Disfruta gestionando tus promociones geográficas!** 🚗💨
