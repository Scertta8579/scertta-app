"use client";

import { useCallback, useEffect, useState } from "react";
import {
  CalendarRange,
  Loader2,
  MapPin,
  Percent,
  Save,
  Sparkles,
  Truck,
} from "lucide-react";
import { supabase } from "@/lib/supabaseClient";
import { fetchCommissionConfig } from "@/lib/ceoDashboardMetrics";
import {
  addSurgeRule,
  loadSurgeRules,
  removeSurgeRule,
  type SurgeRule,
} from "@/lib/ceoSurgeRulesStorage";
import {
  loadReservaIncluyeEspera10min,
  saveReservaIncluyeEspera10min,
} from "@/lib/reservaTariffPrefsStorage";
import GerenteLiquidacionesWallet from "./GerenteLiquidacionesWallet";

type VehicleCat = "auto" | "moto" | "envio" | "reserva";

type FareRow = {
  categoria: VehicleCat;
  valor_base: number;
  valor_km: number;
  valor_min_viaje: number;
  valor_min_espera: number;
  peajes: number;
};

const CAT_META: Record<
  VehicleCat,
  { label: string; hint: string; icon: typeof Truck }
> = {
  auto: { label: "Auto", hint: "Servicio estándar", icon: Truck },
  moto: { label: "Moto", hint: "Movilidad liviana", icon: Truck },
  envio: {
    label: "Scertta Envíos",
    hint: "Cargas hasta 3500 kg",
    icon: Truck,
  },
  reserva: {
    label: "Reservas / programados",
    hint: "Viajes agendados",
    icon: CalendarRange,
  },
};

const CATS: VehicleCat[] = ["auto", "moto", "envio", "reserva"];

function emptyFare(c: VehicleCat): FareRow {
  return {
    categoria: c,
    valor_base: 0,
    valor_km: 0,
    valor_min_viaje: 0,
    valor_min_espera: 0,
    peajes: 0,
  };
}

type PanelTab = "base" | "surge" | "comisiones";

export default function CeoTarifarioPanel() {
  const [panelTab, setPanelTab] = useState<PanelTab>("base");
  const [fares, setFares] = useState<Record<VehicleCat, FareRow>>(() => {
    const o = {} as Record<VehicleCat, FareRow>;
    for (const c of CATS) o[c] = emptyFare(c);
    return o;
  });
  const [activeCat, setActiveCat] = useState<VehicleCat>("auto");
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [msg, setMsg] = useState<string | null>(null);
  const [reservaEspera10, setReservaEspera10] = useState(false);

  const [comScertta, setComScertta] = useState("10");
  const [gastosOp, setGastosOp] = useState("7.9");
  const [savingCom, setSavingCom] = useState(false);

  const [surgeRules, setSurgeRules] = useState<SurgeRule[]>([]);
  const [sn, setSn] = useState("");
  const [sm, setSm] = useState("1.5");
  const [ss, setSs] = useState("");
  const [se, setSe] = useState("");
  const [zoneLabel, setZoneLabel] = useState("");
  const [zoneGeojson, setZoneGeojson] = useState("");

  const load = useCallback(async () => {
    setLoading(true);
    setMsg(null);
    const { data, error } = await supabase
      .from("fare_config")
      .select(
        "categoria,valor_base,valor_km,valor_min_viaje,valor_min_espera,peajes"
      );
    if (!error && data?.length) {
      setFares((prev) => {
        const next = { ...prev };
        for (const row of data) {
          const c = row.categoria as VehicleCat;
          if (CATS.includes(c)) {
            next[c] = {
              categoria: c,
              valor_base: Number(row.valor_base),
              valor_km: Number(row.valor_km),
              valor_min_viaje: Number(row.valor_min_viaje),
              valor_min_espera: Number(row.valor_min_espera),
              peajes: Number(row.peajes),
            };
          }
        }
        return next;
      });
    }

    const cc = await fetchCommissionConfig(supabase);
    if (cc) {
      setComScertta(String(cc.comision_scertta_pct));
      setGastosOp(String(cc.gastos_operativos_pct));
    }

    setReservaEspera10(loadReservaIncluyeEspera10min());
    setSurgeRules(loadSurgeRules());
    setLoading(false);
  }, []); // eslint-disable-line react-hooks/exhaustive-deps -- carga inicial única

  useEffect(() => {
    void load();
  }, [load]);

  const saveFare = async (c: VehicleCat) => {
    setSaving(true);
    setMsg(null);
    const f = fares[c];
    const { error } = await supabase
      .from("fare_config")
      .update({
        valor_base: f.valor_base,
        valor_km: f.valor_km,
        valor_min_viaje: f.valor_min_viaje,
        valor_min_espera: f.valor_min_espera,
        peajes: f.peajes,
        updated_at: new Date().toISOString(),
      })
      .eq("categoria", c);
    setSaving(false);
    setMsg(error ? error.message : `Tarifas ${CAT_META[c].label} guardadas.`);
  };

  const saveCommission = async () => {
    setSavingCom(true);
    setMsg(null);
    const { error } = await supabase
      .from("commission_config")
      .update({
        comision_scertta_pct: Number(comScertta.replace(",", ".")),
        gastos_operativos_pct: Number(gastosOp.replace(",", ".")),
        updated_at: new Date().toISOString(),
      })
      .eq("id", 1);
    setSavingCom(false);
    setMsg(
      error
        ? error.message
        : "Porcentajes globales actualizados en commission_config."
    );
  };

  const patchFare = (c: VehicleCat, patch: Partial<FareRow>) => {
    setFares((prev) => ({ ...prev, [c]: { ...prev[c], ...patch } }));
  };

  const f = fares[activeCat];
  const Meta = CAT_META[activeCat];

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-semibold tracking-tight">
          Tarifario y demanda
        </h2>
        <p className="mt-1 max-w-3xl text-sm text-apple-gray">
          Edición de{" "}
          <code className="rounded bg-black/5 px-1 dark:bg-white/10">
            fare_config
          </code>{" "}
          por categoría, comisiones en{" "}
          <code className="rounded bg-black/5 px-1 dark:bg-white/10">
            commission_config
          </code>
          , y reglas de surge almacenadas en el navegador hasta crear{" "}
          <code className="rounded bg-black/5 px-1 dark:bg-white/10">
            surge_pricing_rules
          </code>{" "}
          (ver <code className="rounded bg-black/5 px-1 dark:bg-white/10">lib/ceoSchemaHints.ts</code>).
        </p>
      </div>

      <div
        role="tablist"
        className="flex flex-wrap gap-2 border-b border-black/10 pb-3 dark:border-white/10"
      >
        {(
          [
            ["base", "Tarifas base"],
            ["surge", "Tarifa dinámica (surge)"],
            ["comisiones", "Comisiones globales"],
          ] as const
        ).map(([id, label]) => (
          <button
            key={id}
            type="button"
            role="tab"
            aria-selected={panelTab === id}
            onClick={() => setPanelTab(id)}
            className={`rounded-xl px-4 py-2 text-sm font-medium transition ${
              panelTab === id
                ? "bg-rutmy-deep text-white shadow-sm"
                : "text-rutmy-slate hover:bg-rutmy-sand hover:text-rutmy-deep"
            }`}
          >
            {label}
          </button>
        ))}
      </div>

      {panelTab === "base" ? (
        <div className="grid gap-6 lg:grid-cols-[220px_1fr]">
          <nav className="flex flex-row flex-wrap gap-2 lg:flex-col">
            {CATS.map((c) => {
              const m = CAT_META[c];
              return (
                <button
                  key={c}
                  type="button"
                  onClick={() => setActiveCat(c)}
                  className={`flex items-center gap-2 rounded-xl border px-3 py-2.5 text-left text-sm font-medium transition ${
                    activeCat === c
                      ? "border-rutmy-agua bg-rutmy-agua/10 text-rutmy-agua"
                      : "border-black/10 hover:bg-black/5 dark:border-white/10 dark:hover:bg-white/10"
                  }`}
                >
                  <m.icon className="h-4 w-4 shrink-0 opacity-70" />
                  <span>{m.label}</span>
                </button>
              );
            })}
          </nav>

          <div className="rounded-2xl border border-black/10 bg-white p-6 dark:border-white/10 dark:bg-zinc-950">
            {loading ? (
              <div className="flex items-center gap-2 text-sm text-apple-gray">
                <Loader2 className="h-4 w-4 animate-spin" />
                Cargando tarifas…
              </div>
            ) : (
              <>
                <div className="mb-6 flex items-start gap-3">
                  <div className="rounded-xl bg-rutmy-agua/10 p-3 text-rutmy-agua">
                    <Meta.icon className="h-6 w-6" />
                  </div>
                  <div>
                    <h3 className="text-lg font-semibold">{Meta.label}</h3>
                    <p className="text-xs text-apple-gray">{Meta.hint}</p>
                  </div>
                </div>

                <div className="grid gap-4 sm:grid-cols-2">
                  <Field
                    label="Bajada de bandera (ARS)"
                    value={f.valor_base}
                    onChange={(v) => patchFare(activeCat, { valor_base: v })}
                  />
                  <Field
                    label="Precio × km (ARS)"
                    value={f.valor_km}
                    onChange={(v) => patchFare(activeCat, { valor_km: v })}
                  />
                  <Field
                    label="Precio × minuto de viaje (ARS)"
                    value={f.valor_min_viaje}
                    onChange={(v) =>
                      patchFare(activeCat, { valor_min_viaje: v })
                    }
                  />
                  <Field
                    label="Precio × minuto de espera (ARS)"
                    value={f.valor_min_espera}
                    onChange={(v) =>
                      patchFare(activeCat, { valor_min_espera: v })
                    }
                  />
                  <Field
                    label="Peajes (ARS fijo)"
                    value={f.peajes}
                    onChange={(v) => patchFare(activeCat, { peajes: v })}
                  />
                </div>

                {activeCat === "reserva" ? (
                  <div className="mt-6 rounded-xl border border-violet-500/25 bg-violet-500/5 p-4 dark:bg-violet-950/25">
                    <label className="flex cursor-pointer items-start gap-3">
                      <input
                        type="checkbox"
                        checked={reservaEspera10}
                        onChange={(e) => {
                          const v = e.target.checked;
                          setReservaEspera10(v);
                          saveReservaIncluyeEspera10min(v);
                        }}
                        className="mt-1 rounded border-black/20 accent-rutmy-agua"
                      />
                      <span>
                        <span className="font-medium">
                          Incluir automáticamente 10 minutos de espera
                        </span>
                        <span className="mt-1 block text-xs text-apple-gray">
                          Suma el equivalente a 10 min de espera a la tarifa de
                          reservas/programados. Persistido en navegador; en BD:
                          columna sugerida{" "}
                          <code className="rounded bg-black/5 px-1 dark:bg-white/10">
                            reserva_incluye_espera_10min
                          </code>{" "}
                          en{" "}
                          <code className="rounded bg-black/5 px-1 dark:bg-white/10">
                            fare_config
                          </code>
                          .
                        </span>
                      </span>
                    </label>
                  </div>
                ) : null}

                <button
                  type="button"
                  disabled={saving}
                  onClick={() => void saveFare(activeCat)}
                  className="mt-6 inline-flex items-center gap-2 rounded-xl bg-rutmy-agua px-5 py-2.5 text-sm font-semibold text-rutmy-deep disabled:opacity-50"
                >
                  {saving ? (
                    <Loader2 className="h-4 w-4 animate-spin" />
                  ) : (
                    <Save className="h-4 w-4" />
                  )}
                  Guardar categoría
                </button>
              </>
            )}
          </div>
        </div>
      ) : null}

      {panelTab === "surge" ? (
        <div className="grid gap-6 lg:grid-cols-2">
          <div className="rounded-2xl border border-black/10 bg-white p-6 dark:border-white/10 dark:bg-zinc-950">
            <div className="mb-4 flex items-center gap-2">
              <Sparkles className="h-5 w-5 text-amber-500" />
              <h3 className="font-semibold">Nueva regla de demanda</h3>
            </div>
            <p className="mb-4 text-xs text-apple-gray">
              Multiplicador sobre tarifa base en ventana horaria. Zona opcional
              (etiqueta + GeoJSON pegado).
            </p>
            <div className="space-y-3">
              <input
                placeholder="Nombre (ej. Lluvia CABA)"
                value={sn}
                onChange={(e) => setSn(e.target.value)}
                className="w-full rounded-xl border border-black/10 px-3 py-2 text-sm dark:border-white/15"
              />
              <div className="grid gap-3 sm:grid-cols-2">
                <input
                  placeholder="Multiplicador (ej. 1.5)"
                  value={sm}
                  onChange={(e) => setSm(e.target.value)}
                  className="rounded-xl border border-black/10 px-3 py-2 text-sm dark:border-white/15"
                />
                <input
                  placeholder="Etiqueta zona (ej. Microcentro)"
                  value={zoneLabel}
                  onChange={(e) => setZoneLabel(e.target.value)}
                  className="rounded-xl border border-black/10 px-3 py-2 text-sm dark:border-white/15"
                />
              </div>
              <input
                type="datetime-local"
                value={ss}
                onChange={(e) => setSs(e.target.value)}
                className="w-full rounded-xl border border-black/10 px-3 py-2 text-sm dark:border-white/15"
              />
              <input
                type="datetime-local"
                value={se}
                onChange={(e) => setSe(e.target.value)}
                className="w-full rounded-xl border border-black/10 px-3 py-2 text-sm dark:border-white/15"
              />
              <textarea
                placeholder='GeoJSON opcional (Polygon), ej. {"type":"Polygon","coordinates":[...]}'
                rows={3}
                value={zoneGeojson}
                onChange={(e) => setZoneGeojson(e.target.value)}
                className="w-full rounded-xl border border-black/10 px-3 py-2 font-mono text-xs dark:border-white/15"
              />
              <button
                type="button"
                onClick={() => {
                  const mult = Number(sm.replace(",", "."));
                  if (!sn.trim() || !Number.isFinite(mult) || mult < 1) return;
                  const startsAt = ss
                    ? new Date(ss).toISOString()
                    : new Date().toISOString();
                  const endsAt = se
                    ? new Date(se).toISOString()
                    : new Date(Date.now() + 3600000).toISOString();
                  const zg = zoneGeojson.trim();
                  const zl =
                    zoneLabel.trim() ||
                    (zg.startsWith("{") ? "Zona GeoJSON" : "Toda la red");
                  addSurgeRule({
                    name: sn.trim(),
                    multiplier: mult,
                    startsAt,
                    endsAt,
                    zoneLabel: zl,
                    zoneGeoJson: zg.startsWith("{") ? zg : "",
                    active: true,
                  });
                  setSurgeRules(loadSurgeRules());
                  setSn("");
                  setSm("1.5");
                  setSs("");
                  setSe("");
                  setZoneLabel("");
                  setZoneGeojson("");
                }}
                className="w-full rounded-xl bg-amber-600 px-4 py-2.5 text-sm font-semibold text-white hover:bg-amber-700"
              >
                Agregar regla (local)
              </button>
            </div>
          </div>

          <div className="rounded-2xl border border-black/10 bg-white p-6 dark:border-white/10 dark:bg-zinc-950">
            <h3 className="mb-4 flex items-center gap-2 font-semibold">
              <MapPin className="h-4 w-4" />
              Reglas activas (navegador)
            </h3>
            <ul className="max-h-[420px] space-y-3 overflow-auto text-sm">
              {surgeRules.length === 0 ? (
                <li className="text-apple-gray">No hay reglas guardadas.</li>
              ) : (
                surgeRules.map((r) => (
                  <li
                    key={r.id}
                    className="rounded-xl border border-black/10 p-3 dark:border-white/10"
                  >
                    <div className="flex items-start justify-between gap-2">
                      <div>
                        <p className="font-medium">{r.name}</p>
                        <p className="text-xs text-apple-gray">
                          ×{r.multiplier} · {r.zoneLabel}
                        </p>
                        <p className="mt-1 text-[11px] text-apple-gray">
                          {new Date(r.startsAt).toLocaleString("es-AR")} →{" "}
                          {new Date(r.endsAt).toLocaleString("es-AR")}
                        </p>
                      </div>
                      <button
                        type="button"
                        onClick={() => {
                          removeSurgeRule(r.id);
                          setSurgeRules(loadSurgeRules());
                        }}
                        className="text-xs font-medium text-red-600 hover:underline"
                      >
                        Quitar
                      </button>
                    </div>
                  </li>
                ))
              )}
            </ul>
          </div>
        </div>
      ) : null}

      {panelTab === "comisiones" ? (
        <div className="max-w-lg rounded-2xl border border-black/10 bg-white p-6 dark:border-white/10 dark:bg-zinc-950">
          <div className="mb-4 flex items-center gap-2">
            <Percent className="h-5 w-5 text-rutmy-agua" />
            <h3 className="font-semibold">Comisiones globales</h3>
          </div>
          <p className="mb-4 text-xs text-apple-gray">
            Misma fuente que usa el modelo fiscal del panel de contabilidad.
          </p>
          <div className="space-y-3">
            <div>
              <label className="text-xs font-medium text-apple-gray">
                Comisión Scertta (%)
              </label>
              <input
                value={comScertta}
                onChange={(e) => setComScertta(e.target.value)}
                className="mt-1 w-full rounded-xl border border-black/10 px-3 py-2 text-sm dark:border-white/15"
              />
            </div>
            <div>
              <label className="text-xs font-medium text-apple-gray">
                Gastos operativos / tarifa plataforma (%)
              </label>
              <input
                value={gastosOp}
                onChange={(e) => setGastosOp(e.target.value)}
                className="mt-1 w-full rounded-xl border border-black/10 px-3 py-2 text-sm dark:border-white/15"
              />
            </div>
            <button
              type="button"
              disabled={savingCom}
              onClick={() => void saveCommission()}
              className="inline-flex items-center gap-2 rounded-xl bg-rutmy-agua px-4 py-2.5 text-sm font-semibold text-rutmy-deep disabled:opacity-50"
            >
              {savingCom ? (
                <Loader2 className="h-4 w-4 animate-spin" />
              ) : (
                <Save className="h-4 w-4" />
              )}
              Guardar en Supabase
            </button>
          </div>
          <GerenteLiquidacionesWallet />
        </div>
      ) : null}

      {msg ? (
        <p className="text-sm text-apple-gray" role="status">
          {msg}
        </p>
      ) : null}
    </div>
  );
}

function Field({
  label,
  value,
  onChange,
}: {
  label: string;
  value: number;
  onChange: (n: number) => void;
}) {
  return (
    <div>
      <label className="text-xs font-medium text-apple-gray">{label}</label>
      <input
        type="number"
        min={0}
        step={0.01}
        value={Number.isFinite(value) ? value : 0}
        onChange={(e) => onChange(Number(e.target.value))}
        className="mt-1 w-full rounded-xl border border-black/10 px-3 py-2 text-sm dark:border-white/15"
      />
    </div>
  );
}
