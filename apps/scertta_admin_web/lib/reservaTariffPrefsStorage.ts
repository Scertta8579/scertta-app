const KEY = "scertta_reserva_incluye_10min_espera";

export function loadReservaIncluyeEspera10min(): boolean {
  if (typeof window === "undefined") return false;
  return localStorage.getItem(KEY) === "1";
}

export function saveReservaIncluyeEspera10min(v: boolean) {
  if (typeof window === "undefined") return;
  localStorage.setItem(KEY, v ? "1" : "0");
}
