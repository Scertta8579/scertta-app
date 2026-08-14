"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import {
  Headphones,
  LayoutDashboard,
  Loader2,
  RefreshCw,
  Search,
  ShieldCheck,
} from "lucide-react";
import { createClient } from "@/lib/supabaseClient";
import KycReviewPanel, {
  type KycDocRow,
  type KycPerfilLite,
} from "./KycReviewPanel";

type DocRow = KycDocRow;

type TicketRow = {
  id: string;
  status: string;
  priority: string;
  subject: string;
  description: string | null;
  source: string;
  created_at: string;
  passenger_id: string | null;
  driver_id: string | null;
};

type PerfilLite = KycPerfilLite;

const DOC_LABEL: Record<string, string> = {
  dni: "DNI",
  licencia: "Cédula / Licencia de conducir",
  vtv: "VTV / Seguro vehicular",
  seguro: "Póliza / Seguro",
  cedula: "Cédula del vehículo",
  dni_frente: "DNI frente",
  dni_dorso: "DNI dorso",
  licencia_frente: "Licencia frente",
  licencia_dorso: "Licencia dorso",
  cedula_frente: "Cédula frente",
  cedula_dorso: "Cédula dorso",
  poliza: "Póliza",
  selfie: "Selfie verificación",
  vehiculo: "Vehículo (fotos)",
};

type NavId = "kyc" | "soporte" | "busqueda";

function labelDoc(t: string) {
  return DOC_LABEL[t] ?? t;
}

async function syncKycResumenPerfil(
  client: ReturnType<typeof createClient>,
  driverId: string
) {
  const { data: rows } = await client
    .from("document_validations")
    .select("document_type,status")
    .eq("driver_id", driverId)
    .in("document_type", ["dni", "licencia", "vtv"]);
  const required = ["dni", "licencia", "vtv"] as const;
  const byType: Record<string, string> = {};
  for (const r of rows ?? []) {
    if (r.document_type) byType[r.document_type] = r.status ?? "";
  }
  let estado: string | null = "pendiente";
  if (required.every((t) => byType[t] === "approved")) {
    estado = "aprobado";
  } else if (required.some((t) => byType[t] === "rejected")) {
    estado = "rechazado";
  } else if (
    required.some(
      (t) =>
        byType[t] === "pending" ||
        byType[t] === "requires_review" ||
        !byType[t]
    )
  ) {
    estado = "en_revision";
  }
  await client
    .from("perfiles")
    .update({ estado_validacion_kyc: estado })
    .eq("id", driverId);
}

export default function SoporteDashboard() {
  const supabase = createClient();
  const [nav, setNav] = useState<NavId>("kyc");
  const [docs, setDocs] = useState<DocRow[]>([]);
  const [tickets, setTickets] = useState<TicketRow[]>([]);
  const [perfilMap, setPerfilMap] = useState<Record<string, KycPerfilLite>>({});
  const [loading, setLoading] = useState(true);
  const [acting, setActing] = useState<string | null>(null);
  const [msg, setMsg] = useState<string | null>(null);

  const [searchQ, setSearchQ] = useState("");
  const [searching, setSearching] = useState(false);
  const [searchPerfiles, setSearchPerfiles] = useState<PerfilLite[]>([]);
  const [searchDocs, setSearchDocs] = useState<DocRow[]>([]);

  const load = useCallback(async () => {
    setLoading(true);
    setMsg(null);
    const [dRes, tRes] = await Promise.all([
      supabase
        .from("document_validations")
        .select(
          "id,driver_id,document_type,status,document_url,created_at,notes,feedback_conductor"
        )
        .in("status", ["pending", "requires_review"])
        .order("created_at", { ascending: false })
        .limit(120),
      supabase
        .from("support_tickets")
        .select(
          "id,status,priority,subject,description,source,created_at,passenger_id,driver_id"
        )
        .in("status", ["open", "in_progress"])
        .order("created_at", { ascending: false })
        .limit(120),
    ]);
    if (dRes.error) setMsg(dRes.error.message);
    else setDocs((dRes.data as DocRow[]) ?? []);
    if (tRes.error && !dRes.error) setMsg(tRes.error.message);
    if (!tRes.error) setTickets((tRes.data as TicketRow[]) ?? []);
    setLoading(false);
  }, [supabase]);

  const driverIds = useMemo(() => {
    const s = new Set<string>();
    docs.forEach((d) => s.add(d.driver_id));
    tickets.forEach((t) => {
      if (t.driver_id) s.add(t.driver_id);
      if (t.passenger_id) s.add(t.passenger_id);
    });
    return [...s].filter(Boolean);
  }, [docs, tickets]);

  const loadPerfiles = useCallback(async () => {
    if (driverIds.length === 0) {
      setPerfilMap({});
      return;
    }
    const { data, error } = await supabase
      .from("perfiles")
      .select("id,nombre,apellido,email,rol,dni")
      .in("id", driverIds.slice(0, 100));
    if (error || !data) return;
    const m: Record<string, KycPerfilLite> = {};
    for (const p of data as KycPerfilLite[]) m[p.id] = p;
    setPerfilMap(m);
  }, [supabase, driverIds]);

  useEffect(() => {
    void load();
  }, [load]);

  useEffect(() => {
    void loadPerfiles();
  }, [loadPerfiles]);

  useEffect(() => {
    const ch = supabase
      .channel("backoffice-sync")
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "document_validations" },
        () => void load()
      )
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "support_tickets" },
        () => void load()
      )
      .subscribe();
    return () => {
      supabase.removeChannel(ch);
    };
  }, [supabase, load]);

  const setDocStatus = async (
    id: string,
    status: "approved" | "rejected" | "pending",
    reviewerNotes?: string
  ) => {
    setActing(id);
    setMsg(null);
    const {
      data: { user },
    } = await supabase.auth.getUser();
    const trimmed = reviewerNotes?.trim() ?? "";
    const patch: Record<string, unknown> = {
      status,
      validated_by_ai: false,
      feedback_conductor: trimmed || null,
    };
    if (trimmed !== "") {
      patch.notes = trimmed;
    }
    if (status === "pending") {
      patch.validated_at = null;
      patch.validated_by = null;
    } else {
      patch.validated_at = new Date().toISOString();
      patch.validated_by = user?.id ?? null;
    }
    const { data: docRow, error: fetchErr } = await supabase
      .from("document_validations")
      .select("driver_id")
      .eq("id", id)
      .maybeSingle();
    if (fetchErr) {
      setActing(null);
      setMsg(fetchErr.message);
      return;
    }
    const { error } = await supabase
      .from("document_validations")
      .update(patch)
      .eq("id", id);
    setActing(null);
    if (error) setMsg(error.message);
    else {
      const did = docRow?.driver_id as string | undefined;
      if (did) await syncKycResumenPerfil(supabase, did);
      void load();
    }
  };

  const pedirResubida = async (id: string, reviewerNotes?: string) => {
    setActing(id);
    setMsg(null);
    const {
      data: { user },
    } = await supabase.auth.getUser();
    const stamp = new Date().toISOString();
    const prefix =
      reviewerNotes !== undefined && reviewerNotes.trim() !== ""
        ? `${reviewerNotes.trim()}\n\n`
        : "";
    const { data: docRow, error: fetchErr } = await supabase
      .from("document_validations")
      .select("driver_id")
      .eq("id", id)
      .maybeSingle();
    if (fetchErr) {
      setActing(null);
      setMsg(fetchErr.message);
      return;
    }
    const { error } = await supabase
      .from("document_validations")
      .update({
        status: "requires_review",
        notes: `${prefix}Re-subida solicitada por operaciones (${stamp}). Auditor: ${user?.id ?? "—"}`,
        feedback_conductor:
          reviewerNotes !== undefined && reviewerNotes.trim() !== ""
            ? reviewerNotes.trim()
            : null,
        validated_at: null,
        validated_by: null,
        validated_by_ai: false,
      })
      .eq("id", id);
    setActing(null);
    if (error) setMsg(error.message);
    else {
      const did = docRow?.driver_id as string | undefined;
      if (did) await syncKycResumenPerfil(supabase, did);
      void load();
    }
  };

  const saveDriverProfile = async (
    driverId: string,
    patch: { nombre: string; apellido: string; dni: string }
  ) => {
    setMsg(null);
    const { error } = await supabase
      .from("perfiles")
      .update({
        nombre: patch.nombre || null,
        apellido: patch.apellido || null,
        dni: patch.dni || null,
      })
      .eq("id", driverId);
    if (error) {
      setMsg(error.message);
      return;
    }
    await loadPerfiles();
  };

  const setTicketStatus = async (id: string, status: string) => {
    setActing(id);
    setMsg(null);
    const { error } = await supabase
      .from("support_tickets")
      .update({ status, updated_at: new Date().toISOString() })
      .eq("id", id);
    setActing(null);
    if (error) setMsg(error.message);
    else void load();
  };

  const runUniversalSearch = async () => {
    const q = searchQ.trim();
    if (!q) return;
    setSearching(true);
    setSearchPerfiles([]);
    setSearchDocs([]);
    try {
      const isUuid =
        /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
          q
        );

      if (isUuid) {
        const { data: p } = await supabase
          .from("perfiles")
          .select("id,nombre,apellido,email,rol,dni")
          .eq("id", q)
          .maybeSingle();
        if (p) setSearchPerfiles([p as PerfilLite]);
        const { data: dByDriver } = await supabase
          .from("document_validations")
          .select(
            "id,driver_id,document_type,status,document_url,created_at,notes,feedback_conductor"
          )
          .eq("driver_id", q)
          .limit(40);
        setSearchDocs((dByDriver as DocRow[]) ?? []);
      } else {
        const safe = q.replace(/%/g, "\\%").replace(/_/g, "\\_");
        const { data: pl } = await supabase
          .from("perfiles")
          .select("id,nombre,apellido,email,rol,dni")
          .or(`email.ilike.%${safe}%,nombre.ilike.%${safe}%`)
          .limit(25);
        setSearchPerfiles((pl as PerfilLite[]) ?? []);
        const { data: dl2 } = await supabase
          .from("document_validations")
          .select(
            "id,driver_id,document_type,status,document_url,created_at,notes,feedback_conductor"
          )
          .ilike("notes", `%${safe}%`)
          .limit(40);
        setSearchDocs((dl2 as DocRow[]) ?? []);
      }
    } finally {
      setSearching(false);
    }
  };

  const navItems: { id: NavId; label: string; icon: typeof LayoutDashboard }[] =
    [
      { id: "kyc", label: "Cola KYC", icon: ShieldCheck },
      { id: "soporte", label: "Soporte Nivel 1", icon: Headphones },
      { id: "busqueda", label: "Buscador universal", icon: Search },
    ];

  return (
    <div className="flex min-h-[calc(100vh-8rem)] flex-col gap-6 lg:flex-row lg:gap-8">
      <aside className="shrink-0 lg:w-56">
        <nav className="flex flex-row gap-1 overflow-x-auto rounded-2xl border border-zinc-200 bg-zinc-50/80 p-1 dark:border-zinc-800 dark:bg-zinc-900/50 lg:flex-col lg:overflow-visible">
          {navItems.map(({ id, label, icon: Icon }) => (
            <button
              key={id}
              type="button"
              onClick={() => setNav(id)}
              className={`flex items-center gap-2.5 rounded-xl px-3 py-2.5 text-left text-sm font-medium transition lg:w-full ${
                nav === id
                  ? "bg-white text-zinc-900 shadow-sm dark:bg-zinc-800 dark:text-white"
                  : "text-zinc-600 hover:bg-white/60 dark:text-zinc-400 dark:hover:bg-zinc-800/80"
              }`}
            >
              <Icon className="h-4 w-4 shrink-0 opacity-80" />
              {label}
            </button>
          ))}
        </nav>
      </aside>

      <div className="min-w-0 flex-1 space-y-4">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div>
            <h2 className="text-lg font-semibold tracking-tight text-zinc-900 dark:text-white">
              {nav === "kyc"
                ? "Validación de identidad y vehículo"
                : nav === "soporte"
                  ? "Tickets activos"
                  : "Búsqueda rápida"}
            </h2>
            <p className="text-xs text-zinc-500 dark:text-zinc-400">
              Datos en vivo vía Supabase Realtime
            </p>
          </div>
          <button
            type="button"
            onClick={() => void load()}
            disabled={loading}
            className="inline-flex items-center gap-2 rounded-xl border border-zinc-200 bg-white px-3 py-2 text-sm font-medium text-zinc-700 shadow-sm hover:bg-zinc-50 disabled:opacity-50 dark:border-zinc-700 dark:bg-zinc-900 dark:text-zinc-200 dark:hover:bg-zinc-800"
          >
            <RefreshCw className={`h-4 w-4 ${loading ? "animate-spin" : ""}`} />
            Actualizar
          </button>
        </div>

        {msg ? (
          <div
            role="alert"
            className="rounded-xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-900 dark:border-amber-900/50 dark:bg-amber-950/40 dark:text-amber-100"
          >
            {msg}
          </div>
        ) : null}

        {nav === "kyc" ? (
          <div className="space-y-3">
            <p className="text-xs text-zinc-500 dark:text-zinc-400">
              DNI, cédula/licencia, VTV/seguro — visor ampliado y notas del revisor.
            </p>
            <KycReviewPanel
              supabase={supabase}
              docs={docs}
              perfilMap={perfilMap}
              loading={loading}
              acting={acting}
              labelDoc={labelDoc}
              onSetDocStatus={(id, status, notes) =>
                void setDocStatus(id, status, notes)
              }
              onPedirResubida={(id, notes) => void pedirResubida(id, notes)}
              onSaveDriverProfile={(driverId, patch) =>
                void saveDriverProfile(driverId, patch)
              }
            />
          </div>
        ) : null}

        {nav === "soporte" ? (
          <div className="overflow-hidden rounded-2xl border border-zinc-200 bg-white shadow-sm dark:border-zinc-800 dark:bg-zinc-950">
            <div className="flex items-center gap-3 border-b border-zinc-100 px-5 py-4 dark:border-zinc-800">
              <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-sky-100 text-sky-700 dark:bg-sky-950 dark:text-sky-300">
                <Headphones className="h-5 w-5" />
              </div>
              <div>
                <p className="text-sm font-semibold text-zinc-900 dark:text-white">
                  Soporte nivel 1
                </p>
                <p className="text-xs text-zinc-500">
                  Usuario, motivo, prioridad y estado operativo
                </p>
              </div>
            </div>
            <div className="overflow-x-auto">
              {loading ? (
                <div className="flex justify-center py-16">
                  <Loader2 className="h-8 w-8 animate-spin text-zinc-400" />
                </div>
              ) : tickets.length === 0 ? (
                <p className="py-16 text-center text-sm text-zinc-500">
                  No hay tickets activos.
                </p>
              ) : (
                <table className="w-full min-w-[880px] text-left text-sm">
                  <thead>
                    <tr className="border-b border-zinc-100 bg-zinc-50/80 text-xs font-semibold uppercase tracking-wide text-zinc-500 dark:border-zinc-800 dark:bg-zinc-900/50">
                      <th className="px-4 py-3">Usuario</th>
                      <th className="px-4 py-3">Motivo</th>
                      <th className="px-4 py-3">Prioridad</th>
                      <th className="px-4 py-3">Estado</th>
                      <th className="px-4 py-3">Origen</th>
                      <th className="px-4 py-3 text-right">Acciones</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-zinc-100 dark:divide-zinc-800">
                    {tickets.map((t) => {
                      const uid = t.driver_id ?? t.passenger_id;
                      const p = uid ? perfilMap[uid] : undefined;
                      const motivo =
                        t.description?.trim() || t.subject || "—";
                      return (
                        <tr
                          key={t.id}
                          className="hover:bg-zinc-50/50 dark:hover:bg-zinc-900/30"
                        >
                          <td className="px-4 py-3">
                            <p className="font-medium text-zinc-900 dark:text-white">
                              {p?.nombre ?? "Sin nombre"}
                            </p>
                            <p className="text-xs text-zinc-500">
                              {p?.email ?? uid?.slice(0, 13) ?? "—"}
                            </p>
                          </td>
                          <td className="max-w-[240px] px-4 py-3">
                            <p className="line-clamp-2 text-zinc-700 dark:text-zinc-300">
                              {motivo}
                            </p>
                          </td>
                          <td className="px-4 py-3">
                            <span
                              className={`inline-flex rounded-full px-2 py-0.5 text-xs font-semibold uppercase ${
                                t.priority === "urgent"
                                  ? "bg-red-100 text-red-800 dark:bg-red-950 dark:text-red-200"
                                  : t.priority === "high"
                                    ? "bg-orange-100 text-orange-800 dark:bg-orange-950 dark:text-orange-200"
                                    : "bg-zinc-100 text-zinc-700 dark:bg-zinc-800 dark:text-zinc-300"
                              }`}
                            >
                              {t.priority}
                            </span>
                          </td>
                          <td className="px-4 py-3 capitalize text-zinc-600 dark:text-zinc-400">
                            {t.status.replace(/_/g, " ")}
                          </td>
                          <td className="px-4 py-3 text-zinc-500">
                            {t.source}
                          </td>
                          <td className="px-4 py-3">
                            <div className="flex flex-wrap justify-end gap-1">
                              <button
                                type="button"
                                disabled={acting === t.id}
                                onClick={() =>
                                  void setTicketStatus(t.id, "in_progress")
                                }
                                className="rounded-lg bg-amber-100 px-2.5 py-1 text-xs font-semibold text-amber-900 dark:bg-amber-950 dark:text-amber-200"
                              >
                                En curso
                              </button>
                              <button
                                type="button"
                                disabled={acting === t.id}
                                onClick={() =>
                                  void setTicketStatus(t.id, "resolved")
                                }
                                className="rounded-lg bg-emerald-100 px-2.5 py-1 text-xs font-semibold text-emerald-900 dark:bg-emerald-950 dark:text-emerald-200"
                              >
                                Resolver
                              </button>
                            </div>
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              )}
            </div>
          </div>
        ) : null}

        {nav === "busqueda" ? (
          <div className="space-y-4 rounded-2xl border border-zinc-200 bg-white p-5 shadow-sm dark:border-zinc-800 dark:bg-zinc-950">
            <div className="flex flex-col gap-3 sm:flex-row sm:items-end">
              <div className="min-w-0 flex-1">
                <label className="text-xs font-semibold uppercase tracking-wide text-zinc-500">
                  Buscador universal
                </label>
                <div className="mt-1 flex gap-2">
                  <div className="relative flex-1">
                    <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-zinc-400" />
                    <input
                      value={searchQ}
                      onChange={(e) => setSearchQ(e.target.value)}
                      onKeyDown={(e) => {
                        if (e.key === "Enter") void runUniversalSearch();
                      }}
                      placeholder="DNI en notas, correo, UUID o patente en notas…"
                      className="w-full rounded-xl border border-zinc-200 bg-zinc-50 py-2.5 pl-10 pr-3 text-sm outline-none ring-violet-500/20 focus:border-violet-500 focus:ring-4 dark:border-zinc-700 dark:bg-zinc-900 dark:text-white"
                    />
                  </div>
                  <button
                    type="button"
                    disabled={searching}
                    onClick={() => void runUniversalSearch()}
                    className="rounded-xl bg-zinc-900 px-5 py-2.5 text-sm font-semibold text-white hover:bg-zinc-800 disabled:opacity-50 dark:bg-violet-600 dark:hover:bg-violet-500"
                  >
                    {searching ? (
                      <Loader2 className="h-4 w-4 animate-spin" />
                    ) : (
                      "Buscar"
                    )}
                  </button>
                </div>
                <p className="mt-2 text-xs text-zinc-500">
                  Tip: si agregás patente en notas de documentos, aparecerá
                  aquí. Ampliá el esquema con campo dedicado cuando lo definan.
                </p>
              </div>
            </div>

            {searchPerfiles.length > 0 ? (
              <div>
                <h3 className="mb-2 text-sm font-semibold text-zinc-900 dark:text-white">
                  Perfiles
                </h3>
                <div className="grid gap-2 sm:grid-cols-2">
                  {searchPerfiles.map((p) => (
                    <div
                      key={p.id}
                      className="rounded-xl border border-zinc-100 bg-zinc-50/80 p-3 dark:border-zinc-800 dark:bg-zinc-900/40"
                    >
                      <p className="font-medium text-zinc-900 dark:text-white">
                        {p.nombre}
                      </p>
                      <p className="text-xs text-zinc-500">{p.email}</p>
                      <p className="mt-1 text-xs font-mono text-zinc-400">
                        {p.id}
                      </p>
                      <span className="mt-2 inline-block rounded-full bg-white px-2 py-0.5 text-xs font-medium capitalize dark:bg-zinc-800">
                        {p.rol}
                      </span>
                    </div>
                  ))}
                </div>
              </div>
            ) : null}

            {searchDocs.length > 0 ? (
              <div>
                <h3 className="mb-2 text-sm font-semibold text-zinc-900 dark:text-white">
                  Coincidencias en documentación
                </h3>
                <ul className="space-y-2">
                  {searchDocs.map((d) => (
                    <li
                      key={d.id}
                      className="rounded-xl border border-zinc-100 p-3 text-sm dark:border-zinc-800"
                    >
                      <span className="font-medium">
                        {labelDoc(d.document_type)}
                      </span>{" "}
                      · {d.status} ·{" "}
                      <span className="font-mono text-xs">{d.driver_id}</span>
                    </li>
                  ))}
                </ul>
              </div>
            ) : null}
          </div>
        ) : null}
      </div>
    </div>
  );
}
