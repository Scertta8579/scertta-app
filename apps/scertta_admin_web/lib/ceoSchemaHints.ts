/**
 * Esquemas sugeridos para persistir en Supabase lo que hoy el panel maneja
 * en localStorage o demo. Ejecutar como migración cuando definas backend.
 *
 * -- platform_maintenance_fund (fondo 0.9% / gastos AWS-IA)
 * CREATE TABLE IF NOT EXISTS platform_maintenance_fund (
 *   id              SMALLINT PRIMARY KEY DEFAULT 1 CHECK (id = 1),
 *   balance_ars     NUMERIC(15,2) NOT NULL DEFAULT 0,
 *   updated_at      TIMESTAMPTZ DEFAULT NOW()
 * );
 * CREATE TABLE IF NOT EXISTS platform_operating_expenses (
 *   id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
 *   amount_ars      NUMERIC(12,2) NOT NULL,
 *   concept         TEXT NOT NULL,
 *   deducted_from   TEXT NOT NULL DEFAULT 'maintenance_fund',
 *   created_by      UUID REFERENCES auth.users(id),
 *   created_at      TIMESTAMPTZ DEFAULT NOW()
 * );
 *
 * -- Pasajeros: saldo y estado (sin bloqueo; solo etiqueta "con_deuda")
 * CREATE TABLE IF NOT EXISTS passenger_wallet_ledger (
 *   user_id         UUID PRIMARY KEY REFERENCES auth.users(id),
 *   balance_ars     NUMERIC(12,2) NOT NULL DEFAULT 0,
 *   risk_status     TEXT NOT NULL DEFAULT 'ok'
 *     CHECK (risk_status IN ('ok', 'con_deuda')),
 *   updated_at      TIMESTAMPTZ DEFAULT NOW()
 * );
 *
 * -- Conductores: ciclo semanal domingo 23:59, gracia 1 semana, bloqueo 2º domingo
 * CREATE TABLE IF NOT EXISTS driver_billing_cycles (
 *   id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
 *   driver_id       UUID NOT NULL REFERENCES auth.users(id),
 *   period_start    DATE NOT NULL,
 *   period_end      TIMESTAMPTZ NOT NULL, -- domingo 23:59 ART
 *   commission_due_ars NUMERIC(12,2) NOT NULL DEFAULT 0,
 *   cash_debt_ars   NUMERIC(12,2) NOT NULL DEFAULT 0,
 *   card_auto_paid_ars NUMERIC(12,2) NOT NULL DEFAULT 0,
 *   status          TEXT NOT NULL DEFAULT 'open'
 *     CHECK (status IN ('open', 'grace', 'paid', 'blocked')),
 *   paid_at         TIMESTAMPTZ,
 *   created_at      TIMESTAMPTZ DEFAULT NOW()
 * );
 * CREATE INDEX IF NOT EXISTS idx_driver_billing_driver ON driver_billing_cycles(driver_id, period_end DESC);
 *
 * -- Reglas surge por ventana y zona (GeoJSON opcional)
 * CREATE TABLE IF NOT EXISTS surge_pricing_rules (
 *   id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
 *   name            TEXT NOT NULL,
 *   multiplier      NUMERIC(4,2) NOT NULL CHECK (multiplier >= 1),
 *   starts_at       TIMESTAMPTZ NOT NULL,
 *   ends_at         TIMESTAMPTZ NOT NULL,
 *   zone_geojson    JSONB,
 *   active          BOOLEAN NOT NULL DEFAULT true,
 *   created_at      TIMESTAMPTZ DEFAULT NOW()
 * );
 *
 * -- Opcional: flag en fare_config para reservas (10 min espera incluidos)
 * ALTER TABLE fare_config ADD COLUMN IF NOT EXISTS reserva_incluye_espera_10min BOOLEAN DEFAULT false;
 */

export const CEO_SCHEMA_HINTS_VERSION = "2026-04-06";
