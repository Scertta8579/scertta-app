/**
 * Modelo fiscal de retenciones sobre cobros (tarjeta vs otros medios).
 * Pasarela ~7% solo tarjeta; fondo mantenimiento = tarifa operativa declarada − pasarela.
 */

export type CommissionConfigRow = {
  comision_scertta_pct: number;
  gastos_operativos_pct: number;
};

export const DEFAULT_GATEWAY_CARD_PCT = 7;

export function splitOperativeFee(
  gastosOperativosPct: number,
  gatewayCardPct: number
): { gatewayPct: number; maintenancePlatformPct: number } {
  const g = Math.min(Math.max(0, gatewayCardPct), Math.max(0, gastosOperativosPct));
  return {
    gatewayPct: g,
    maintenancePlatformPct: Math.max(0, gastosOperativosPct - g),
  };
}

export type FiscalBucketsMoney = {
  gananciaNetaScerttaArs: number;
  gastosPasarelaArs: number;
  fondoMantenimientoArs: number;
};

/** Aplica porcentajes sobre un monto bruto de cobros con tarjeta. */
export function allocateCardRetentions(
  grossCardArs: number,
  cfg: CommissionConfigRow,
  gatewayCardPct: number
): FiscalBucketsMoney {
  const base = Math.max(0, grossCardArs);
  const sc = (base * Math.max(0, cfg.comision_scertta_pct)) / 100;
  const { gatewayPct, maintenancePlatformPct } = splitOperativeFee(
    cfg.gastos_operativos_pct,
    gatewayCardPct
  );
  const pas = (base * gatewayPct) / 100;
  const mant = (base * maintenancePlatformPct) / 100;
  return {
    gananciaNetaScerttaArs: sc,
    gastosPasarelaArs: pas,
    fondoMantenimientoArs: mant,
  };
}

/** Sin pasarela: solo ganancia Scertta + parte operativa que no es pasarela (mantenimiento). */
export function allocateNonCardRetentions(
  grossArs: number,
  cfg: CommissionConfigRow,
  gatewayCardPct: number
): FiscalBucketsMoney {
  const base = Math.max(0, grossArs);
  const sc = (base * Math.max(0, cfg.comision_scertta_pct)) / 100;
  const { maintenancePlatformPct } = splitOperativeFee(
    cfg.gastos_operativos_pct,
    gatewayCardPct
  );
  const mant = (base * maintenancePlatformPct) / 100;
  return {
    gananciaNetaScerttaArs: sc,
    gastosPasarelaArs: 0,
    fondoMantenimientoArs: mant,
  };
}

export function totalRetentionPctCard(cfg: CommissionConfigRow, gatewayCardPct: number): number {
  const { gatewayPct, maintenancePlatformPct } = splitOperativeFee(
    cfg.gastos_operativos_pct,
    gatewayCardPct
  );
  return cfg.comision_scertta_pct + gatewayPct + maintenancePlatformPct;
}
