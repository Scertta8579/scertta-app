-- ═══════════════════════════════════════════════════════════════════════════
-- REPARACIÓN: quitar FK errónea a public.solicitudes_viaje (tabla inexistente)
-- y asegurar trip_id / viaje_id como uuid sin FK (referencia trips / viajes).
-- Ejecutar UNA VEZ en el SQL Editor de Supabase si falló una migración previa.
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE IF EXISTS public.wallet_transactions
  DROP CONSTRAINT IF EXISTS wallet_transactions_trip_id_fkey;

ALTER TABLE IF EXISTS public.trip_financial_settlements
  DROP CONSTRAINT IF EXISTS trip_financial_settlements_trip_id_fkey;

-- Si existiera otra FK autogenerada, listar con:
-- SELECT conname FROM pg_constraint
-- WHERE conrelid = 'public.wallet_transactions'::regclass;

COMMENT ON COLUMN public.wallet_transactions.trip_id IS
  'UUID del viaje (public.trips o public.viajes); sin FK por compatibilidad de esquemas.';

COMMENT ON COLUMN public.trip_financial_settlements.trip_id IS
  'UUID del viaje liquidado; sin FK por compatibilidad de esquemas.';

-- Luego aplicá las migraciones completas del repo (en orden):
--   supabase/migrations/20260411_wallet_ledger_finanzas.sql
--   supabase/migrations/20260412_movimientos_billetera_kyc_feedback.sql
