const BALANCE_KEY = "scertta_platform_maintenance_fund_ars";
const EXPENSES_KEY = "scertta_platform_maintenance_expenses_v1";

export type MaintenanceExpense = {
  id: string;
  amountArs: number;
  concept: string;
  at: string;
};

function safeParseExpenses(raw: string | null): MaintenanceExpense[] {
  if (!raw) return [];
  try {
    const v = JSON.parse(raw) as unknown;
    if (!Array.isArray(v)) return [];
    return v
      .filter(
        (x): x is MaintenanceExpense =>
          typeof x === "object" &&
          x !== null &&
          typeof (x as MaintenanceExpense).id === "string" &&
          typeof (x as MaintenanceExpense).amountArs === "number"
      )
      .slice(0, 500);
  } catch {
    return [];
  }
}

export function loadMaintenanceFundBalanceArs(): number {
  if (typeof window === "undefined") return 0;
  const n = Number(localStorage.getItem(BALANCE_KEY));
  return Number.isFinite(n) ? Math.max(0, n) : 0;
}

export function saveMaintenanceFundBalanceArs(v: number) {
  if (typeof window === "undefined") return;
  localStorage.setItem(BALANCE_KEY, String(Math.max(0, v)));
}

export function loadMaintenanceExpenses(): MaintenanceExpense[] {
  if (typeof window === "undefined") return [];
  return safeParseExpenses(localStorage.getItem(EXPENSES_KEY));
}

function persistExpenses(rows: MaintenanceExpense[]) {
  if (typeof window === "undefined") return;
  localStorage.setItem(EXPENSES_KEY, JSON.stringify(rows));
}

/** Acredita al fondo (ej. cierre diario proporcional 0.9%). */
export function creditMaintenanceFundArs(delta: number) {
  const cur = loadMaintenanceFundBalanceArs();
  saveMaintenanceFundBalanceArs(cur + Math.max(0, delta));
}

/**
 * Registra gasto operativo descontado del fondo de mantenimiento.
 * Devuelve false si el saldo es insuficiente.
 */
export function registerOperatingExpenseArs(
  amountArs: number,
  concept: string
): boolean {
  const amt = Math.max(0, amountArs);
  if (amt <= 0) return false;
  const bal = loadMaintenanceFundBalanceArs();
  if (bal < amt) return false;
  saveMaintenanceFundBalanceArs(bal - amt);
  const row: MaintenanceExpense = {
    id: `${Date.now()}-${Math.random().toString(36).slice(2, 9)}`,
    amountArs: amt,
    concept: concept.trim() || "Gasto operativo",
    at: new Date().toISOString(),
  };
  const list = [row, ...loadMaintenanceExpenses()];
  persistExpenses(list);
  return true;
}
