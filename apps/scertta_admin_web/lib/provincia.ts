/**
 * Utilidad de contexto de provincia para Rutmy.
 * 
 * CEO → '*' (ve todas las provincias, sin filtro)
 * Otros roles → UUID de provincia_activa_id (filtra datos a esa provincia)
 */

export const CEO_ROLE = 'ceo'
export const CEO_WILDCARD = '*'

/** Determina si un rol tiene alcance global (CEO). */
export function esAlcanceGlobal(rol: string | null): boolean {
  return rol === CEO_ROLE
}

/** 
 * Retorna el filtro de provincia para queries de Supabase.
 * Si el rol es CEO, no aplica filtro (retorna undefined).
 * Si es otro rol y tiene provincia, retorna el filtro .eq().
 */
export function filtroProvincia(
  provinciaActivaId: string | null,
  rol: string | null,
  columna: string = 'provincia_id'
): { columna: string; valor: string } | undefined {
  if (esAlcanceGlobal(rol)) return undefined
  if (!provinciaActivaId) return undefined
  return { columna, valor: provinciaActivaId }
}

/** 
 * Formatea el label de provincia activa para mostrar en UI.
 * CEO → "Todas las provincias"
 * Otro → nombre de la provincia
 */
export function labelProvinciaActiva(
  provinciaActivaId: string | null,
  rol: string | null,
  provincias: Array<{ id: string; nombre: string }> = []
): string {
  if (esAlcanceGlobal(rol)) return '🌎 Todas las provincias'
  if (!provinciaActivaId) return '⚠️ Sin provincia asignada'
  const prov = provincias.find(p => p.id === provinciaActivaId)
  return prov ? `📍 ${prov.nombre}` : `📍 Provincia (${provinciaActivaId.slice(0, 8)}...)`
}
