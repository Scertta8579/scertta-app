-- Pánico / emergencias, tipo de vehículo operativo y marca temporal de fin de viaje (objetos perdidos).
ALTER TABLE public.perfiles
  ADD COLUMN IF NOT EXISTS contactos_emergencia jsonb NOT NULL DEFAULT '[]'::jsonb;

ALTER TABLE public.perfiles
  ADD COLUMN IF NOT EXISTS tipo_vehiculo_operativo text;

ALTER TABLE public.perfiles
  ADD COLUMN IF NOT EXISTS ultimo_viaje_finalizado_at timestamptz;

COMMENT ON COLUMN public.perfiles.contactos_emergencia IS 'Array JSON de teléfonos (strings) para envío de ubicación en pánico.';
COMMENT ON COLUMN public.perfiles.tipo_vehiculo_operativo IS 'auto | moto | camioneta — filtro de oferta de viajes.';
COMMENT ON COLUMN public.perfiles.ultimo_viaje_finalizado_at IS 'Último fin de viaje del pasajero (UTC); ventana objetos perdidos.';

ALTER TABLE public.perfiles DROP CONSTRAINT IF EXISTS perfiles_tipo_vehiculo_operativo_check;
ALTER TABLE public.perfiles
  ADD CONSTRAINT perfiles_tipo_vehiculo_operativo_check
  CHECK (tipo_vehiculo_operativo IS NULL OR tipo_vehiculo_operativo IN ('auto', 'moto', 'camioneta'));
