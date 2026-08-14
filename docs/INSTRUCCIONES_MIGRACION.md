# Instrucciones para Migración de Base de Datos - Promociones Geográficas

## Prerequisitos

1. Tener acceso al proyecto de Supabase
2. Tener instalado Supabase CLI (opcional) o acceso al Dashboard web
3. Extensión PostGIS habilitada en tu base de datos

## Opción 1: Usando Supabase Dashboard (Recomendado)

### Paso 1: Habilitar PostGIS
1. Ve a tu proyecto en [Supabase Dashboard](https://app.supabase.com)
2. Navega a **Database** → **Extensions**
3. Busca `postgis` y habilítala
4. Espera a que se complete la instalación

### Paso 2: Ejecutar la Migración
1. Ve a **SQL Editor** en el menú lateral
2. Haz clic en **New Query**
3. Copia y pega el contenido del archivo:
   ```
   supabase/migrations/create_promociones_geograficas.sql
   ```
4. Haz clic en **Run** (o presiona `Ctrl/Cmd + Enter`)
5. Verifica que no haya errores en la consola

### Paso 3: Verificar la Instalación
Ejecuta la siguiente consulta para verificar que las tablas se crearon correctamente:

```sql
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('promociones_geograficas', 'metricas_promociones');
```

Deberías ver ambas tablas listadas.

## Opción 2: Usando Supabase CLI

### Paso 1: Instalar Supabase CLI
```bash
npm install -g supabase
```

### Paso 2: Login
```bash
supabase login
```

### Paso 3: Link al Proyecto
```bash
supabase link --project-ref tu-project-ref
```

### Paso 4: Ejecutar Migración
```bash
supabase db push
```

## Verificación de Funciones

Después de ejecutar la migración, verifica que la función RPC esté disponible:

```sql
SELECT routine_name 
FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND routine_name = 'verificar_promocion_en_punto';
```

## Probar la Función

Puedes probar la función con esta consulta:

```sql
SELECT * FROM verificar_promocion_en_punto(
  -34.603722,  -- latitud (Microcentro)
  -58.381592,  -- longitud
  '14:00:00'   -- hora actual
);
```

Si no hay promociones creadas aún, la consulta no devolverá resultados (esto es normal).

## Troubleshooting

### Error: "extension postgis does not exist"
**Solución**: Habilita la extensión PostGIS primero (ver Paso 1 de Opción 1)

### Error: "permission denied for schema public"
**Solución**: Asegúrate de estar usando las credenciales correctas con permisos de administrador

### Error: "function st_dwithin does not exist"
**Solución**: PostGIS no está correctamente instalado. Reinstala la extensión.

## Rollback (Deshacer Migración)

Si necesitas deshacer la migración, ejecuta:

```sql
-- Eliminar tablas
DROP TABLE IF EXISTS metricas_promociones CASCADE;
DROP TABLE IF EXISTS promociones_geograficas CASCADE;

-- Eliminar funciones
DROP FUNCTION IF EXISTS verificar_promocion_en_punto;
DROP FUNCTION IF EXISTS update_updated_at_column;
```

## Próximos Pasos

Una vez completada la migración:

1. ✅ Verifica que las tablas existan
2. ✅ Verifica que las funciones estén disponibles
3. ✅ Configura las políticas de seguridad (RLS) si es necesario
4. ✅ Accede al CEO Dashboard y crea tu primera promoción

## Políticas de Seguridad (Row Level Security)

Si deseas habilitar RLS para mayor seguridad, ejecuta:

```sql
-- Habilitar RLS
ALTER TABLE promociones_geograficas ENABLE ROW LEVEL SECURITY;
ALTER TABLE metricas_promociones ENABLE ROW LEVEL SECURITY;

-- Política para CEO (puede hacer todo)
CREATE POLICY "CEO puede gestionar promociones"
ON promociones_geograficas
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM perfiles
    WHERE perfiles.id = auth.uid()
    AND perfiles.rol = 'ceo'
  )
);

-- Política para lectura pública (necesario para verificar promociones)
CREATE POLICY "Todos pueden leer promociones activas"
ON promociones_geograficas
FOR SELECT
TO authenticated
USING (activa = true);

-- Política para métricas (solo CEO)
CREATE POLICY "CEO puede ver métricas"
ON metricas_promociones
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM perfiles
    WHERE perfiles.id = auth.uid()
    AND perfiles.rol = 'ceo'
  )
);
```

## Soporte

Si encuentras problemas durante la migración, verifica:
- Logs de Supabase en el Dashboard
- Permisos de tu usuario
- Versión de PostgreSQL (debe ser 12+)
- Extensión PostGIS habilitada
