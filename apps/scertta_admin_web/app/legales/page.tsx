"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { supabase } from "@/lib/supabaseClient";
import {
  LayoutDashboard, Scale, FileText, Shield, Calendar,
  AlertTriangle, CheckCircle, Clock, Upload, LogOut,
  Building2, Car, ExternalLink, MapPin,
} from "lucide-react";

type TabId = "dashboard" | "contratos" | "habilitaciones" | "seguros" | "vencimientos";

const TABS: { id: TabId; label: string; icon: React.ElementType }[] = [
  { id: "dashboard", label: "Dashboard Legal", icon: LayoutDashboard },
  { id: "contratos", label: "Contratos", icon: FileText },
  { id: "habilitaciones", label: "Habilitaciones", icon: Building2 },
  { id: "seguros", label: "Seguros", icon: Shield },
  { id: "vencimientos", label: "Vencimientos", icon: Calendar },
];

export default function LegalesPage() {
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

      // Cargar franquicia y provincia
      if (p.franquicia_id) {
        const { data: f } = await supabase.from("franquicias")
          .select("id, nombre, provincia_id, estado, razon_social, cuit_franquicia")
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
        <div className="animate-spin rounded-full h-10 w-10 border-4 border-red-400/30 border-t-red-500" />
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-rutmy-sand">
      <header className="sticky top-0 z-40 border-b border-gray-200 bg-white/95 backdrop-blur">
        <div className="mx-auto flex w-full max-w-7xl items-center justify-between px-4 py-3 sm:px-6">
          <div className="flex items-center gap-3">
            <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-red-500 text-white">
              <Scale size={20} />
            </div>
            <div>
              <p className="text-xs text-rutmy-stone">
                Rutmy · {provincia?.nombre || franquicia?.nombre || "Legales"}
              </p>
              <h1 className="text-base font-bold text-rutmy-deep flex items-center gap-2">
                Legales
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
                  active ? "bg-red-500 text-white shadow-sm" : "text-rutmy-stone hover:bg-red-50"
                }`}>
                <Icon size={16} /> {t.label}
              </button>
            );
          })}
        </nav>
      </header>

      <main className="mx-auto w-full max-w-7xl px-4 py-8 sm:px-6">
        {tab === "dashboard" && <LegalesDashboard provincia={provincia} franquicia={franquicia} />}
        {tab === "contratos" && <ContratosPanel provincia={provincia} franquiciaId={franquicia?.id} />}
        {tab === "habilitaciones" && <HabilitacionesPanel provincia={provincia} />}
        {tab === "seguros" && <SegurosPanel provincia={provincia} franquiciaId={franquicia?.id} />}
        {tab === "vencimientos" && <VencimientosPanel provincia={provincia} />}
      </main>
    </div>
  );
}

function LegalesDashboard({ provincia, franquicia }: any) {
  const provNombre = provincia?.nombre || "esta provincia";

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h2 className="text-2xl font-bold text-rutmy-deep">
          Dashboard Legal — {provNombre}
        </h2>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <MetricaCard icon={FileText} label="Contratos activos" value="—" color="text-red-600" />
        <MetricaCard icon={Building2} label="Habilitaciones" value="—" color="text-amber-600" />
        <MetricaCard icon={Shield} label="Seguros vigentes" value="—" color="text-emerald-600" />
        <MetricaCard icon={AlertTriangle} label="Vencen este mes" value="—" color="text-red-500" />
      </div>

      <div className="bg-white border border-gray-200 rounded-2xl p-6">
        <h3 className="font-semibold text-rutmy-deep mb-3 flex items-center gap-2">
          <MapPin size={18} className="text-red-500" /> Requisitos legales en {provNombre}
        </h3>
        <div className="space-y-3 text-sm text-rutmy-stone">
          <RequisitosProvincia provincia={provincia} />
        </div>
      </div>

      {franquicia && (
        <div className="bg-white border border-gray-200 rounded-2xl p-6">
          <h3 className="font-semibold text-rutmy-deep mb-2">Datos de la franquicia</h3>
          <div className="grid grid-cols-2 gap-2 text-sm">
            <span className="text-rutmy-stone">Razón social:</span>
            <span className="font-medium">{franquicia.razon_social || "—"}</span>
            <span className="text-rutmy-stone">CUIT:</span>
            <span className="font-medium">{franquicia.cuit_franquicia || "—"}</span>
          </div>
        </div>
      )}
    </div>
  );
}

function RequisitosProvincia({ provincia }: any) {
  const nombre = provincia?.nombre || "";

  if (nombre === "Buenos Aires" || nombre === "CABA") {
    return (
      <ul className="list-disc pl-5 space-y-1">
        <li>Inscripción en Agencia Reguladora de Movilidad (GCBA)</li>
        <li>Seguro de responsabilidad civil para transporte de pasajeros</li>
        <li>Licencia de conductor profesional (categoría D1 o superior)</li>
        <li>VTV vigente para todos los vehículos</li>
        <li>Certificado de antecedentes penales para conductores</li>
        <li>Libros contables digitales (IGJ — TAD)</li>
        <li>Facturación electrónica AFIP</li>
      </ul>
    );
  }
  if (nombre === "Córdoba") {
    return (
      <ul className="list-disc pl-5 space-y-1">
        <li>Habilitación municipal de transporte (Municipalidad de Córdoba)</li>
        <li>Seguro de responsabilidad civil</li>
        <li>Licencia profesional provincial</li>
        <li>VTV vigente</li>
        <li>Registro provincial de plataformas de movilidad</li>
        <li>Facturación electrónica AFIP</li>
      </ul>
    );
  }

  return (
    <ul className="list-disc pl-5 space-y-1">
      <li>Habilitación municipal de transporte</li>
      <li>Seguro de responsabilidad civil para pasajeros</li>
      <li>Licencia de conductor profesional</li>
      <li>VTV vigente para todos los vehículos</li>
      <li>Facturación electrónica AFIP</li>
    </ul>
  );
}

function ContratosPanel({ provincia, franquiciaId }: any) {
  const provNombre = provincia?.nombre || "esta provincia";
  return <PlaceholderTab titulo={`Contratos — ${provNombre}`} descripcion="Gestión de contratos con conductores, proveedores y empleados. Firma digital y almacenamiento seguro con validez legal." icon={<FileText size={32} className="text-red-400" />} />;
}

function HabilitacionesPanel({ provincia }: any) {
  const provNombre = provincia?.nombre || "esta provincia";
  return <PlaceholderTab titulo={`Habilitaciones — ${provNombre}`} descripcion="Seguimiento de habilitaciones municipales, licencias de conductor profesional, y permisos de operación específicos de la provincia." icon={<Building2 size={32} className="text-amber-400" />} />;
}

function SegurosPanel({ provincia, franquiciaId }: any) {
  const provNombre = provincia?.nombre || "esta provincia";
  return <PlaceholderTab titulo={`Seguros — ${provNombre}`} descripcion="Control de pólizas de responsabilidad civil, ART, seguro de flota. Vencimientos y renovaciones." icon={<Shield size={32} className="text-emerald-400" />} />;
}

function VencimientosPanel({ provincia }: any) {
  const provNombre = provincia?.nombre || "esta provincia";
  return <PlaceholderTab titulo={`Vencimientos — ${provNombre}`} descripcion="Calendario de vencimientos legales: contratos, habilitaciones, seguros, VTV, libros contables. Alertas automáticas." icon={<Calendar size={32} className="text-purple-400" />} />;
}

function PlaceholderTab({ titulo, descripcion, icon }: any) {
  return (
    <div className="flex flex-col items-center justify-center py-20 text-center">
      <div className="h-16 w-16 rounded-full bg-red-50 flex items-center justify-center mb-4">
        {icon || <Clock size={32} className="text-red-400" />}
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
