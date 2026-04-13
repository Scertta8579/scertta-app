"use client";

import { useCallback, useEffect, useState } from "react";
import {
  Bell,
  Cake,
  CalendarHeart,
  Loader2,
  Mail,
  MapPinned,
  RefreshCw,
  Send,
  Sparkles,
  Tag,
  Zap,
} from "lucide-react";
import { createClient } from "@/lib/supabaseClient";
import MarketingPromoMapClient from "@/app/marketing/MarketingPromoMapClient";

type SegmentId =
  | "nuevos"
  | "nunca_viajaron"
  | "primer_viaje"
  | "inactivos_7d"
  | "inactivos_30d"
  | "inactivos_365d";

const SEGMENTS: {
  id: SegmentId;
  title: string;
  desc: string;
}[] = [
  {
    id: "nuevos",
    title: "Usuarios nuevos",
    desc: "Alta reciente en la plataforma (últimos días).",
  },
  {
    id: "nunca_viajaron",
    title: "Nunca viajaron",
    desc: "Registrados sin viaje completado asociado.",
  },
  {
    id: "primer_viaje",
    title: "1.er viaje completado",
    desc: "Primer viaje finalizado — onboarding y fidelización.",
  },
  {
    id: "inactivos_7d",
    title: "Inactivos +1 semana",
    desc: "Sin actividad relevante en los últimos 7 días.",
  },
  {
    id: "inactivos_30d",
    title: "Inactivos +1 mes",
    desc: "Reactivación suave y ofertas segmentadas.",
  },
  {
    id: "inactivos_365d",
    title: "Inactivos +1 año",
    desc: "Campaña de recuperación de largo plazo.",
  },
];

const AUTO_KEYS = {
  birthday: "mkt_auto_cumpleanos",
  holidays: "mkt_auto_festivos",
  abandoned: "mkt_auto_viaje_abandonado",
} as const;

type AutoState = Record<keyof typeof AUTO_KEYS, boolean>;

function loadAuto(): AutoState {
  if (typeof window === "undefined") {
    return { birthday: false, holidays: false, abandoned: false };
  }
  try {
    const r = localStorage.getItem("scertta_mkt_automations_v1");
    if (!r)
      return { birthday: false, holidays: false, abandoned: false };
    return { ...JSON.parse(r) } as AutoState;
  } catch {
    return { birthday: false, holidays: false, abandoned: false };
  }
}

function saveAuto(s: AutoState) {
  if (typeof window === "undefined") return;
  localStorage.setItem("scertta_mkt_automations_v1", JSON.stringify(s));
}

type NavId = "campanas" | "auto" | "mapa" | "cupones";

type DiscountRow = {
  id: string;
  code: string;
  description: string | null;
  percent_off: number | null;
  active: boolean;
  uses_count: number;
  max_uses: number | null;
};

export default function MarketingEnterpriseDashboard() {
  const supabase = createClient();
  const [nav, setNav] = useState<NavId>("campanas");
  const [sending, setSending] = useState<SegmentId | null>(null);
  const [previewEmails, setPreviewEmails] = useState("");
  const [campaignSubject, setCampaignSubject] = useState("");
  const [campaignHtml, setCampaignHtml] = useState("");
  const [campaignMsg, setCampaignMsg] = useState<string | null>(null);
  const [auto, setAuto] = useState<AutoState>(loadAuto);
  const [codes, setCodes] = useState<DiscountRow[]>([]);
  const [codesLoading, setCodesLoading] = useState(false);
  const [newCode, setNewCode] = useState("");
  const [newPct, setNewPct] = useState("10");
  const [newDesc, setNewDesc] = useState("");
  const [codeErr, setCodeErr] = useState<string | null>(null);

  useEffect(() => {
    setAuto(loadAuto());
  }, []);

  const loadCodes = useCallback(async () => {
    setCodesLoading(true);
    const { data, error } = await supabase
      .from("discount_codes")
      .select(
        "id,code,description,percent_off,active,uses_count,max_uses"
      )
      .order("created_at", { ascending: false })
      .limit(60);
    if (!error) setCodes((data as DiscountRow[]) ?? []);
    setCodesLoading(false);
  }, [supabase]);

  useEffect(() => {
    void loadCodes();
  }, [loadCodes]);

  useEffect(() => {
    const ch = supabase
      .channel("mkt-enterprise")
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "discount_codes" },
        () => void loadCodes()
      )
      .subscribe();
    return () => {
      supabase.removeChannel(ch);
    };
  }, [supabase, loadCodes]);

  const sendSegment = async (segment: SegmentId) => {
    setSending(segment);
    setCampaignMsg(null);
    const to = previewEmails
      .split(/[,;\s]+/)
      .map((e) => e.trim())
      .filter(Boolean);
    try {
      const res = await fetch("/api/marketing/send-campaign", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          segment,
          previewEmails: to.length ? to : undefined,
          ...(campaignSubject.trim() ? { subject: campaignSubject.trim() } : {}),
          ...(campaignHtml.trim() ? { html: campaignHtml.trim() } : {}),
        }),
      });
      const j = (await res.json()) as { ok?: boolean; message?: string; error?: string };
      if (!res.ok) setCampaignMsg(j.error ?? "Error al enviar");
      else
        setCampaignMsg(
          j.message ??
            (j.ok
              ? "Campaña encolada correctamente."
              : "Respuesta recibida.")
        );
    } catch (e) {
      setCampaignMsg(e instanceof Error ? e.message : "Error de red");
    } finally {
      setSending(null);
    }
  };

  const toggleAuto = (k: keyof AutoState, v: boolean) => {
    const next = { ...auto, [k]: v };
    setAuto(next);
    saveAuto(next);
  };

  const crearCupon = async () => {
    setCodeErr(null);
    const code = newCode.trim().toUpperCase();
    if (!code) {
      setCodeErr("Código requerido.");
      return;
    }
    const pct = Number(newPct.replace(",", "."));
    if (!Number.isFinite(pct) || pct <= 0) {
      setCodeErr("Porcentaje inválido.");
      return;
    }
    const { error } = await supabase.from("discount_codes").insert({
      code,
      description: newDesc.trim() || null,
      percent_off: pct,
      active: true,
    });
    if (error) setCodeErr(error.message);
    else {
      setNewCode("");
      setNewDesc("");
      void loadCodes();
    }
  };

  const toggleCupon = async (id: string, active: boolean) => {
    await supabase.from("discount_codes").update({ active }).eq("id", id);
    void loadCodes();
  };

  const navItems: { id: NavId; label: string; icon: typeof Mail }[] = [
    { id: "campanas", label: "Campañas y segmentos", icon: Mail },
    { id: "auto", label: "Automatizaciones", icon: Zap },
    { id: "mapa", label: "Mapa promociones", icon: MapPinned },
    { id: "cupones", label: "Códigos descuento", icon: Tag },
  ];

  return (
    <div className="flex min-h-[calc(100vh-8rem)] flex-col gap-6 lg:flex-row lg:gap-8">
      <aside className="shrink-0 lg:w-56">
        <nav className="flex flex-row gap-1 overflow-x-auto rounded-2xl border border-slate-200 bg-white p-1 shadow-sm dark:border-slate-800 dark:bg-slate-900/60 lg:flex-col lg:overflow-visible">
          {navItems.map(({ id, label, icon: Icon }) => (
            <button
              key={id}
              type="button"
              onClick={() => setNav(id)}
              className={`flex items-center gap-2.5 rounded-xl px-3 py-2.5 text-left text-sm font-medium transition lg:w-full ${
                nav === id
                  ? "bg-indigo-600 text-white shadow-md"
                  : "text-slate-600 hover:bg-slate-50 dark:text-slate-400 dark:hover:bg-slate-800/80"
              }`}
            >
              <Icon className="h-4 w-4 shrink-0 opacity-90" />
              {label}
            </button>
          ))}
        </nav>
      </aside>

      <div className="min-w-0 flex-1 space-y-5">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div>
            <h2 className="text-lg font-bold text-slate-900 dark:text-white">
              Motor de retención
            </h2>
            <p className="text-xs text-slate-500">
              Resend API vía{" "}
              <code className="rounded bg-slate-100 px-1 dark:bg-slate-800">
                /api/marketing/send-campaign
              </code>
            </p>
          </div>
          <button
            type="button"
            onClick={() => void loadCodes()}
            className="inline-flex items-center gap-2 rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm shadow-sm dark:border-slate-700 dark:bg-slate-900"
          >
            <RefreshCw
              className={`h-4 w-4 ${codesLoading ? "animate-spin" : ""}`}
            />
            Refrescar datos
          </button>
        </div>

        {nav === "campanas" ? (
          <div className="space-y-5">
            <div className="rounded-2xl border border-indigo-100 bg-gradient-to-br from-indigo-50/80 to-white p-5 shadow-sm dark:border-indigo-900/40 dark:from-indigo-950/30 dark:to-slate-950">
              <div className="flex flex-wrap items-start gap-4">
                <div className="flex h-11 w-11 items-center justify-center rounded-xl bg-indigo-600 text-white shadow-lg shadow-indigo-500/30">
                  <Send className="h-5 w-5" />
                </div>
                <div className="min-w-0 flex-1">
                  <h3 className="font-semibold text-slate-900 dark:text-white">
                    Envío manual (Resend)
                  </h3>
                  <p className="mt-1 text-xs text-slate-600 dark:text-slate-400">
                    Configurá{" "}
                    <strong>RESEND_API_KEY</strong> y{" "}
                    <strong>RESEND_FROM</strong> en el servidor. Podés limitar a
                    correos de prueba separados por coma.
                  </p>
                  <input
                    value={previewEmails}
                    onChange={(e) => setPreviewEmails(e.target.value)}
                    placeholder="prueba1@dominio.com, prueba2@dominio.com"
                    className="mt-3 w-full max-w-xl rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm dark:border-slate-700 dark:bg-slate-900"
                  />
                  <input
                    value={campaignSubject}
                    onChange={(e) => setCampaignSubject(e.target.value)}
                    placeholder="Asunto (opcional — por defecto según segmento)"
                    className="mt-2 w-full max-w-xl rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm dark:border-slate-700 dark:bg-slate-900"
                  />
                  <textarea
                    value={campaignHtml}
                    onChange={(e) => setCampaignHtml(e.target.value)}
                    placeholder="HTML del correo (opcional)"
                    rows={3}
                    className="mt-2 w-full max-w-xl resize-y rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm dark:border-slate-700 dark:bg-slate-900"
                  />
                </div>
              </div>
              {campaignMsg ? (
                <p className="mt-3 text-sm text-indigo-800 dark:text-indigo-200">
                  {campaignMsg}
                </p>
              ) : null}
            </div>

            <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
              {SEGMENTS.map((s) => (
                <div
                  key={s.id}
                  className="flex flex-col rounded-2xl border border-slate-200 bg-white p-5 shadow-sm transition hover:border-indigo-200 hover:shadow-md dark:border-slate-800 dark:bg-slate-950 dark:hover:border-indigo-900/50"
                >
                  <div className="mb-3 flex items-start justify-between gap-2">
                    <Sparkles className="h-5 w-5 shrink-0 text-amber-500" />
                    <span className="rounded-md bg-slate-100 px-2 py-0.5 font-mono text-[10px] uppercase text-slate-500 dark:bg-slate-800">
                      {s.id}
                    </span>
                  </div>
                  <h4 className="font-semibold text-slate-900 dark:text-white">
                    {s.title}
                  </h4>
                  <p className="mt-2 flex-1 text-xs leading-relaxed text-slate-500 dark:text-slate-400">
                    {s.desc}
                  </p>
                  <p className="mt-3 text-[10px] text-slate-400">
                    La selección real de destinatarios debe resolverse en el
                    servidor (consulta a trips/perfiles) antes del envío masivo.
                  </p>
                  <button
                    type="button"
                    disabled={sending === s.id}
                    onClick={() => void sendSegment(s.id)}
                    className="mt-4 inline-flex items-center justify-center gap-2 rounded-xl bg-indigo-600 px-4 py-2.5 text-sm font-semibold text-white hover:bg-indigo-700 disabled:opacity-50"
                  >
                    {sending === s.id ? (
                      <Loader2 className="h-4 w-4 animate-spin" />
                    ) : (
                      <Mail className="h-4 w-4" />
                    )}
                    Enviar campaña
                  </button>
                </div>
              ))}
            </div>
          </div>
        ) : null}

        {nav === "auto" ? (
          <div className="space-y-4 rounded-2xl border border-slate-200 bg-white p-6 shadow-sm dark:border-slate-800 dark:bg-slate-950">
            <div className="mb-2 flex items-center gap-2">
              <Zap className="h-5 w-5 text-amber-500" />
              <h3 className="font-semibold text-slate-900 dark:text-white">
                Automatizaciones (cron / triggers)
              </h3>
            </div>
            <p className="mb-6 text-xs text-slate-500">
              Estado guardado en el navegador. En producción, enlazá estos flags
              a Edge Functions programadas o a filas en{" "}
              <code className="rounded bg-slate-100 px-1 dark:bg-slate-800">
                ai_automation_config
              </code>
              .
            </p>
            <div className="grid gap-4 md:grid-cols-1 lg:grid-cols-1">
              {(
                [
                  {
                    k: "birthday" as const,
                    title: "Saludos de cumpleaños",
                    desc: "Correo automático el día del cumpleaños (requiere fecha en perfil).",
                    icon: Cake,
                  },
                  {
                    k: "holidays" as const,
                    title: "Días festivos",
                    desc: "Campañas en calendario festivo (configurar fechas en servidor).",
                    icon: CalendarHeart,
                  },
                  {
                    k: "abandoned" as const,
                    title: "Viaje abandonado",
                    desc: "Recordatorio si el usuario dejó la solicitud sin completar.",
                    icon: Bell,
                  },
                ] as const
              ).map(({ k, title, desc, icon: Icon }) => (
                <div
                  key={k}
                  className="flex flex-col gap-3 rounded-xl border border-slate-100 p-4 sm:flex-row sm:items-center sm:justify-between dark:border-slate-800"
                >
                  <div className="flex gap-3">
                    <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-slate-100 dark:bg-slate-800">
                      <Icon className="h-5 w-5 text-slate-600 dark:text-slate-300" />
                    </div>
                    <div>
                      <p className="font-medium text-slate-900 dark:text-white">
                        {title}
                      </p>
                      <p className="text-xs text-slate-500">{desc}</p>
                      <p className="mt-1 font-mono text-[10px] text-slate-400">
                        {AUTO_KEYS[k]}
                      </p>
                    </div>
                  </div>
                  <button
                    type="button"
                    role="switch"
                    aria-checked={auto[k]}
                    onClick={() => toggleAuto(k, !auto[k])}
                    className={`relative h-9 w-16 shrink-0 rounded-full transition-colors ${
                      auto[k] ? "bg-emerald-500" : "bg-slate-300 dark:bg-slate-600"
                    }`}
                  >
                    <span
                      className={`absolute top-1 left-1 block h-7 w-7 rounded-full bg-white shadow transition-transform ${
                        auto[k] ? "translate-x-7" : "translate-x-0"
                      }`}
                    />
                  </button>
                </div>
              ))}
            </div>
          </div>
        ) : null}

        {nav === "mapa" ? (
          <div className="rounded-2xl border border-slate-200 bg-slate-950 p-4 dark:border-slate-800">
            <p className="mb-3 text-sm text-slate-400">
              Promociones geográficas — sincronización Realtime con el resto de
              paneles.
            </p>
            <MarketingPromoMapClient />
          </div>
        ) : null}

        {nav === "cupones" ? (
          <div className="space-y-5">
            <div className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm dark:border-slate-800 dark:bg-slate-950">
              <h3 className="mb-3 font-semibold text-slate-900 dark:text-white">
                Nuevo código
              </h3>
              {codeErr ? (
                <p className="mb-2 text-sm text-red-600">{codeErr}</p>
              ) : null}
              <div className="flex flex-col gap-3 sm:flex-row sm:flex-wrap">
                <input
                  value={newCode}
                  onChange={(e) => setNewCode(e.target.value)}
                  placeholder="Código"
                  className="rounded-xl border border-slate-200 px-3 py-2 text-sm dark:border-slate-700 dark:bg-slate-900"
                />
                <input
                  value={newPct}
                  onChange={(e) => setNewPct(e.target.value)}
                  className="w-24 rounded-xl border border-slate-200 px-3 py-2 text-sm dark:border-slate-700 dark:bg-slate-900"
                />
                <input
                  value={newDesc}
                  onChange={(e) => setNewDesc(e.target.value)}
                  placeholder="Descripción"
                  className="min-w-[200px] flex-1 rounded-xl border border-slate-200 px-3 py-2 text-sm dark:border-slate-700 dark:bg-slate-900"
                />
                <button
                  type="button"
                  onClick={() => void crearCupon()}
                  className="rounded-xl bg-indigo-600 px-4 py-2 text-sm font-semibold text-white"
                >
                  Crear
                </button>
              </div>
            </div>
            <div className="overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm dark:border-slate-800 dark:bg-slate-950">
              <div className="overflow-x-auto">
                <table className="w-full min-w-[520px] text-left text-sm">
                  <thead>
                    <tr className="border-b border-slate-100 bg-slate-50 text-xs font-semibold uppercase text-slate-500 dark:border-slate-800 dark:bg-slate-900/80">
                      <th className="px-4 py-3">Código</th>
                      <th className="px-4 py-3">%</th>
                      <th className="px-4 py-3">Usos</th>
                      <th className="px-4 py-3">Estado</th>
                      <th className="px-4 py-3 text-right">Acción</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100 dark:divide-slate-800">
                    {codes.map((r) => (
                      <tr key={r.id}>
                        <td className="px-4 py-2 font-mono font-medium">
                          {r.code}
                        </td>
                        <td className="px-4 py-2">{r.percent_off ?? "—"}</td>
                        <td className="px-4 py-2">
                          {r.uses_count}
                          {r.max_uses != null ? ` / ${r.max_uses}` : ""}
                        </td>
                        <td className="px-4 py-2">
                          {r.active ? "Activo" : "Pausado"}
                        </td>
                        <td className="px-4 py-2 text-right">
                          <button
                            type="button"
                            onClick={() => void toggleCupon(r.id, !r.active)}
                            className="text-xs font-semibold text-indigo-600 hover:underline dark:text-indigo-400"
                          >
                            {r.active ? "Pausar" : "Activar"}
                          </button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
                {codes.length === 0 ? (
                  <p className="py-10 text-center text-sm text-slate-500">
                    Sin cupones o tabla pendiente de migración.
                  </p>
                ) : null}
              </div>
            </div>
          </div>
        ) : null}
      </div>
    </div>
  );
}
