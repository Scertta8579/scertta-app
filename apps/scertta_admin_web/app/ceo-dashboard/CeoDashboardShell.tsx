"use client";

import { useState } from "react";
import {
  BarChart3,
  CircleDollarSign,
  LayoutDashboard,
  LineChart,
  LogOut,
  MapPinned,
  SlidersHorizontal,
} from "lucide-react";
import { supabase } from "@/lib/supabaseClient";
import CeoDashboardMapClient from "./CeoDashboardMapClient";
import CeoAnaliticaOperaciones from "@/components/ceo/CeoAnaliticaOperaciones";
import CeoConfiguracionNegocio from "@/components/ceo/CeoConfiguracionNegocio";
import CeoDataScienceReportes from "@/components/ceo/CeoDataScienceReportes";
import CeoTarifarioPanel from "@/components/ceo/CeoTarifarioPanel";

type TabId = "mapa" | "analitica" | "tarifas" | "data" | "config";

const tabs: { id: TabId; label: string; icon: typeof MapPinned }[] = [
  { id: "mapa", label: "Mapa y promociones", icon: MapPinned },
  { id: "analitica", label: "Analítica y operaciones", icon: BarChart3 },
  { id: "tarifas", label: "Tarifario", icon: CircleDollarSign },
  { id: "data", label: "Data science e IA", icon: LineChart },
  { id: "config", label: "IA y negocio", icon: SlidersHorizontal },
];

export default function CeoDashboardShell() {
  const [tab, setTab] = useState<TabId>("mapa");
  const [cerrandoSesion, setCerrandoSesion] = useState(false);

  const cerrarSesion = async () => {
    setCerrandoSesion(true);
    try {
      await supabase.auth.signOut();
    } catch (e) {
      console.error("[ceo-dashboard] signOut", e);
    } finally {
      window.location.href = "/login";
    }
  };

  return (
    <div className="flex min-h-screen flex-col bg-background text-foreground">
      <header className="sticky top-0 z-40 border-b border-black/10 bg-white/95 backdrop-blur dark:border-white/10 dark:bg-black/95">
        <div className="mx-auto flex w-full max-w-7xl items-center justify-between gap-4 px-4 py-4 sm:px-6">
          <div className="flex min-w-0 items-center gap-3">
            <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-scertta-blue text-white">
              <LayoutDashboard className="h-5 w-5" />
            </div>
            <div className="min-w-0">
              <p className="truncate text-xs font-medium text-apple-gray">
                <span translate="no" className="notranslate">
                  Scertta
                </span>
              </p>
              <h1 className="truncate text-base font-semibold tracking-tight sm:text-lg">
                Panel CEO
              </h1>
            </div>
          </div>

          <div className="flex shrink-0 items-center gap-2 sm:gap-3">
            <span className="hidden rounded-full bg-scertta-blue/10 px-3 py-1 text-xs font-medium text-scertta-blue sm:inline">
              Control estratégico
            </span>
            <button
              type="button"
              onClick={cerrarSesion}
              disabled={cerrandoSesion}
              className="inline-flex items-center gap-2 rounded-xl border border-red-500/30 bg-red-500/5 px-3 py-2 text-sm font-medium text-red-700 transition hover:bg-red-500/10 disabled:opacity-60 dark:text-red-300"
            >
              <LogOut className="h-4 w-4" />
              <span className="hidden sm:inline">
                {cerrandoSesion ? "Saliendo…" : "Cerrar sesión"}
              </span>
            </button>
          </div>
        </div>

        <nav
          role="tablist"
          className="mx-auto flex w-full max-w-7xl gap-1 overflow-x-auto px-4 pb-3 sm:px-6"
          aria-label="Secciones del panel"
        >
          {tabs.map((t) => {
            const active = tab === t.id;
            const Icon = t.icon;
            return (
              <button
                key={t.id}
                type="button"
                role="tab"
                aria-selected={active}
                aria-controls={`ceo-tab-${t.id}`}
                id={`ceo-tab-trigger-${t.id}`}
                onClick={() => setTab(t.id)}
                className={`flex shrink-0 items-center gap-2 rounded-xl px-4 py-2.5 text-sm font-medium transition ${
                  active
                    ? "bg-scertta-blue text-white shadow-sm"
                    : "text-apple-gray hover:bg-black/5 dark:hover:bg-white/10"
                }`}
              >
                <Icon className="h-4 w-4" />
                {t.label}
              </button>
            );
          })}
        </nav>
      </header>

      <main className="mx-auto w-full max-w-7xl flex-1 px-4 py-8 sm:px-6">
        <div
          id="ceo-tab-mapa"
          role="tabpanel"
          aria-labelledby="ceo-tab-trigger-mapa"
          hidden={tab !== "mapa"}
          className={tab === "mapa" ? "block" : "hidden"}
        >
          <CeoDashboardMapClient />
        </div>

        <div
          id="ceo-tab-analitica"
          role="tabpanel"
          aria-labelledby="ceo-tab-trigger-analitica"
          hidden={tab !== "analitica"}
          className={tab === "analitica" ? "block" : "hidden"}
        >
          <CeoAnaliticaOperaciones />
        </div>

        <div
          id="ceo-tab-tarifas"
          role="tabpanel"
          aria-labelledby="ceo-tab-trigger-tarifas"
          hidden={tab !== "tarifas"}
          className={tab === "tarifas" ? "block" : "hidden"}
        >
          <CeoTarifarioPanel />
        </div>

        <div
          id="ceo-tab-data"
          role="tabpanel"
          aria-labelledby="ceo-tab-trigger-data"
          hidden={tab !== "data"}
          className={tab === "data" ? "block" : "hidden"}
        >
          <CeoDataScienceReportes />
        </div>

        <div
          id="ceo-tab-config"
          role="tabpanel"
          aria-labelledby="ceo-tab-trigger-config"
          hidden={tab !== "config"}
          className={tab === "config" ? "block" : "hidden"}
        >
          <CeoConfiguracionNegocio />
        </div>
      </main>
    </div>
  );
}
