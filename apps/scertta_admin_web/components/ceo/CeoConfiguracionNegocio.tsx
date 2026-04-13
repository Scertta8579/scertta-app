"use client";

import { useCallback, useEffect, useState } from "react";
import { Bot, CreditCard, Loader2, Sparkles } from "lucide-react";
import { supabase } from "@/lib/supabaseClient";
import CeoContabilidadPanel from "./CeoContabilidadPanel";
import CeoModeloIngresosPanel from "./CeoModeloIngresosPanel";

const AI_FEATURE_KEY = "ai_level1_support";

function SwitchRow({
  id,
  label,
  description,
  checked,
  onChange,
  disabled = false,
}: {
  id: string;
  label: string;
  description: string;
  checked: boolean;
  onChange: (v: boolean) => void;
  disabled?: boolean;
}) {
  return (
    <div
      className={`flex items-start justify-between gap-4 rounded-xl border border-black/10 px-4 py-4 dark:border-white/10 ${
        disabled ? "opacity-50" : ""
      }`}
    >
      <div>
        <label htmlFor={id} className="text-sm font-medium">
          {label}
        </label>
        <p className="mt-1 text-xs text-apple-gray">{description}</p>
      </div>
      <button
        id={id}
        type="button"
        role="switch"
        aria-checked={checked}
        disabled={disabled}
        onClick={() => !disabled && onChange(!checked)}
        className={`relative inline-flex h-7 w-12 shrink-0 rounded-full transition-colors focus:outline-none focus-visible:ring-2 focus-visible:ring-scertta-blue disabled:pointer-events-none ${
          checked ? "bg-scertta-blue" : "bg-zinc-300 dark:bg-zinc-600"
        }`}
      >
        <span
          className={`pointer-events-none mt-0.5 inline-block h-6 w-6 rounded-full bg-white shadow transition ${
            checked ? "translate-x-5" : "translate-x-0.5"
          }`}
        />
      </button>
    </div>
  );
}

export default function CeoConfiguracionNegocio() {
  const [suscripcionPremium, setSuscripcionPremium] = useState(true);
  const [suscripcionComunidad, setSuscripcionComunidad] = useState(false);

  const [aiEnabled, setAiEnabled] = useState(false);
  const [aiLabel, setAiLabel] = useState("Soporte y reclamos Nivel 1 (IA)");
  const [aiLoading, setAiLoading] = useState(true);
  const [aiSaving, setAiSaving] = useState(false);
  const [aiError, setAiError] = useState<string | null>(null);

  const loadAiConfig = useCallback(async () => {
    setAiLoading(true);
    setAiError(null);
    const { data, error } = await supabase
      .from("ai_automation_config")
      .select("is_enabled,feature_name")
      .eq("feature_key", AI_FEATURE_KEY)
      .maybeSingle();
    if (error) {
      setAiError(error.message);
      setAiEnabled(false);
    } else if (data) {
      setAiEnabled(Boolean(data.is_enabled));
      if (data.feature_name) setAiLabel(data.feature_name);
    } else {
      setAiEnabled(false);
      setAiError(
        "No hay fila en ai_automation_config para ai_level1_support. Ejecutá las migraciones del back-office."
      );
    }
    setAiLoading(false);
  }, []);

  useEffect(() => {
    loadAiConfig();
  }, [loadAiConfig]);

  useEffect(() => {
    const ch = supabase
      .channel("ceo-ai-config")
      .on(
        "postgres_changes",
        {
          event: "*",
          schema: "public",
          table: "ai_automation_config",
          filter: `feature_key=eq.${AI_FEATURE_KEY}`,
        },
        () => {
          void loadAiConfig();
        }
      )
      .subscribe();
    return () => {
      supabase.removeChannel(ch);
    };
  }, [loadAiConfig]);

  const persistAi = async (enabled: boolean) => {
    setAiSaving(true);
    setAiError(null);
    const { error } = await supabase
      .from("ai_automation_config")
      .update({
        is_enabled: enabled,
        updated_at: new Date().toISOString(),
      })
      .eq("feature_key", AI_FEATURE_KEY);
    if (error) {
      setAiError(error.message);
      await loadAiConfig();
    } else {
      setAiEnabled(enabled);
    }
    setAiSaving(false);
  };

  return (
    <div className="space-y-10">
      <div>
        <h2 className="text-2xl font-semibold tracking-tight">
          Configuración y negocio
        </h2>
        <p className="mt-1 max-w-2xl text-sm text-apple-gray">
          Contabilidad conectada a Supabase, agente de IA de atención desde{" "}
          <code className="rounded bg-black/5 px-1 dark:bg-white/10">
            ai_automation_config
          </code>
          , y parámetros comerciales locales hasta persistirlos en BD.
        </p>
      </div>

      <CeoContabilidadPanel />

      <CeoModeloIngresosPanel />

      <div className="rounded-2xl border border-black/10 bg-white p-6 shadow-sm dark:border-white/10 dark:bg-zinc-950">
        <div className="mb-4 flex items-center gap-2">
          <div className="rounded-lg bg-violet-500/10 p-2">
            <Bot className="h-5 w-5 text-violet-600 dark:text-violet-400" />
          </div>
          <div>
            <h3 className="font-semibold">Agente de IA — atención</h3>
            <p className="text-xs text-apple-gray">{aiLabel}</p>
          </div>
        </div>

        {aiError ? (
          <div
            role="alert"
            className="mb-3 rounded-xl border border-amber-500/40 bg-amber-500/10 px-3 py-2 text-xs text-amber-900 dark:text-amber-100"
          >
            {aiError}
          </div>
        ) : null}

        <div className="relative">
          {aiLoading ? (
            <div className="flex items-center gap-2 py-4 text-sm text-apple-gray">
              <Loader2 className="h-4 w-4 animate-spin" />
              Cargando configuración…
            </div>
          ) : (
            <SwitchRow
              id="ceo-ia-atencion"
              label="IA de atención al cliente (Nivel 1)"
              description="Cuando está activa, la IA puede responder antes de escalar a humanos. Se guarda en Supabase."
              checked={aiEnabled}
              onChange={(v) => void persistAi(v)}
              disabled={aiSaving}
            />
          )}
          {aiSaving ? (
            <p className="mt-2 flex items-center gap-1 text-xs text-apple-gray">
              <Loader2 className="h-3 w-3 animate-spin" />
              Guardando…
            </p>
          ) : null}
        </div>

        <p className="mt-4 flex items-start gap-1.5 text-xs text-apple-gray">
          <Sparkles className="mt-0.5 h-3.5 w-3.5 shrink-0" />
          Sincronizado en tiempo real si tenés Realtime habilitado en esa tabla.
        </p>
      </div>

      <div className="rounded-2xl border border-black/10 bg-white p-6 shadow-sm dark:border-white/10 dark:bg-zinc-950">
        <div className="mb-4 flex items-center gap-2">
          <div className="rounded-lg bg-emerald-500/10 p-2">
            <CreditCard className="h-5 w-5 text-emerald-600 dark:text-emerald-400" />
          </div>
          <div>
            <h3 className="font-semibold">Suscripciones y planes</h3>
            <p className="text-xs text-apple-gray">
              Activá o pausá ofertas comerciales (estado local del panel)
            </p>
          </div>
        </div>
        <div className="grid gap-3 sm:grid-cols-2">
          <SwitchRow
            id="ceo-sub-premium"
            label="Plan Premium conductores"
            description="Prioridad en asignaciones y métricas avanzadas."
            checked={suscripcionPremium}
            onChange={setSuscripcionPremium}
          />
          <SwitchRow
            id="ceo-sub-comunidad"
            label="Programa Comunidad solicitantes"
            description="Beneficios por frecuencia y referidos."
            checked={suscripcionComunidad}
            onChange={setSuscripcionComunidad}
          />
        </div>
      </div>
    </div>
  );
}
