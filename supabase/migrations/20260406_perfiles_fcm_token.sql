-- Tokens FCM para push (apps conductor / solicitante)
-- Ejecutar en Supabase SQL Editor o vía CLI migrate.

ALTER TABLE public.perfiles
  ADD COLUMN IF NOT EXISTS fcm_token TEXT,
  ADD COLUMN IF NOT EXISTS fcm_token_updated_at TIMESTAMPTZ;

COMMENT ON COLUMN public.perfiles.fcm_token IS 'Token Firebase Cloud Messaging del dispositivo (último registrado).';
COMMENT ON COLUMN public.perfiles.fcm_token_updated_at IS 'Última vez que el cliente actualizó el token FCM.';

-- La app solo hace UPDATE de su propia fila (id = auth.uid()).
-- Si aún no tenés política que permita UPDATE al dueño del perfil, descomentá:
--
-- CREATE POLICY "perfiles_update_own_fcm"
-- ON public.perfiles
-- FOR UPDATE
-- TO authenticated
-- USING (id = auth.uid())
-- WITH CHECK (id = auth.uid());
