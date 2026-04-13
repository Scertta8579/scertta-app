-- ═══════════════════════════════════════════════════════════════════════════
-- Sesión única conductor, garaje multivehículo, foto perfil, radar (RPC)
-- ═══════════════════════════════════════════════════════════════════════════

-- ─── Perfiles: sesión activa + vehículo activo + avatar ─────────────────────
ALTER TABLE public.perfiles
  ADD COLUMN IF NOT EXISTS active_session_id uuid,
  ADD COLUMN IF NOT EXISTS active_session_device jsonb DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS active_session_at timestamptz,
  ADD COLUMN IF NOT EXISTS active_vehicle_id uuid,
  ADD COLUMN IF NOT EXISTS foto_perfil_url text;

COMMENT ON COLUMN public.perfiles.active_session_id IS 'Última sesión registrada; otros dispositivos deben cerrar sesión si no coincide.';
COMMENT ON COLUMN public.perfiles.active_session_device IS 'JSON: modelo, OS, etc. del último login.';
COMMENT ON COLUMN public.perfiles.active_vehicle_id IS 'Vehículo seleccionado para operar (FK a conductor_vehiculos).';

-- ─── Garaje del conductor ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.conductor_vehiculos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  perfil_id uuid NOT NULL REFERENCES public.perfiles (id) ON DELETE CASCADE,
  marca text NOT NULL,
  modelo text NOT NULL,
  anio integer NOT NULL CHECK (anio >= 1980 AND anio <= 2100),
  patente text NOT NULL,
  color text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT conductor_vehiculos_patente_perfil UNIQUE (perfil_id, patente)
);

CREATE INDEX IF NOT EXISTS idx_conductor_vehiculos_perfil ON public.conductor_vehiculos (perfil_id);

ALTER TABLE public.perfiles
  DROP CONSTRAINT IF EXISTS perfiles_active_vehicle_fkey;
ALTER TABLE public.perfiles
  ADD CONSTRAINT perfiles_active_vehicle_fkey
  FOREIGN KEY (active_vehicle_id) REFERENCES public.conductor_vehiculos (id) ON DELETE SET NULL;

CREATE OR REPLACE FUNCTION public.perfiles_active_vehicle_same_owner()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.active_vehicle_id IS NULL THEN
    RETURN NEW;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.conductor_vehiculos v
    WHERE v.id = NEW.active_vehicle_id AND v.perfil_id = NEW.id
  ) THEN
    RAISE EXCEPTION 'active_vehicle_id no pertenece a este perfil';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_perfiles_active_vehicle_owner ON public.perfiles;
CREATE TRIGGER trg_perfiles_active_vehicle_owner
  BEFORE INSERT OR UPDATE OF active_vehicle_id ON public.perfiles
  FOR EACH ROW
  EXECUTE FUNCTION public.perfiles_active_vehicle_same_owner();

-- ─── RPC: registrar sesión (un dispositivo invalida el anterior en servidor) ─
CREATE OR REPLACE FUNCTION public.register_driver_session(p_device jsonb)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid := gen_random_uuid();
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'No autenticado';
  END IF;

  UPDATE public.perfiles
  SET
    active_session_id = v_id,
    active_session_device = COALESCE(p_device, '{}'::jsonb),
    active_session_at = now()
  WHERE id = auth.uid()
    AND rol IN ('conductor', 'ceo');

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.register_driver_session(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.register_driver_session(jsonb) TO authenticated;

-- ─── RPC: vehículo activo (evita UPDATE amplio en perfiles si RLS lo bloquea) ─
CREATE OR REPLACE FUNCTION public.set_active_vehicle_for_driver(p_vehicle_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'No autenticado';
  END IF;
  IF p_vehicle_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.conductor_vehiculos v
    WHERE v.id = p_vehicle_id AND v.perfil_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Vehículo inválido o no pertenece al conductor';
  END IF;
  UPDATE public.perfiles
  SET active_vehicle_id = p_vehicle_id
  WHERE id = auth.uid();
END;
$$;

REVOKE ALL ON FUNCTION public.set_active_vehicle_for_driver(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.set_active_vehicle_for_driver(uuid) TO authenticated;

-- ─── RPC: URL pública de avatar (tras subir a Storage) ───────────────────────
CREATE OR REPLACE FUNCTION public.set_driver_profile_avatar_url(p_public_url text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'No autenticado';
  END IF;
  UPDATE public.perfiles
  SET foto_perfil_url = NULLIF(trim(p_public_url), '')
  WHERE id = auth.uid();
END;
$$;

REVOKE ALL ON FUNCTION public.set_driver_profile_avatar_url(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.set_driver_profile_avatar_url(text) TO authenticated;

-- ─── RLS conductor_vehiculos ─────────────────────────────────────────────────
ALTER TABLE public.conductor_vehiculos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "conductor_vehiculos_own_all" ON public.conductor_vehiculos;
CREATE POLICY "conductor_vehiculos_own_all"
  ON public.conductor_vehiculos
  FOR ALL
  TO authenticated
  USING (perfil_id = auth.uid())
  WITH CHECK (perfil_id = auth.uid());

DROP POLICY IF EXISTS "conductor_vehiculos_staff_select" ON public.conductor_vehiculos;
CREATE POLICY "conductor_vehiculos_staff_select"
  ON public.conductor_vehiculos
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.perfiles p
      WHERE p.id = auth.uid()
        AND p.rol IN ('ceo', 'operador', 'marketing')
    )
  );

-- ─── Solicitudes: direcciones legibles (opcional) ───────────────────────────
ALTER TABLE public.solicitudes_viaje
  ADD COLUMN IF NOT EXISTS direccion_origen text,
  ADD COLUMN IF NOT EXISTS direccion_destino text;

-- Lectura radar sin activar RLS en la tabla (no rompe inserts del solicitante / heatmaps)
CREATE OR REPLACE FUNCTION public.conductor_radar_solicitudes_pendientes()
RETURNS SETOF public.solicitudes_viaje
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT sv.*
  FROM public.solicitudes_viaje sv
  WHERE sv.estado = 'pendiente'
    AND auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM public.perfiles p
      WHERE p.id = auth.uid() AND p.rol IN ('conductor', 'ceo')
    )
  ORDER BY sv.created_at DESC
  LIMIT 50;
$$;

REVOKE ALL ON FUNCTION public.conductor_radar_solicitudes_pendientes() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.conductor_radar_solicitudes_pendientes() TO authenticated;

-- ─── Conductor: ver estado de sus documentos KYC ─────────────────────────────
DROP POLICY IF EXISTS "doc_val_select_own_driver" ON public.document_validations;
CREATE POLICY "doc_val_select_own_driver"
  ON public.document_validations
  FOR SELECT
  TO authenticated
  USING (driver_id = auth.uid());

-- ─── Bucket avatares ─────────────────────────────────────────────────────────
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'avatars',
  'avatars',
  true,
  5242880,
  ARRAY['image/jpeg', 'image/png', 'image/webp']::text[]
)
ON CONFLICT (id) DO UPDATE SET
  public = true,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "avatars_insert_own" ON storage.objects;
CREATE POLICY "avatars_insert_own"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'avatars'
    AND split_part(name, '/', 1) = auth.uid()::text
  );

DROP POLICY IF EXISTS "avatars_update_own" ON storage.objects;
CREATE POLICY "avatars_update_own"
  ON storage.objects FOR UPDATE TO authenticated
  USING (
    bucket_id = 'avatars'
    AND split_part(name, '/', 1) = auth.uid()::text
  )
  WITH CHECK (
    bucket_id = 'avatars'
    AND split_part(name, '/', 1) = auth.uid()::text
  );

DROP POLICY IF EXISTS "avatars_delete_own" ON storage.objects;
CREATE POLICY "avatars_delete_own"
  ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'avatars'
    AND split_part(name, '/', 1) = auth.uid()::text
  );

DROP POLICY IF EXISTS "avatars_select_public" ON storage.objects;
CREATE POLICY "avatars_select_public"
  ON storage.objects FOR SELECT TO public
  USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "avatars_select_staff" ON storage.objects;
CREATE POLICY "avatars_select_staff"
  ON storage.objects FOR SELECT TO authenticated
  USING (
    bucket_id = 'avatars'
    AND EXISTS (
      SELECT 1 FROM public.perfiles p
      WHERE p.id = auth.uid()
        AND p.rol IN ('ceo', 'operador', 'marketing')
    )
  );

-- Realtime: invalidación de sesión al cambiar active_session_id (idempotente)
DO $pub$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'perfiles'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.perfiles;
  END IF;
END $pub$;
