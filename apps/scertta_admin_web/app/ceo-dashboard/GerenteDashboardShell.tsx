"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useTheme } from "@/components/ThemeProvider";
import { MobileSidebar, type NavItem } from "@/components/MobileSidebar";
import {
  Map, Truck, Package, Sliders, TrendingUp, BarChart3 as ChartIcon,
  DollarSign, Bot, Activity, Users, ChevronDown, Radio,
  Server,
} from "lucide-react";
import GerenteFlotaPanel from "@/components/ceo/GerenteFlotaPanel";
import GerenteDespachoPanel from "@/components/ceo/GerenteDespachoPanel";
import GerenteValoresPanel from "@/components/ceo/GerenteValoresPanel";
import GerenteAnaliticaOperaciones from "@/components/ceo/GerenteAnaliticaOperaciones";
import GerenteTarifarioPanel from "@/components/ceo/GerenteTarifarioPanel";
import GerenteDataScienceReportes from "@/components/ceo/GerenteDataScienceReportes";
import GerenteAgentesPanel from "@/components/ceo/GerenteAgentesPanel";
import GerenteModeloIngresosPanel from "@/components/ceo/GerenteModeloIngresosPanel";
import GerenteKpisPanel from "@/components/ceo/GerenteKpisPanel";
import ArchitectureDiagram from "@/components/ceo/ArchitectureDiagram";

type TabId =
  | "flota" | "despacho" | "valores" | "modelo_ingresos"
  | "kpis" | "analitica" | "tarifas" | "data"
  | "agentes" | "infra";

interface TabDef {
  id: TabId;
  label: string;
  icon: React.ReactNode;
}

const TABS: TabDef[] = [
  { id: "flota", label: "Flota OCA", icon: <Truck size={18} /> },
  { id: "despacho", label: "Despacho", icon: <Package size={18} /> },
  { id: "valores", label: "Valores", icon: <Sliders size={18} /> },
  { id: "modelo_ingresos", label: "Ingresos", icon: <TrendingUp size={18} /> },
  { id: "kpis", label: "KPIs", icon: <Activity size={18} /> },
  { id: "analitica", label: "Analítica", icon: <ChartIcon size={18} /> },
  { id: "tarifas", label: "Tarifario", icon: <DollarSign size={18} /> },
  { id: "data", label: "Data Science", icon: <ChartIcon size={18} /> },
  { id: "agentes", label: "IA Agentes", icon: <Bot size={18} /> },
  { id: "infra", label: "Infraestructura", icon: <Server size={18} /> },
];

const MAPA_SUBITEMS = [
  { id: "pasajeros", label: "Pasajeros", icon: <Users size={15} />, route: "/gerencia/mapas/pasajeros" },
  { id: "envios_livianos", label: "Envíos Livianos", icon: <Package size={15} />, route: "/gerencia/mapas/envios-livianos" },
  { id: "carga_pesada", label: "Carga Pesada", icon: <Truck size={15} />, route: "/gerencia/mapas/carga-pesada" },
  { id: "torre_control", label: "Torre de Control", icon: <Radio size={15} />, route: "/gerencia/mapas/torre-de-control" },
];

export default function GerenteDashboardShell() {
  const [tab, setTab] = useState<TabId>("flota");
  const [mapasAbierto, setMapasAbierto] = useState(false);
  const router = useRouter();
  const { theme } = useTheme();
  const isDark = theme === "dark";

  const navItems: NavItem[] = [
    // ── Mapas con submenú ──
    {
      id: "mapas",
      label: "Mapas",
      icon: <Map size={18} />,
      onClick: () => setMapasAbierto(!mapasAbierto),
    },
    // ── Sub-items de Mapas (solo visibles cuando está expandido) ──
    ...(mapasAbierto ? MAPA_SUBITEMS.map(m => ({
      id: `mapa-${m.id}`,
      label: m.label,
      icon: m.icon,
      onClick: () => router.push(m.route),
    })) : []),
    // ── Resto de tabs ──
    ...TABS.map((t) => ({
      id: t.id,
      label: t.label,
      icon: t.icon,
      onClick: () => setTab(t.id),
    })),
  ];

  const cs = {
    bg: isDark ? "bg-rutmy-deep" : "bg-rutmy-sand",
  };

  return (
    <MobileSidebar
      items={navItems}
      activeId={tab}
      headerLabel="Panel Gerente"
      headerSub="Rutmy"
      onNavigate={(id) => {
        // Solo para items que NO son mapa ni sub-mapa
        if (!id.startsWith("mapa-") && id !== "mapas") {
          setTab(id as TabId);
        }
      }}
    >
      <div className={`min-h-full ${cs.bg}`}>
        {tab === "flota" && (
          <div id="ceo-tab-flota" role="tabpanel"><GerenteFlotaPanel /></div>
        )}
        {tab === "despacho" && (
          <div id="ceo-tab-despacho" role="tabpanel"><GerenteDespachoPanel /></div>
        )}
        {tab === "valores" && (
          <div id="ceo-tab-valores" role="tabpanel"><GerenteValoresPanel /></div>
        )}
        {tab === "modelo_ingresos" && (
          <div id="ceo-tab-modelo-ingresos" role="tabpanel"><GerenteModeloIngresosPanel /></div>
        )}
        {tab === "kpis" && (
          <div id="ceo-tab-kpis" role="tabpanel"><GerenteKpisPanel /></div>
        )}
        {tab === "analitica" && (
          <div id="ceo-tab-analitica" role="tabpanel"><GerenteAnaliticaOperaciones /></div>
        )}
        {tab === "tarifas" && (
          <div id="ceo-tab-tarifas" role="tabpanel"><GerenteTarifarioPanel /></div>
        )}
        {tab === "data" && (
          <div id="ceo-tab-data" role="tabpanel"><GerenteDataScienceReportes /></div>
        )}
        {tab === "agentes" && (
          <div id="ceo-tab-agentes" role="tabpanel"><GerenteAgentesPanel /></div>
        )}
        {tab === "infra" && (
          <div id="ceo-tab-infra" role="tabpanel" className="p-4"><ArchitectureDiagram /></div>
        )}
      </div>
    </MobileSidebar>
  );
}
