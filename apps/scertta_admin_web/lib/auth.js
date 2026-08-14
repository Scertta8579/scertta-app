export const RUTAS_POR_ROL = Object.freeze({
  ceo_admin: "/ceo-dashboard",
  gerente_franquicia: "/hub",
  pasajero: "/solicitante",
  solicitante: "/solicitante",
  conductor: "/socio-conductor",
  flota: "/flota",
  operador: "/back-office",
  marketing: "/marketing",
  finanzas: "/finanzas",
});

export function rutaPorRol(rol) {
  if (!rol) return "/login";
  return RUTAS_POR_ROL[String(rol)] ?? "/login";
}

export const RUTAS_PROTEGIDAS = Object.freeze([
  "/solicitante",
  "/socio-conductor",
  "/back-office",
  "/ceo-dashboard",
  "/marketing",
  "/finanzas",
]);

export function esRutaProtegida(pathname) {
  return RUTAS_PROTEGIDAS.some((base) => pathname === base || pathname.startsWith(`${base}/`));
}
