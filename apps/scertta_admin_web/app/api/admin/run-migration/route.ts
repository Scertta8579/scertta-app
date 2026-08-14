import { NextResponse } from "next/server";

export async function GET() {
  // Esta API existe como recordatorio. La migración debe ejecutarse
  // en el SQL Editor de Supabase Dashboard con service_role.
  return NextResponse.json({
    mensaje: "La migración debe ejecutarse manualmente en Supabase Dashboard → SQL Editor.",
    pasos: [
      "1. Entrá a https://supabase.com/dashboard/project/TU_PROYECTO_REF",
      "2. Andá a SQL Editor en el menú izquierdo",
      "3. Pegá el siguiente SQL y ejecutalo:",
    ],
    sql: `-- Agregar 'eliminado' al CHECK constraint de franquicias.estado
ALTER TABLE public.franquicias DROP CONSTRAINT IF EXISTS franquicias_estado_check;

ALTER TABLE public.franquicias ADD CONSTRAINT franquicias_estado_check 
  CHECK (estado IN ('activo', 'suspendido', 'pendiente', 'eliminado'));

COMMENT ON COLUMN public.franquicias.estado IS 
  'activo | suspendido | pendiente | eliminado (soft-delete)';`,
  });
}
