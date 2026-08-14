"use client";

import { useEffect, useState, useMemo } from "react";
import { supabase } from "@/lib/supabaseClient";
import {
  PlusCircle, UserPlus, PauseCircle, XCircle,
  Clock, Building2, ChevronDown, ChevronUp, Filter,
  FileJson, History, Search, X as XIcon,
} from "lucide-react";

// ═══════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════

interface AuditoriaRecord {
  id: string;
  franquicia_id: string;
  accion: string;
  detalle: Record<string, any> | null;
  created_at: string;
  franquicias?: { nombre: string } | null;
  origen?: string; // "auditoria" | "gerentes_historial"
}

interface FranquiciaOption {
  id: string;
  nombre: string;
}

type AccionType = "crear" | "agregar" | "suspender" | "rescindir" | "otro";

// ═══════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════

function clasificarAccion(accion: string): AccionType {
  const a = (accion || "").toLowerCase();
  if (a.includes("crear") || a.includes("creación") || a.includes("registro")) return "crear";
  if (a.includes("agregar") || a.includes("añadir") || a.includes("asignar") || a.includes("nuevo gerente")) return "agregar";
  if (a.includes("suspender") || a.includes("pausar") || a.includes("suspensión")) return "suspender";
  if (a.includes("rescindir") || a.includes("cancelar") || a.includes("eliminar") || a.includes("baja")) return "rescindir";
  return "otro";
}

const ACCION_CONFIG: Record<AccionType, { colorDot: string; colorBg: string; colorBorder: string; icon: React.ElementType; label: string }> = {
  crear:     { colorDot: "bg-rutmy-agua",     colorBg: "bg-rutmy-agua/10",     colorBorder: "border-rutmy-agua/30",     icon: PlusCircle,  label: "Creación" },
  agregar:   { colorDot: "bg-rutmy-agua",     colorBg: "bg-rutmy-agua/10",     colorBorder: "border-rutmy-agua/30",     icon: UserPlus,    label: "Agregado" },
  suspender: { colorDot: "bg-amber-500",       colorBg: "bg-amber-500/10",       colorBorder: "border-amber-500/30",       icon: PauseCircle, label: "Suspensión" },
  rescindir: { colorDot: "bg-red-500",         colorBg: "bg-red-500/10",         colorBorder: "border-red-500/30",         icon: XCircle,     label: "Rescisión" },
  otro:      { colorDot: "bg-rutmy-stone",     colorBg: "bg-white/5",            colorBorder: "border-white/10",           icon: Clock,       label: "Otro" },
};

function formatearTimestamp(iso: string): string {
  try {
    const d = new Date(iso);
    return d.toLocaleString("es-AR", {
      day: "2-digit", month: "short", year: "numeric",
      hour: "2-digit", minute: "2-digit", second: "2-digit",
    });
  } catch {
    return iso;
  }
}

// ═══════════════════════════════════════════════════════════════
// COMPONENT
// ═══════════════════════════════════════════════════════════════

export default function TimelineAuditoria() {
  const [eventos, setEventos] = useState<AuditoriaRecord[]>([]);
  const [franquicias, setFranquicias] = useState<FranquiciaOption[]>([]);
  const [loading, setLoading] = useState(true);

  // Filtros
  const [filtroFranquicia, setFiltroFranquicia] = useState<string>("");
  const [filtroAccion, setFiltroAccion] = useState<AccionType | "">("");
  const [busqueda, setBusqueda] = useState("");

  // Expansión de detalles
  const [expandidos, setExpandidos] = useState<Set<string>>(new Set());
  const [mostrarFiltros, setMostrarFiltros] = useState(false);

  // Paginación simple
  const [pagina, setPagina] = useState(1);
  const POR_PAGINA = 30;

  // ── Cargar datos ──
  useEffect(() => {
    (async () => {
      setLoading(true);
      try {
        // Auditoría general
        const { data: auditoria } = await supabase
          .from("franquicia_auditoria")
          .select("*, franquicias(nombre)")
          .order("created_at", { ascending: false })
          .limit(500);

        // Historial de gerentes
        const { data: historial } = await supabase
          .from("franquicia_gerentes_historial")
          .select("*, franquicias(nombre)")
          .order("created_at", { ascending: false })
          .limit(500);

        // Unificar y ordenar
        const todas: AuditoriaRecord[] = [
          ...(auditoria || []).map((r: any) => ({ ...r, origen: "auditoria" })),
          ...(historial || []).map((r: any) => ({ ...r, origen: "gerentes_historial" })),
        ].sort((a, b) =>
          new Date(b.created_at).getTime() - new Date(a.created_at).getTime()
        );

        setEventos(todas);

        // Extraer franquicias únicas para filtro
        const mapa = new Map<string, string>();
        for (const e of todas) {
          if (!mapa.has(e.franquicia_id)) {
            mapa.set(e.franquicia_id, e.franquicias?.nombre || e.franquicia_id);
          }
        }
        const opciones = Array.from(mapa.entries()).map(([id, nombre]) => ({ id, nombre }));
        opciones.sort((a, b) => a.nombre.localeCompare(b.nombre));
        setFranquicias(opciones);
      } catch (err) {
        console.error("Error cargando timeline:", err);
      } finally {
        setLoading(false);
      }
    })();
  }, []);

  // ── Filtrar ──
  const eventosFiltrados = useMemo(() => {
    let resultado = eventos;

    if (filtroFranquicia) {
      resultado = resultado.filter((e) => e.franquicia_id === filtroFranquicia);
    }

    if (filtroAccion) {
      resultado = resultado.filter((e) => clasificarAccion(e.accion) === filtroAccion);
    }

    if (busqueda.trim()) {
      const q = busqueda.toLowerCase();
      resultado = resultado.filter((e) =>
        e.accion.toLowerCase().includes(q) ||
        (e.franquicias?.nombre || "").toLowerCase().includes(q) ||
        JSON.stringify(e.detalle || {}).toLowerCase().includes(q)
      );
    }

    return resultado;
  }, [eventos, filtroFranquicia, filtroAccion, busqueda]);

  // ── Paginar ──
  const totalPaginas = Math.ceil(eventosFiltrados.length / POR_PAGINA);
  const eventosPaginados = eventosFiltrados.slice(0, pagina * POR_PAGINA);

  // ── Toggle expandir ──
  const toggleExpandir = (id: string) => {
    setExpandidos((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  // ── Conteo por tipo ──
  const conteos = useMemo(() => {
    const c: Record<AccionType, number> = { crear: 0, agregar: 0, suspender: 0, rescindir: 0, otro: 0 };
    for (const e of eventosFiltrados) {
      c[clasificarAccion(e.accion)]++;
    }
    return c;
  }, [eventosFiltrados]);

  // ── Cargando ──
  if (loading) {
    return (
      <div className="flex items-center justify-center py-20">
        <div className="animate-spin rounded-full h-8 w-8 border-4 border-rutmy-agua/30 border-t-rutmy-agua" />
      </div>
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // RENDER
  // ═══════════════════════════════════════════════════════════════
  return (
    <div className="space-y-4">
      {/* ── Cabecera con conteos ── */}
      <div className="flex items-center justify-between flex-wrap gap-2">
        <h3 className="text-lg font-bold flex items-center gap-2">
          <History size={20} className="text-rutmy-agua" />
          Línea de Tiempo de Auditoría
        </h3>
        <div className="flex items-center gap-1.5 flex-wrap">
          {(Object.keys(ACCION_CONFIG) as AccionType[]).map((tipo) => {
            if (tipo === "otro" && conteos.otro === 0) return null;
            const cfg = ACCION_CONFIG[tipo];
            const Icon = cfg.icon;
            return (
              <span
                key={tipo}
                className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-lg text-[11px] font-medium ${cfg.colorBg} ${cfg.colorBorder} border`}
              >
                <span className={`w-2 h-2 rounded-full ${cfg.colorDot}`} />
                <Icon size={11} />
                {conteos[tipo]}
              </span>
            );
          })}
          <span className="text-xs text-white/85">
            {eventosFiltrados.length} eventos
          </span>
        </div>
      </div>

      {/* ── Filtros ── */}
      <div className="space-y-2">
        {/* Barra de búsqueda */}
        <div className="relative">
          <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-white/85" />
          <input
            placeholder="Buscar eventos..."
            value={busqueda}
            onChange={(e) => { setBusqueda(e.target.value); setPagina(1); }}
            className="w-full pl-9 pr-3 py-2 rounded-xl border border-white/10 bg-white/5 text-sm text-white placeholder:text-white/60 outline-none focus:border-rutmy-agua transition"
          />
          {busqueda && (
            <button
              onClick={() => { setBusqueda(""); setPagina(1); }}
              className="absolute right-3 top-1/2 -translate-y-1/2 text-white/85 hover:text-white"
            >
              <XIcon size={14} />
            </button>
          )}
        </div>

        {/* Toggle filtros avanzados */}
        <button
          onClick={() => setMostrarFiltros(!mostrarFiltros)}
          className="flex items-center gap-1.5 text-xs text-white/85 hover:text-white transition"
        >
          <Filter size={13} />
          Filtros avanzados
          {mostrarFiltros ? <ChevronUp size={13} /> : <ChevronDown size={13} />}
        </button>

        {mostrarFiltros && (
          <div className="flex items-center gap-3 flex-wrap bg-white/5 border border-white/10 rounded-xl p-3">
            {/* Filtro por franquicia */}
            <select
              value={filtroFranquicia}
              onChange={(e) => { setFiltroFranquicia(e.target.value); setPagina(1); }}
              className="rounded-lg border border-white/10 bg-white/5 px-3 py-1.5 text-xs text-white outline-none focus:border-rutmy-agua transition"
            >
              <option value="">Todas las franquicias</option>
              {franquicias.map((f) => (
                <option key={f.id} value={f.id}>{f.nombre}</option>
              ))}
            </select>

            {/* Filtro por tipo de acción */}
            <select
              value={filtroAccion}
              onChange={(e) => { setFiltroAccion(e.target.value as AccionType | ""); setPagina(1); }}
              className="rounded-lg border border-white/10 bg-white/5 px-3 py-1.5 text-xs text-white outline-none focus:border-rutmy-agua transition"
            >
              <option value="">Todos los tipos</option>
              <option value="crear">Creación</option>
              <option value="agregar">Agregado</option>
              <option value="suspender">Suspensión</option>
              <option value="rescindir">Rescisión</option>
              <option value="otro">Otro</option>
            </select>

            {/* Limpiar filtros */}
            {(filtroFranquicia || filtroAccion) && (
              <button
                onClick={() => { setFiltroFranquicia(""); setFiltroAccion(""); setPagina(1); }}
                className="text-xs text-rutmy-agua hover:underline"
              >
                Limpiar filtros
              </button>
            )}
          </div>
        )}
      </div>

      {/* ── Timeline ── */}
      {eventosFiltrados.length === 0 ? (
        <div className="text-center py-16 text-white/85">
          <History size={40} className="mx-auto mb-3 opacity-30" />
          <p>No se encontraron eventos de auditoría.</p>
          {busqueda && <p className="text-xs mt-1">Intentá con otros términos de búsqueda.</p>}
        </div>
      ) : (
        <div className="relative">
          {/* Línea vertical central */}
          <div className="absolute left-[15px] top-0 bottom-0 w-0.5 bg-white/10" />

          <div className="space-y-0">
            {eventosPaginados.map((evento, idx) => {
              const tipo = clasificarAccion(evento.accion);
              const cfg = ACCION_CONFIG[tipo];
              const Icon = cfg.icon;
              const expandido = expandidos.has(evento.id);
              const nombreFranquicia = evento.franquicias?.nombre || evento.franquicia_id;
              const esPrimerDia = idx === 0 ||
                new Date(evento.created_at).toDateString() !==
                new Date(eventosPaginados[idx - 1]?.created_at).toDateString();

              return (
                <div key={evento.id}>
                  {/* Separador de día */}
                  {esPrimerDia && (
                    <div className="flex items-center gap-3 py-2 pl-9">
                      <div className="text-[10px] uppercase tracking-wider text-white/85 font-semibold">
                        {new Date(evento.created_at).toLocaleDateString("es-AR", {
                          weekday: "long", day: "numeric", month: "long", year: "numeric",
                        })}
                      </div>
                      <div className="flex-1 h-px bg-white/5" />
                    </div>
                  )}

                  {/* Evento */}
                  <div className="relative pl-9 pb-3">
                    {/* Punto */}
                    <div className={`absolute left-[9px] top-4 w-3.5 h-3.5 rounded-full border-2 border-rutmy-deep ${cfg.colorDot} z-10 ring-2 ring-rutmy-deep`} />

                    {/* Tarjeta */}
                    <div
                      className={`rounded-xl border ${cfg.colorBorder} ${cfg.colorBg} p-3 cursor-pointer hover:brightness-110 transition`}
                      onClick={() => toggleExpandir(evento.id)}
                    >
                      {/* Cabecera */}
                      <div className="flex items-start justify-between gap-3">
                        <div className="flex items-start gap-2.5 min-w-0 flex-1">
                          <Icon size={16} className={`shrink-0 mt-0.5 ${tipo === "crear" ? "text-rutmy-agua" : tipo === "agregar" ? "text-rutmy-agua" : tipo === "suspender" ? "text-amber-400" : tipo === "rescindir" ? "text-red-400" : "text-white/85"}`} />
                          <div className="min-w-0">
                            <p className="text-sm font-semibold truncate">{evento.accion}</p>
                            <div className="flex items-center gap-2 mt-0.5 flex-wrap">
                              <span className="inline-flex items-center gap-1 text-[11px] text-white/85">
                                <Building2 size={10} />
                                {nombreFranquicia}
                              </span>
                              {evento.origen === "gerentes_historial" && (
                                <span className="text-[10px] px-1.5 py-0.5 rounded bg-white/10 text-white/85">
                                  Historial
                                </span>
                              )}
                            </div>
                          </div>
                        </div>
                        <div className="shrink-0 text-right">
                          <p className="text-[10px] text-white/85 whitespace-nowrap">
                            {formatearTimestamp(evento.created_at)}
                          </p>
                          <div className="flex items-center justify-end mt-1">
                            {expandido
                              ? <ChevronUp size={14} className="text-white/85" />
                              : <ChevronDown size={14} className="text-white/85" />
                            }
                          </div>
                        </div>
                      </div>

                      {/* Detalle expandido */}
                      {expandido && (
                        <div className="mt-3 pt-3 border-t border-white/10">
                          <div className="flex items-center gap-1.5 mb-2">
                            <FileJson size={12} className="text-white/85" />
                            <span className="text-[10px] uppercase tracking-wider text-white/85">Detalle del evento</span>
                          </div>
                          {evento.detalle && Object.keys(evento.detalle).length > 0 ? (
                            <pre className="text-[11px] text-white/90 bg-black/30 rounded-lg p-3 overflow-x-auto max-h-48 overflow-y-auto font-mono leading-relaxed">
                              {JSON.stringify(evento.detalle, null, 2)}
                            </pre>
                          ) : (
                            <p className="text-xs text-white/80 italic">Sin detalles adicionales.</p>
                          )}
                          <div className="mt-2 flex items-center gap-3 text-[10px] text-white/80">
                            <span>ID: {evento.id.slice(0, 8)}…</span>
                            <span>Origen: {evento.origen}</span>
                          </div>
                        </div>
                      )}
                    </div>
                  </div>
                </div>
              );
            })}
          </div>

          {/* Cargar más */}
          {pagina < totalPaginas && (
            <div className="pl-9 pb-4">
              <button
                onClick={() => setPagina((p) => p + 1)}
                className="w-full rounded-xl border border-white/10 bg-white/5 px-4 py-2.5 text-sm text-white/85 hover:bg-white/10 hover:text-white transition"
              >
                Cargar más eventos ({eventosFiltrados.length - eventosPaginados.length} restantes)
              </button>
            </div>
          )}

          {/* Final */}
          <div className="absolute left-[9px] bottom-0 w-3.5 h-3.5 rounded-full border-2 border-rutmy-deep bg-rutmy-stone/30 ring-2 ring-rutmy-deep" />
        </div>
      )}
    </div>
  );
}
