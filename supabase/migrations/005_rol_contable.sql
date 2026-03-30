-- ============================================
-- MIGRACIÓN 005: Agregar Rol 'Contable' y Tablas de Libro de Números
-- ============================================
--
-- Esta migración implementa la Fase 1 de la PWA Contable (Libro de Números):
--   1. Agrega el rol 'contable' y 'admin' al constraint de perfiles
--   2. Crea tablas ingresos_plataforma y egresos_plataforma
--   3. Define RLS policies (solo ceo y contable pueden leer/escribir)
--
-- Autor: CTO Agent (Paperclip SCE-9)
-- Fecha: 2026-03-30

-- ============================================
-- 1. Actualizar constraint de rol en tabla perfiles
--    Agrega 'contable' y corrige la ausencia de 'admin'
-- ============================================
ALTER TABLE perfiles
DROP CONSTRAINT IF EXISTS perfiles_rol_check;

ALTER TABLE perfiles
ADD CONSTRAINT perfiles_rol_check
CHECK (rol IN ('ceo', 'operador', 'admin', 'marketing', 'contable', 'solicitante', 'conductor'));

-- ============================================
-- 2. Tabla ingresos_plataforma
-- ============================================
CREATE TABLE IF NOT EXISTS ingresos_plataforma (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  monto       NUMERIC(14, 2) NOT NULL,
  categoria   TEXT NOT NULL,
  descripcion TEXT,
  fecha       DATE NOT NULL DEFAULT CURRENT_DATE,
  region_id   UUID,
  creado_por  UUID REFERENCES auth.users(id),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE ingresos_plataforma ENABLE ROW LEVEL SECURITY;

-- RLS: solo ceo y contable pueden SELECT
CREATE POLICY "CEO y Contable pueden ver ingresos"
ON ingresos_plataforma
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM perfiles
    WHERE id = auth.uid()
    AND rol IN ('ceo', 'contable')
  )
);

-- RLS: solo ceo y contable pueden INSERT
CREATE POLICY "CEO y Contable pueden crear ingresos"
ON ingresos_plataforma
FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM perfiles
    WHERE id = auth.uid()
    AND rol IN ('ceo', 'contable')
  )
);

-- RLS: solo ceo y contable pueden UPDATE
CREATE POLICY "CEO y Contable pueden editar ingresos"
ON ingresos_plataforma
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM perfiles
    WHERE id = auth.uid()
    AND rol IN ('ceo', 'contable')
  )
);

-- RLS: solo ceo y contable pueden DELETE
CREATE POLICY "CEO y Contable pueden eliminar ingresos"
ON ingresos_plataforma
FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM perfiles
    WHERE id = auth.uid()
    AND rol IN ('ceo', 'contable')
  )
);

-- Trigger updated_at
CREATE TRIGGER update_ingresos_plataforma_updated_at
BEFORE UPDATE ON ingresos_plataforma
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- Índices
CREATE INDEX IF NOT EXISTS idx_ingresos_fecha       ON ingresos_plataforma(fecha);
CREATE INDEX IF NOT EXISTS idx_ingresos_categoria   ON ingresos_plataforma(categoria);
CREATE INDEX IF NOT EXISTS idx_ingresos_region_id   ON ingresos_plataforma(region_id);
CREATE INDEX IF NOT EXISTS idx_ingresos_creado_por  ON ingresos_plataforma(creado_por);

COMMENT ON TABLE ingresos_plataforma IS 'Registro de ingresos de la plataforma Scertta (Libro de Números - Fase 1)';

-- ============================================
-- 3. Tabla egresos_plataforma
-- ============================================
CREATE TABLE IF NOT EXISTS egresos_plataforma (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  monto       NUMERIC(14, 2) NOT NULL,
  categoria   TEXT NOT NULL,
  descripcion TEXT,
  fecha       DATE NOT NULL DEFAULT CURRENT_DATE,
  region_id   UUID,
  creado_por  UUID REFERENCES auth.users(id),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE egresos_plataforma ENABLE ROW LEVEL SECURITY;

-- RLS: solo ceo y contable pueden SELECT
CREATE POLICY "CEO y Contable pueden ver egresos"
ON egresos_plataforma
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM perfiles
    WHERE id = auth.uid()
    AND rol IN ('ceo', 'contable')
  )
);

-- RLS: solo ceo y contable pueden INSERT
CREATE POLICY "CEO y Contable pueden crear egresos"
ON egresos_plataforma
FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM perfiles
    WHERE id = auth.uid()
    AND rol IN ('ceo', 'contable')
  )
);

-- RLS: solo ceo y contable pueden UPDATE
CREATE POLICY "CEO y Contable pueden editar egresos"
ON egresos_plataforma
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM perfiles
    WHERE id = auth.uid()
    AND rol IN ('ceo', 'contable')
  )
);

-- RLS: solo ceo y contable pueden DELETE
CREATE POLICY "CEO y Contable pueden eliminar egresos"
ON egresos_plataforma
FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM perfiles
    WHERE id = auth.uid()
    AND rol IN ('ceo', 'contable')
  )
);

-- Trigger updated_at
CREATE TRIGGER update_egresos_plataforma_updated_at
BEFORE UPDATE ON egresos_plataforma
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- Índices
CREATE INDEX IF NOT EXISTS idx_egresos_fecha       ON egresos_plataforma(fecha);
CREATE INDEX IF NOT EXISTS idx_egresos_categoria   ON egresos_plataforma(categoria);
CREATE INDEX IF NOT EXISTS idx_egresos_region_id   ON egresos_plataforma(region_id);
CREATE INDEX IF NOT EXISTS idx_egresos_creado_por  ON egresos_plataforma(creado_por);

COMMENT ON TABLE egresos_plataforma IS 'Registro de egresos de la plataforma Scertta (Libro de Números - Fase 1)';

-- ============================================
-- FIN DE MIGRACIÓN 005
-- ============================================

-- Para aplicar esta migración:
-- 1. Copia este archivo al SQL Editor de Supabase Dashboard
-- 2. Ejecuta y verifica que no haya errores
-- 3. Opcionalmente crea un usuario con rol 'contable' para testing:
--    INSERT INTO perfiles (id, email, nombre, rol)
--    VALUES ('USER_ID_AQUI', 'contable@scertta.com', 'Contable', 'contable');
