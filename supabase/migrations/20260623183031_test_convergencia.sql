-- test_convergencia: Tabla de prueba para pipeline DDL + recuperación post-apagón
-- Creada via migrate.sh (Local-First) para demostrar paridad Cloud ↔ Local
CREATE TABLE IF NOT EXISTS public.test_convergencia (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  origen text NOT NULL DEFAULT 'cloud',    -- 'cloud' o 'local' — dónde se insertó
  mensaje text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- RLS: Permitir inserts anónimos para prueba de apagón
ALTER TABLE public.test_convergencia ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "test_convergencia_insert_all" ON public.test_convergencia;
CREATE POLICY "test_convergencia_insert_all"
  ON public.test_convergencia FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

DROP POLICY IF EXISTS "test_convergencia_select_all" ON public.test_convergencia;
CREATE POLICY "test_convergencia_select_all"
  ON public.test_convergencia FOR SELECT
  TO anon, authenticated
  USING (true);

COMMENT ON TABLE public.test_convergencia IS 'Tabla de prueba para validar pipeline DDL y recuperación post-apagón.';
