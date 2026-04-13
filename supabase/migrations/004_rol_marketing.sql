-- ============================================
-- MIGRACIÓN 004: Agregar Rol 'Marketing'
-- ============================================
-- 
-- Esta migración agrega el rol 'marketing' al esquema
-- y crea vistas y permisos específicos para este rol
--
-- Autor: Scertta Dev Team
-- Fecha: 2026-03-08

-- 1. Actualizar constraint de rol en tabla perfiles para incluir 'marketing'
ALTER TABLE perfiles
DROP CONSTRAINT IF EXISTS perfiles_rol_check;

ALTER TABLE perfiles
ADD CONSTRAINT perfiles_rol_check 
CHECK (rol IN ('ceo', 'operador', 'marketing', 'solicitante', 'conductor'));

-- 2. Crear vista para métricas de marketing
CREATE OR REPLACE VIEW metricas_marketing AS
SELECT 
  -- Métricas de usuarios
  COUNT(DISTINCT CASE WHEN rol = 'solicitante' THEN id END) as total_solicitantes,
  COUNT(DISTINCT CASE WHEN rol = 'conductor' THEN id END) as total_conductores,
  COUNT(DISTINCT id) as total_usuarios,
  
  -- Métricas de actividad (últimos 7 días)
  COUNT(DISTINCT CASE 
    WHEN rol = 'solicitante' 
    AND created_at >= NOW() - INTERVAL '7 days' 
    THEN id 
  END) as nuevos_solicitantes_7d,
  
  COUNT(DISTINCT CASE 
    WHEN rol = 'conductor' 
    AND created_at >= NOW() - INTERVAL '7 days' 
    THEN id 
  END) as nuevos_conductores_7d,
  
  -- Métricas de planes (conductores)
  COUNT(DISTINCT CASE WHEN plan_conductor = 'comunidad' THEN id END) as conductores_comunidad,
  COUNT(DISTINCT CASE WHEN plan_conductor = 'vip' THEN id END) as conductores_vip,
  
  -- Fecha de actualización
  NOW() as fecha_actualizacion
FROM perfiles;

-- 3. Crear vista para datos de contacto (para envío de emails)
CREATE OR REPLACE VIEW contactos_marketing AS
SELECT 
  id,
  email,
  nombre,
  rol,
  created_at as fecha_registro,
  CASE 
    WHEN created_at >= NOW() - INTERVAL '7 days' THEN 'nuevo'
    WHEN created_at >= NOW() - INTERVAL '30 days' THEN 'reciente'
    ELSE 'establecido'
  END as segmento
FROM perfiles
WHERE email IS NOT NULL
ORDER BY created_at DESC;

-- 4. Políticas de seguridad (RLS) para rol marketing

-- Marketing puede ver métricas
CREATE POLICY "Marketing puede ver métricas"
ON perfiles
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM perfiles
    WHERE id = auth.uid()
    AND rol IN ('ceo', 'marketing')
  )
);

-- 5. Crear tabla de campañas de marketing (opcional)
CREATE TABLE IF NOT EXISTS campanas_marketing (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  nombre TEXT NOT NULL,
  descripcion TEXT,
  tipo TEXT NOT NULL CHECK (tipo IN ('email', 'push', 'sms', 'promo')),
  segmento_objetivo TEXT, -- 'nuevo', 'reciente', 'establecido', 'todos'
  estado TEXT NOT NULL DEFAULT 'borrador' CHECK (estado IN ('borrador', 'activa', 'pausada', 'finalizada')),
  fecha_inicio TIMESTAMPTZ,
  fecha_fin TIMESTAMPTZ,
  creado_por UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Trigger para updated_at
CREATE TRIGGER update_campanas_marketing_updated_at
BEFORE UPDATE ON campanas_marketing
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- RLS para campañas
ALTER TABLE campanas_marketing ENABLE ROW LEVEL SECURITY;

CREATE POLICY "CEO y Marketing pueden ver campañas"
ON campanas_marketing
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM perfiles
    WHERE id = auth.uid()
    AND rol IN ('ceo', 'marketing')
  )
);

CREATE POLICY "CEO y Marketing pueden crear campañas"
ON campanas_marketing
FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM perfiles
    WHERE id = auth.uid()
    AND rol IN ('ceo', 'marketing')
  )
);

CREATE POLICY "CEO y Marketing pueden editar campañas"
ON campanas_marketing
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM perfiles
    WHERE id = auth.uid()
    AND rol IN ('ceo', 'marketing')
  )
);

-- 6. Comentarios para documentación
COMMENT ON TABLE campanas_marketing IS 'Campañas de marketing para envío de emails y promociones';
COMMENT ON VIEW metricas_marketing IS 'Vista con métricas agregadas para el equipo de marketing';
COMMENT ON VIEW contactos_marketing IS 'Vista con contactos segmentados para campañas de marketing';

-- 7. Índices para optimización
CREATE INDEX IF NOT EXISTS idx_perfiles_rol ON perfiles(rol);
CREATE INDEX IF NOT EXISTS idx_perfiles_created_at ON perfiles(created_at);
CREATE INDEX IF NOT EXISTS idx_campanas_estado ON campanas_marketing(estado);
CREATE INDEX IF NOT EXISTS idx_campanas_tipo ON campanas_marketing(tipo);

-- ============================================
-- FIN DE MIGRACIÓN 004
-- ============================================

-- Para aplicar esta migración:
-- 1. Copia este archivo a tu proyecto Supabase
-- 2. Ejecuta en SQL Editor de Supabase Dashboard
-- 3. Verifica que no haya errores
-- 4. Crea un usuario de prueba con rol 'marketing'

-- Ejemplo de usuario marketing:
-- INSERT INTO perfiles (id, email, nombre, rol)
-- VALUES ('USER_ID_AQUI', 'marketing@scertta.com', 'Marketing Team', 'marketing');
