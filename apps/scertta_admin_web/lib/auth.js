export const RUTAS_POR_ROL = Object.freeze({
  pasajero: "/solicitante",
  solicitante: "/solicitante",
  conductor: "/socio-conductor",
  admin: "/back-office",
  operador: "/back-office",
  ceo: "/ceo-dashboard",
  marketing: "/marketing",
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
]);

export function esRutaProtegida(pathname) {
  return RUTAS_PROTEGIDAS.some((base) => pathname === base || pathname.startsWith(`${base}/`));
}

