const KEY_SCERTTA = "scertta_fee_comision_scertta_pct";
const KEY_SERVICIO = "scertta_fee_tarifa_servicio_pct";

const DEFAULT_SCERTTA = 15;
const DEFAULT_SERVICIO = 8;

export type PlatformFees = {
  comisionScerttaPct: number;
  tarifaServicioPct: number;
};

function clamp(n: number, min: number, max: number) {
  return Math.min(max, Math.max(min, n));
}

export function loadPlatformFees(): PlatformFees {
  if (typeof window === "undefined") {
    return {
      comisionScerttaPct: DEFAULT_SCERTTA,
      tarifaServicioPct: DEFAULT_SERVICIO,
    };
  }
  const a = parseFloat(localStorage.getItem(KEY_SCERTTA) ?? "");
  const b = parseFloat(localStorage.getItem(KEY_SERVICIO) ?? "");
  return {
    comisionScerttaPct: Number.isFinite(a) ? clamp(a, 0, 50) : DEFAULT_SCERTTA,
    tarifaServicioPct: Number.isFinite(b) ? clamp(b, 0, 30) : DEFAULT_SERVICIO,
  };
}

export function savePlatformFees(fees: PlatformFees): void {
  if (typeof window === "undefined") return;
  localStorage.setItem(
    KEY_SCERTTA,
    String(clamp(fees.comisionScerttaPct, 0, 50))
  );
  localStorage.setItem(
    KEY_SERVICIO,
    String(clamp(fees.tarifaServicioPct, 0, 30))
  );
}

/** Sobre un viaje de referencia $X: cuánto va a cada concepto (la promo solo puede afectar la parte Scertta). */
export function splitReferenciaViaje(
  montoReferencia: number,
  fees: PlatformFees
) {
  const tarifa = (montoReferencia * fees.tarifaServicioPct) / 100;
  const scertta = (montoReferencia * fees.comisionScerttaPct) / 100;
  const resto = Math.max(0, montoReferencia - tarifa - scertta);
  return {
    tarifaServicio: tarifa,
    comisionScertta: scertta,
    restoOperativo: resto,
    afectablePorPromo: scertta,
    intocablePromo: tarifa,
  };
}
