// PMTiles Protocol Setup — registra el handler de PMTiles en maplibre-gl
// Importar en TODOS los componentes que crean un Map
// Es idempotente: llamarlo múltiples veces es seguro

import maplibregl from "maplibre-gl";
import { Protocol } from "pmtiles";

let initialized = false;

export function initPMTilesProtocol(): void {
  if (initialized) return;
  try {
    const protocol = new Protocol();
    maplibregl.addProtocol("pmtiles", protocol.tile);
    initialized = true;
    console.log("[PMTiles] Protocol registered ✓");
  } catch (e) {
    console.warn("[PMTiles] Failed to register protocol:", e);
  }
}

// Auto-init on import (para compatibilidad con componentes que no llamen explícitamente)
initPMTilesProtocol();
