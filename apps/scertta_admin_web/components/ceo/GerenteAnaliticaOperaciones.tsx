"use client";

import { useEffect, useState } from "react";
import {
  AlertTriangle,
  BellRing,
  Car,
  FileWarning,
  Filter,
  Headphones,
  Loader2,
  Radio,
  RefreshCw,
  ShieldAlert,
  UserCog,
  Users,
} from "lucide-react";
import { supabase } from "@/lib/supabaseClient";
import { useCeoOperationsData } from "@/hooks/useCeoOperationsData";

function fmtNum(n: number | null | undefined, fallback = "—") {
  if (n === null || n === undefined) return fallback;
  return n.toLocaleString("es-AR");
}

function formatRelTime(iso: string) {
  try {
    const d = new Date(iso);
    return d.toLocaleString("es-AR", {
      day: "2-digit",
      month: "short",
      hour: "2-digit",
      minute: "2-digit",
    });
  } catch {
    return iso;
  }
}

type AnaliticaSub = "ops" | "embudo" | "riesgo";

export default function CeoAnaliticaOperaciones() {
  const { data, loading, error, refresh } = useCeoOperationsData();
  const [userId, setUserId] = useState<string | null>(null);
  const [sub, setSub] = useState<AnaliticaSub>("ops");

  useEffect(() => {
    supabase.auth.getUser().then(({ data: u }) => {
      setUserId(u.user?.id ?? null);
    });
  }, []);

  const hayPanico = (data?.panicoAbiertos.length ?? 0) > 0;

  return (
    <div className="space-y-8">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <h2 className="text-2xl font-semibold tracking-tight">
            Analítica y operaciones
          </h2>
          <p className="mt-1 max-w-2xl text-sm text-apple-gray">
            Datos críticos en vivo desde Supabase (conductores en línea,
            búsquedas activas, soporte, seguridad y documentación). Si una
            tabla no existe o RLS no aplica, verás &quot;—&quot;.
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-2 self-start">
          <button
            type="button"
            onClick={() => refresh()}
            disabled={loading}
            className="inline-flex items-center justify-center gap-2 rounded-xl border border-black/10 bg-white px-4 py-2 text-sm font-medium transition hover:bg-black/5 disabled:opacity-50 dark:border-white/15 dark:bg-zinc-950 dark:hover:bg-white/10"
          >
            <RefreshCw className={`h-4 w-4 ${loading ? "animate-spin" : ""}`} />
            Actualizar
          </button>
        </div>
      </div>

      <div
        role="tablist"
        className="flex flex-wrap gap-2 border-b border-black/10 pb-3 dark:border-white/10"
        aria-label="Vistas de analítica"
      >
        {(
          [
            ["ops", "Operaciones en vivo"],
          ] as const
        ).map(([id, label]) => (
          <button
            key={id}
            type="button"
            role="tab"
            aria-selected={sub === id}
            onClick={() => setSub(id)}
            className={`inline-flex items-center gap-2 rounded-xl px-4 py-2 text-sm font-medium transition ${
              sub === id
                ? "bg-rutmy-deep text-white shadow-sm"
                : "text-rutmy-slate hover:bg-rutmy-sand hover:text-rutmy-deep"
            }`}
          >
            {id === "embudo" ? (
              <Filter className="h-4 w-4" />
            ) : id === "riesgo" ? (
              <ShieldAlert className="h-4 w-4" />
            ) : (
              <Radio className="h-4 w-4" />
            )}
            {label}
          </button>
        ))}
      </div>

      {sub === "ops" ? (
        <>
      {error ? (
        <div
          role="alert"
          className="rounded-xl border border-amber-500/40 bg-amber-500/10 px-4 py-3 text-sm text-amber-900 dark:text-amber-200"
        >
          {error}
        </div>
      ) : null}

      {hayPanico ? (
        <div
          role="alert"
          className="animate-pulse rounded-2xl border-2 border-red-600 bg-red-600/10 p-5 shadow-lg dark:border-red-500 dark:bg-red-950/40"
        >
          <div className="flex flex-wrap items-start gap-3">
            <div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-xl bg-red-600 text-white">
              <ShieldAlert className="h-7 w-7" />
            </div>
            <div className="min-w-0 flex-1">
              <p className="text-lg font-bold text-red-800 dark:text-red-100">
                Alerta: botón de pánico activo
              </p>
              <p className="mt-1 text-sm text-red-900/90 dark:text-red-200/90">
                Hay incidentes de tipo pánico sin cerrar. Coordiná respuesta
                inmediata con operaciones y seguridad.
              </p>
              <ul className="mt-3 space-y-2">
                {data!.panicoAbiertos.map((p) => (
                  <li
                    key={p.id}
                    className="flex flex-wrap items-center justify-between gap-2 rounded-lg bg-white/80 px-3 py-2 text-sm dark:bg-black/40"
                  >
                    <span className="font-mono text-xs text-apple-gray">
                      #{p.id}
                    </span>
                    <span className="font-semibold uppercase text-red-700 dark:text-red-300">
                      {p.severity}
                    </span>
                    <span className="text-apple-gray">
                      {formatRelTime(p.created_at)}
                    </span>
                  </li>
                ))}
              </ul>
            </div>
          </div>
        </div>
      ) : (
        <div className="grid gap-4 rounded-2xl border border-emerald-500/30 bg-emerald-500/5 p-4 dark:bg-emerald-950/20 lg:grid-cols-[auto_1fr] lg:items-center">
          <div className="flex h-11 w-11 items-center justify-center rounded-xl bg-emerald-500/15 text-emerald-700 dark:text-emerald-400">
            <BellRing className="h-5 w-5" />
          </div>
          <div>
            <p className="font-medium text-emerald-900 dark:text-emerald-100">
              Seguridad / pánico
            </p>
            <p className="text-sm text-emerald-800/80 dark:text-emerald-200/80">
              No hay eventos de pánico abiertos. Los nuevos incidentes aparecen
              aquí al instante (tiempo real + sondeo cada 25 s).
            </p>
          </div>
        </div>
      )}

      <section
        aria-label="Métricas en tiempo real"
        className="grid gap-4 md:grid-cols-2"
      >
        <div className="rounded-2xl border border-black/10 bg-white p-6 shadow-sm dark:border-white/10 dark:bg-zinc-950">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <div className="rounded-xl bg-rutmy-agua/10 p-2.5">
                <Car className="h-6 w-6 text-rutmy-agua" />
              </div>
              <div>
                <p className="text-xs font-medium uppercase tracking-wide text-apple-gray">
                  Conductores conectados
                </p>
                <p className="mt-1 text-4xl font-bold tabular-nums">
                  {loading && !data ? (
                    <Loader2 className="h-8 w-8 animate-spin text-apple-gray" />
                  ) : (
                    fmtNum(data?.conductoresOnline)
                  )}
                </p>
              </div>
            </div>
            <Radio className="h-5 w-5 text-emerald-500" aria-hidden />
          </div>
          <p className="mt-3 text-xs text-apple-gray">
            Fuente: <code className="rounded bg-black/5 px-1 dark:bg-white/10">driver_positions.is_online</code>
          </p>
        </div>

        <div className="rounded-2xl border border-black/10 bg-white p-6 shadow-sm dark:border-white/10 dark:bg-zinc-950">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <div className="rounded-xl bg-violet-500/10 p-2.5">
                <Users className="h-6 w-6 text-violet-600 dark:text-violet-400" />
              </div>
              <div>
                <p className="text-xs font-medium uppercase tracking-wide text-apple-gray">
                  Pasajeros buscando viaje
                </p>
                <p className="mt-1 text-4xl font-bold tabular-nums">
                  {loading && !data ? (
                    <Loader2 className="h-8 w-8 animate-spin text-apple-gray" />
                  ) : (
                    fmtNum(data?.pasajerosBuscando)
                  )}
                </p>
              </div>
            </div>
            <Radio className="h-5 w-5 text-emerald-500" aria-hidden />
          </div>
          <p className="mt-3 text-xs text-apple-gray">
            Fuente:{" "}
            <code className="rounded bg-black/5 px-1 dark:bg-white/10">
              passenger_searches
            </code>{" "}
            con estado <strong>searching</strong>
          </p>
        </div>
      </section>

      <section aria-label="Gestión de casos de soporte">
        <h3 className="mb-4 flex items-center gap-2 text-lg font-semibold">
          <Headphones className="h-5 w-5 text-rutmy-agua" />
          Gestión de casos (soporte)
        </h3>
        <div className="grid gap-4 sm:grid-cols-3">
          <div className="rounded-2xl border border-black/10 bg-white p-5 dark:border-white/10 dark:bg-zinc-950">
            <p className="text-xs font-medium uppercase text-apple-gray">
              Casos activos
            </p>
            <p className="mt-2 text-3xl font-bold tabular-nums">
              {fmtNum(data?.soporteActivos)}
            </p>
            <p className="mt-1 text-xs text-apple-gray">Abiertos + en curso</p>
          </div>
          <div className="rounded-2xl border border-black/10 bg-white p-5 dark:border-white/10 dark:bg-zinc-950">
            <p className="text-xs font-medium uppercase text-apple-gray">
              En espera
            </p>
            <p className="mt-2 text-3xl font-bold tabular-nums text-amber-700 dark:text-amber-400">
              {fmtNum(data?.soporteEnEspera)}
            </p>
            <p className="mt-1 text-xs text-apple-gray">Estado: abierto</p>
          </div>
          <div className="rounded-2xl border-2 border-red-500/50 bg-red-500/5 p-5 dark:bg-red-950/30">
            <p className="flex items-center gap-1.5 text-xs font-medium uppercase text-red-800 dark:text-red-200">
              <AlertTriangle className="h-3.5 w-3.5" />
              Urgencia
            </p>
            <p className="mt-2 text-3xl font-bold tabular-nums text-red-700 dark:text-red-300">
              {fmtNum(data?.soporteUrgentes)}
            </p>
            <p className="mt-1 text-xs text-red-800/80 dark:text-red-200/80">
              Prioridad urgente sin cerrar
            </p>
          </div>
        </div>
        <p className="mt-2 text-xs text-apple-gray">
          Tabla: <code className="rounded bg-black/5 px-1 dark:bg-white/10">support_tickets</code>
        </p>
      </section>

      <section
        aria-label="Documentación y personal"
        className="grid gap-6 lg:grid-cols-2"
      >
        <div className="rounded-2xl border border-black/10 bg-white p-6 dark:border-white/10 dark:bg-zinc-950">
          <div className="flex items-center gap-2 border-b border-black/5 pb-4 dark:border-white/10">
            <FileWarning className="h-5 w-5 text-amber-600" />
            <h3 className="font-semibold">Documentación pendiente</h3>
          </div>
          <div className="mt-6 flex flex-col items-center justify-center rounded-xl border border-dashed border-amber-500/40 bg-amber-500/5 px-6 py-10 text-center dark:bg-amber-950/20">
            <p className="text-sm text-apple-gray">
              Conductores con documentos por aprobar
            </p>
            <p className="mt-2 text-5xl font-bold tabular-nums text-amber-800 dark:text-amber-200">
              {fmtNum(data?.documentosPendientes)}
            </p>
            <p className="mt-3 max-w-sm text-xs text-apple-gray">
              Cuenta registros en{" "}
              <code className="rounded bg-black/5 px-1 dark:bg-white/10">
                document_validations
              </code>{" "}
              (pending / requires_review) o{" "}
              <code className="rounded bg-black/5 px-1 dark:bg-white/10">
                documentos_validacion
              </code>{" "}
              (pendiente).
            </p>
          </div>
        </div>

        <div className="rounded-2xl border border-black/10 bg-white p-6 dark:border-white/10 dark:bg-zinc-950">
          <div className="flex items-center gap-2 border-b border-black/5 pb-4 dark:border-white/10">
            <UserCog className="h-5 w-5 text-rutmy-agua" />
            <h3 className="font-semibold">Control de personal</h3>
          </div>
          <p className="mt-3 text-xs text-apple-gray">
            Perfiles con rol operador, admin, CEO o marketing.
          </p>
          <ul className="mt-4 max-h-[280px] space-y-2 overflow-y-auto pr-1">
            {data?.staff.length ? (
              data.staff.map((m) => {
                const esVos = userId && m.id === userId;
                return (
                  <li
                    key={m.id}
                    className="flex items-center justify-between gap-3 rounded-xl border border-black/5 px-4 py-3 dark:border-white/10"
                  >
                    <div className="min-w-0">
                      <p className="truncate font-medium">{m.nombre}</p>
                      <p className="truncate text-xs text-apple-gray">
                        {m.email}
                      </p>
                    </div>
                    <div className="shrink-0 text-right">
                      <span className="rounded-full bg-zinc-100 px-2 py-0.5 text-xs font-medium capitalize dark:bg-zinc-800">
                        {m.rol}
                      </span>
                      <p
                        className={`mt-1 text-xs ${esVos ? "font-semibold text-emerald-600 dark:text-emerald-400" : "text-apple-gray"}`}
                      >
                        {esVos ? "Tu sesión (panel)" : "Equipo"}
                      </p>
                    </div>
                  </li>
                );
              })
            ) : (
              <li className="rounded-xl border border-dashed border-black/10 px-4 py-8 text-center text-sm text-apple-gray dark:border-white/15">
                {loading
                  ? "Cargando equipo…"
                  : "No se pudieron listar perfiles (vacío o permisos)."}
              </li>
            )}
          </ul>
        </div>
      </section>
        </>
      ) : null}
    </div>
  );
}
