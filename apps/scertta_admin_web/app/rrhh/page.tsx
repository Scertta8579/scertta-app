"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { supabase } from "@/lib/supabaseClient";
import {
  LayoutDashboard, Users, FileText, Calendar, DollarSign,
  UserPlus, Clock, LogOut, Shield, ExternalLink,
  Building2, TrendingUp, MapPin,
} from "lucide-react";

type TabId = "dashboard" | "legajos" | "contrataciones" | "nomina" | "licencias";

const TABS: { id: TabId; label: string; icon: React.ElementType }[] = [
  { id: "dashboard", label: "Dashboard RRHH", icon: LayoutDashboard },
  { id: "legajos", label: "Legajos", icon: FileText },
  { id: "contrataciones", label: "Contrataciones", icon: UserPlus },
  { id: "nomina", label: "Nómina", icon: DollarSign },
  { id: "licencias", label: "Licencias", icon: Calendar },
];

export default function RRHHPage() {
  const router = useRouter();
  const [tab, setTab] = useState<TabId>("dashboard");
  const [loading, setLoading] = useState(true);
  const [perfil, setPerfil] = useState<any>(null);
  const [franquicia, setFranquicia] = useState<any>(null);
  const [provincia, setProvincia] = useState<any>(null);

  useEffect(() => {
    supabase.auth.getUser().then(async ({ data: { user } }) => {
      if (!user) { router.push("/login"); return; }
      const { data: p } = await supabase.from("perfiles")
        .select("rol, franquicia_id, email, nombre, apellido, provincia_activa_id")
        .eq("id", user.id).maybeSingle();
      if (!p) { router.push("/login"); return; }
      setPerfil(p);

      if (p.franquicia_id) {
        const { data: f } = await supabase.from("franquicias")
          .select("id, nombre, provincia_id, estado")
          .eq("id", p.franquicia_id).maybeSingle();
        setFranquicia(f);

        if (f?.provincia_id) {
          const { data: prov } = await supabase.from("provincias")
            .select("id, nombre, codigo")
            .eq("id", f.provincia_id).maybeSingle();
          setProvincia(prov);
        }
      }
      setLoading(false);
    });
  }, []);

  const cerrarSesion = async () => { await supabase.auth.signOut(); router.push("/login"); };
  const volverHub = () => router.push("/hub");

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-rutmy-sand">
        <div className="animate-spin rounded-full h-10 w-10 border-4 border-blue-400/30 border-t-blue-500" />
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-rutmy-sand">
      <header className="sticky top-0 z-40 border-b border-gray-200 bg-white/95 backdrop-blur">
        <div className="mx-auto flex w-full max-w-7xl items-center justify-between px-4 py-3 sm:px-6">
          <div className="flex items-center gap-3">
            <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-blue-500 text-white">
              <Users size={20} />
            </div>
            <div>
              <p className="text-xs text-rutmy-stone">
                Rutmy · {provincia?.nombre || franquicia?.nombre || "RRHH"}
              </p>
              <h1 className="text-base font-bold text-rutmy-deep flex items-center gap-2">
                RRHH & Nómina
                {provincia && (
                  <span className="text-xs font-normal text-rutmy-stone flex items-center gap-1">
                    <MapPin size={12} /> {provincia.nombre}
                  </span>
                )}
              </h1>
            </div>
          </div>
          <div className="flex items-center gap-3">
            <button onClick={volverHub} className="text-xs text-rutmy-stone hover:text-rutmy-deep flex items-center gap-1">
              <ExternalLink size={12} /> Portal Hub
            </button>
            <button onClick={cerrarSesion} className="flex items-center gap-1 rounded-xl border border-red-200 bg-red-50 px-3 py-1.5 text-xs text-red-700 hover:bg-red-100">
              <LogOut size={14} /> Salir
            </button>
          </div>
        </div>
        <nav className="mx-auto flex w-full max-w-7xl gap-1 overflow-x-auto px-4 pb-3 sm:px-6">
          {TABS.map((t) => {
            const Icon = t.icon;
            const active = tab === t.id;
            return (
              <button key={t.id} onClick={() => setTab(t.id)}
                className={`flex shrink-0 items-center gap-2 rounded-xl px-4 py-2.5 text-sm font-medium transition ${
                  active ? "bg-blue-500 text-white shadow-sm" : "text-rutmy-stone hover:bg-blue-50"
                }`}>
                <Icon size={16} /> {t.label}
              </button>
            );
          })}
        </nav>
      </header>

      <main className="mx-auto w-full max-w-7xl px-4 py-8 sm:px-6">
        {tab === "dashboard" && <RRHHDashboard provincia={provincia} franquiciaId={franquicia?.id} />}
        {tab === "legajos" && <PlaceholderTab titulo={`Legajos del Personal — ${provincia?.nombre || ""}`} descripcion="Legajos digitales completos: datos personales, documentación, historial laboral, evaluaciones." icon={<FileText size={32} className="text-blue-400" />} />}
        {tab === "contrataciones" && <ContratacionesPanel provincia={provincia} />}
        {tab === "nomina" && <NominaPanel provincia={provincia} franquiciaId={franquicia?.id} />}
        {tab === "licencias" && <PlaceholderTab titulo={`Licencias y Ausencias — ${provincia?.nombre || ""}`} descripcion="Gestión de vacaciones, licencias por enfermedad, francos, y control de presentismo." icon={<Calendar size={32} className="text-amber-400" />} />}
      </main>
    </div>
  );
}

function RRHHDashboard({ provincia, franquiciaId }: any) {
  const provNombre = provincia?.nombre || "esta provincia";

  return (
    <div className="space-y-6">
      <h2 className="text-2xl font-bold text-rutmy-deep">
        Dashboard RRHH — {provNombre}
      </h2>
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <MetricaCard icon={Users} label="Empleados activos" value="—" color="text-blue-600" />
        <MetricaCard icon={UserPlus} label="Contrataciones mes" value="—" color="text-emerald-600" />
        <MetricaCard icon={Calendar} label="De vacaciones" value="—" color="text-amber-600" />
        <MetricaCard icon={DollarSign} label="Masa salarial" value="—" color="text-purple-600" />
      </div>
      <div className="bg-white border border-gray-200 rounded-2xl p-6">
        <h3 className="font-semibold text-rutmy-deep mb-3 flex items-center gap-2">
          <MapPin size={18} className="text-blue-500" /> Normativa laboral en {provNombre}
        </h3>
        <NormativaProvincia provincia={provincia} />
      </div>
    </div>
  );
}

function NormativaProvincia({ provincia }: any) {
  const nombre = provincia?.nombre || "";

  return (
    <div className="space-y-3 text-sm text-rutmy-stone">
      <p className="font-medium text-rutmy-deep">Requisitos obligatorios para recibos de sueldo (Art. 140 LCT):</p>
      <ul className="list-disc pl-5 space-y-1">
        <li>Nombre completo y CUIT del empleador</li>
        <li>Nombre completo y CUIL del trabajador</li>
        <li>Fecha de pago y período</li>
        <li>Categoría profesional y tipo de jornada</li>
        <li>Desglose de haberes (básico, antigüedad, presentismo, horas extras)</li>
        <li>Desglose de deducciones (jubilación, obra social, sindicato)</li>
        <li>Aportes patronales</li>
        <li>Importe neto a percibir</li>
        <li>Firma del empleador y trabajador</li>
      </ul>

      {nombre === "Buenos Aires" && (
        <>
          <p className="font-medium text-rutmy-deep mt-3">Normativa adicional CABA/BA:</p>
          <ul className="list-disc pl-5 space-y-1">
            <li>Registro en Libro de Sueldos Digital (AFIP)</li>
            <li>ART obligatoria para todo el personal</li>
            <li>Seguro de Vida Obligatorio (Dec. 1567/74)</li>
            <li>Convenio colectivo aplicable según actividad (UTA si corresponde)</li>
          </ul>
        </>
      )}
    </div>
  );
}

function ContratacionesPanel({ provincia }: any) {
  const provNombre = provincia?.nombre || "esta provincia";
  return (
    <div className="space-y-6">
      <h2 className="text-2xl font-bold text-rutmy-deep">Contrataciones — {provNombre}</h2>
      <div className="bg-white border border-gray-200 rounded-2xl p-6">
        <h3 className="font-semibold text-rutmy-deep mb-3">Alta temprana AFIP</h3>
        <p className="text-sm text-rutmy-stone mb-4">
          Todo nuevo empleado debe darse de alta en AFIP antes del inicio de la prestación.
          El registro se realiza a través del Libro de Sueldos Digital.
        </p>
        <div className="grid grid-cols-2 gap-3 text-sm">
          <div className="bg-blue-50 rounded-xl p-3">
            <p className="font-medium text-blue-800">Tipos de contratación</p>
            <p className="text-blue-600 text-xs mt-1">Relación de dependencia, monotributista, autónomo, prestador de servicios</p>
          </div>
          <div className="bg-amber-50 rounded-xl p-3">
            <p className="font-medium text-amber-800">Período de prueba</p>
            <p className="text-amber-600 text-xs mt-1">3 meses (LCT art. 92 bis). Hasta 6 meses para PyMEs y 12 meses para grandes empresas</p>
          </div>
        </div>
      </div>
    </div>
  );
}

function NominaPanel({ provincia, franquiciaId }: any) {
  const provNombre = provincia?.nombre || "esta provincia";
  return (
    <div className="space-y-6">
      <h2 className="text-2xl font-bold text-rutmy-deep">Nómina y Recibos — {provNombre}</h2>
      <div className="bg-white border border-gray-200 rounded-2xl p-6">
        <h3 className="font-semibold text-rutmy-deep mb-3">Requisitos del recibo de sueldo</h3>
        <p className="text-sm text-rutmy-stone mb-4">
          Todo recibo debe cumplir estrictamente con el Art. 140 de la Ley de Contrato de Trabajo.
          La omisión de cualquiera de estos datos invalida el recibo como prueba de pago.
        </p>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 text-sm">
          <div className="bg-purple-50 rounded-xl p-3">
            <p className="font-medium text-purple-800">📋 Estructura obligatoria</p>
            <ul className="list-disc pl-4 text-purple-600 text-xs mt-1 space-y-0.5">
              <li>Datos del empleador (nombre + CUIT)</li>
              <li>Datos del trabajador (nombre + CUIL)</li>
              <li>Período y fecha de pago</li>
              <li>Categoría y jornada</li>
            </ul>
          </div>
          <div className="bg-emerald-50 rounded-xl p-3">
            <p className="font-medium text-emerald-800">💰 Desglose obligatorio</p>
            <ul className="list-disc pl-4 text-emerald-600 text-xs mt-1 space-y-0.5">
              <li>Haberes: básico, antigüedad, extras</li>
              <li>Deducciones: jubilación, OS, gremio</li>
              <li>Aportes patronales</li>
              <li>Neto a percibir + firmas</li>
            </ul>
          </div>
        </div>
      </div>
    </div>
  );
}

function PlaceholderTab({ titulo, descripcion, icon }: any) {
  return (
    <div className="flex flex-col items-center justify-center py-20 text-center">
      <div className="h-16 w-16 rounded-full bg-blue-50 flex items-center justify-center mb-4">
        {icon || <Clock size={32} className="text-blue-400" />}
      </div>
      <h2 className="text-xl font-bold text-rutmy-deep mb-2">{titulo}</h2>
      <p className="text-rutmy-stone max-w-md">{descripcion}</p>
      <p className="text-xs text-rutmy-stone/60 mt-4">Próximamente disponible</p>
    </div>
  );
}

function MetricaCard({ icon: Icon, label, value, color }: any) {
  return (
    <div className="bg-white border border-gray-200 rounded-2xl p-5">
      <Icon size={22} className={`${color} mb-2`} />
      <p className="text-2xl font-bold text-rutmy-deep">{value}</p>
      <p className="text-xs text-rutmy-stone mt-1">{label}</p>
    </div>
  );
}
