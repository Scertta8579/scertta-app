-- Notificaciones in-app (marketing / sistema) para bandeja del conductor (y otros roles).
CREATE TABLE IF NOT EXISTS public.notificaciones_app (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  perfil_id uuid NOT NULL REFERENCES public.perfiles (id) ON DELETE CASCADE,
  titulo text NOT NULL,
  cuerpo text NOT NULL,
  tipo text NOT NULL CHECK (tipo IN ('marketing', 'sistema')),
  leida_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notificaciones_app_perfil_created
  ON public.notificaciones_app (perfil_id, created_at DESC);

ALTER TABLE public.notificaciones_app ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "notificaciones_app_select_own" ON public.notificaciones_app;
CREATE POLICY "notificaciones_app_select_own"
  ON public.notificaciones_app
  FOR SELECT
  TO authenticated
  USING (auth.uid() = perfil_id);

DROP POLICY IF EXISTS "notificaciones_app_update_own" ON public.notificaciones_app;
CREATE POLICY "notificaciones_app_update_own"
  ON public.notificaciones_app
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = perfil_id)
  WITH CHECK (auth.uid() = perfil_id);

COMMENT ON TABLE public.notificaciones_app IS 'Mensajes de marketing y sistema persistidos para la bandeja in-app.';
