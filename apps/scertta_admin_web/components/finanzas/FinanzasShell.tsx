"use client";

import { useState } from "react";
import {
  BookOpen, Calculator, Banknote, Wallet, AlertTriangle,
  FileText,
} from "lucide-react";
import { MobileSidebar, type NavItem } from "@/components/MobileSidebar";
import CfoDashboard from "./CfoDashboard";
import GerenteConciliacionPanel from "@/components/ceo/GerenteConciliacionPanel";
import GerenteContabilidadPanel from "@/components/ceo/GerenteContabilidadPanel";
import GerenteContabilidadFiscalModule from "@/components/ceo/GerenteContabilidadFiscalModule";
import GerenteLiquidacionesWallet from "@/components/ceo/GerenteLiquidacionesWallet";
import GerenteRiesgoBilleterasPanel from "@/components/ceo/GerenteRiesgoBilleterasPanel";

type TabId =
  | "libro_mayor" | "arca" | "contabilidad" | "fiscal"
  | "liquidaciones" | "riesgo";

interface TabDef {
  id: TabId;
  label: string;
  icon: React.ReactNode;
}

const TABS: TabDef[] = [
  { id: "libro_mayor", label: "Libro Mayor", icon: <BookOpen size={18} /> },
  { id: "arca", label: "ARCA", icon: <Calculator size={18} /> },
  { id: "contabilidad", label: "Contabilidad", icon: <Banknote size={18} /> },
  { id: "fiscal", label: "Fiscal", icon: <FileText size={18} /> },
  { id: "liquidaciones", label: "Liquidaciones", icon: <Wallet size={18} /> },
  { id: "riesgo", label: "Riesgo", icon: <AlertTriangle size={18} /> },
];

export default function FinanzasShell() {
  const [tab, setTab] = useState<TabId>("libro_mayor");

  const navItems: NavItem[] = TABS.map((t) => ({
    id: t.id,
    label: t.label,
    icon: t.icon,
    onClick: () => setTab(t.id),
  }));

  return (
    <MobileSidebar
      items={navItems}
      activeId={tab}
      headerLabel="Control Financiero"
      headerSub="CFO"
      onNavigate={(id) => setTab(id as TabId)}
    >
      <div className="min-h-full bg-rutmy-sand dark:bg-rutmy-deep">
        {tab === "libro_mayor" && (
          <div id="finanzas-tab-libro-mayor" role="tabpanel"><CfoDashboard /></div>
        )}
        {tab === "arca" && (
          <div id="finanzas-tab-arca" role="tabpanel"><GerenteConciliacionPanel /></div>
        )}
        {tab === "contabilidad" && (
          <div id="finanzas-tab-contabilidad" role="tabpanel"><GerenteContabilidadPanel /></div>
        )}
        {tab === "fiscal" && (
          <div id="finanzas-tab-fiscal" role="tabpanel"><GerenteContabilidadFiscalModule /></div>
        )}
        {tab === "liquidaciones" && (
          <div id="finanzas-tab-liquidaciones" role="tabpanel"><GerenteLiquidacionesWallet /></div>
        )}
        {tab === "riesgo" && (
          <div id="finanzas-tab-riesgo" role="tabpanel"><GerenteRiesgoBilleterasPanel /></div>
        )}
      </div>
    </MobileSidebar>
  );
}
