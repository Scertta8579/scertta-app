-- Bucket privado para documentos de verificación del conductor (app sube a {auth.uid}/...).
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'conductor_verificacion',
  'conductor_verificacion',
  false,
  10485760,
  ARRAY['image/jpeg', 'image/png', 'image/webp']::text[]
)
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Políticas sobre storage.objects (RLS ya viene habilitado en Storage).

DROP POLICY IF EXISTS "conductor_verificacion_insert_own" ON storage.objects;
CREATE POLICY "conductor_verificacion_insert_own"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'conductor_verificacion'
    AND split_part(name, '/', 1) = auth.uid()::text
  );

DROP POLICY IF EXISTS "conductor_verificacion_update_own" ON storage.objects;
CREATE POLICY "conductor_verificacion_update_own"
  ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'conductor_verificacion'
    AND split_part(name, '/', 1) = auth.uid()::text
  )
  WITH CHECK (
    bucket_id = 'conductor_verificacion'
    AND split_part(name, '/', 1) = auth.uid()::text
  );

DROP POLICY IF EXISTS "conductor_verificacion_delete_own" ON storage.objects;
CREATE POLICY "conductor_verificacion_delete_own"
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'conductor_verificacion'
    AND split_part(name, '/', 1) = auth.uid()::text
  );

DROP POLICY IF EXISTS "conductor_verificacion_select_own" ON storage.objects;
CREATE POLICY "conductor_verificacion_select_own"
  ON storage.objects
  FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'conductor_verificacion'
    AND split_part(name, '/', 1) = auth.uid()::text
  );

-- Back-office: lectura de todos los objetos del bucket (roles staff en perfiles).
DROP POLICY IF EXISTS "conductor_verificacion_select_staff" ON storage.objects;
CREATE POLICY "conductor_verificacion_select_staff"
  ON storage.objects
  FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'conductor_verificacion'
    AND EXISTS (
      SELECT 1
      FROM public.perfiles p
      WHERE p.id = auth.uid()
        AND p.rol IN ('ceo', 'operador', 'marketing', 'admin')
    )
  );
