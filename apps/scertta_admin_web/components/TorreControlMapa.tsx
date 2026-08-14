"use client";
import "@/lib/pmtiles-setup";

import { useState, useRef, useEffect, useCallback } from "react";
import Map, {
  NavigationControl, GeolocateControl,
  Source, Layer, Marker, Popup,
  type MapRef, type MapLayerMouseEvent,
} from "react-map-gl/maplibre";
import "maplibre-gl/dist/maplibre-gl.css";
import { supabase } from "@/lib/supabaseClient";
import {
  Search, Users, Package, Truck, Radio, Activity,
  AlertTriangle, MapPin, Phone, Car, X, CheckSquare,
  Square, Navigation, Clock, Gauge, Crosshair
} from "lucide-react";

// ────────────────────────────────────────────────────────────
// TYPES
// ────────────────────────────────────────────────────────────
type Coord = { lat: number; lng: number };

interface ActiveTrip {
  id: string;
  pasajero_id: string;
  conductor_id: string;
  status: string;
  origin_lat: number;
  origin_lng: number;
  dest_lat: number;
  dest_lng: number;
  route_polyline?: number[][];
  pasajero_nombre?: string;
  pasajero_telefono?: string;
  conductor_nombre?: string;
  conductor_telefono?: string;
  patente?: string;
  modelo?: string;
  started_at?: string;
}

interface PanicAlert {
  id: number;
  lng: number;
  lat: number;
  severity: string;
  trip_id: string | null;
  reporter_id: string | null;
  created_at: string;
  pasajero_nombre?: string;
  pasajero_telefono?: string;
  conductor_nombre?: string;
  conductor_telefono?: string;
  patente?: string;
  modelo?: string;
}

interface GPSPoint { lng: number; lat: number; recorded_at: string; speed_kmh?: number; }

// ────────────────────────────────────────────────────────────
// H3 HELPERS (lazy-loaded)
// ────────────────────────────────────────────────────────────
let H3: any = null;
async function loadH3() {
  if (!H3) { const m = await import("h3-js"); H3 = m; }
  return H3;
}

function bboxToCells(bbox: [number, number, number, number], res: number): string[] {
  if (!H3) return [];
  try {
    // bbox: [west, south, east, north]
    const cells: string[] = [];
    const [w, s, e, n] = bbox;
    const step = 0.02 * Math.pow(2, 7 - res);
    for (let lat = s; lat <= n; lat += step) {
      for (let lng = w; lng <= e; lng += step) {
        const cell = H3.latLngToCell(lat, lng, res);
        if (!cells.includes(cell)) cells.push(cell);
      }
    }
    // Deduplicate
    return [...new Set(cells)];
  } catch { return []; }
}

// ────────────────────────────────────────────────────────────
// COMPONENT
// ────────────────────────────────────────────────────────────
export default function TorreControlMapa() {
  const mapRef = useRef<MapRef | null>(null);
  const sosAudioRef = useRef<HTMLAudioElement | null>(null);

  // ── Map state ──
  const [viewState, setViewState] = useState({ longitude: -58.44, latitude: -34.6, zoom: 10 });
  const [mapLoaded, setMapLoaded] = useState(false);

  // ── Province ──
  const [provinceGeoJSON, setProvinceGeoJSON] = useState<any>(null);
  const [provinceName, setProvinceName] = useState("Cargando...");
  const [provinceId, setProvinceId] = useState<string | null>(null);

  // ── Layers ──
  const [showHeatmap, setShowHeatmap] = useState(true);
  const [hexCells, setHexCells] = useState<any[]>([]);

  // ── Trips ──
  const [activeTrips, setActiveTrips] = useState<ActiveTrip[]>([]);
  const [selectedTripIds, setSelectedTripIds] = useState<Set<string>>(new Set());
  const [gpsTracks, setGpsTracks] = useState<Record<string, GPSPoint[]>>({});

  // ── Search ──
  const [searchQuery, setSearchQuery] = useState("");
  const [searchResults, setSearchResults] = useState<ActiveTrip[]>([]);

  // ── Panic ──
  const [panicAlerts, setPanicAlerts] = useState<PanicAlert[]>([]);
  const [activeSOS, setActiveSOS] = useState<PanicAlert | null>(null);
  const [sosDetail, setSOSDetail] = useState<any>(null);

  // ── Sidebar ──
  const [sidebarOpen, setSidebarOpen] = useState(true);

  // ──────────────────────────────────────────────────
  // 1. LOAD PROVINCE + FIT BOUNDS
  // ──────────────────────────────────────────────────
  useEffect(() => {
    (async () => {
      // Get current user profile → franquicia → provincia
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;

      const { data: perfil } = await supabase.from("perfiles").select("franquicia_id, rol").eq("id", user.id).single();
      if (!perfil) return;

      // CEO sees all; gerente sees their franquicia's province
      let franchiseId = perfil.franquicia_id;
      if (perfil.rol === "ceo_admin") {
        // Try to get from any franquicia or use Buenos Aires as default
        const { data: anyF } = await supabase.from("franquicias").select("id, provincia_id").eq("estado", "activo").limit(1).single();
        if (anyF) franchiseId = anyF.id;
      }

      if (franchiseId) {
        const { data: franq } = await supabase.from("franquicias").select("provincia_id, nombre").eq("id", franchiseId).single();
        if (franq) {
          setProvinceId(franq.provincia_id);
          const { data: prov } = await supabase.from("provincias").select("nombre, config_json").eq("id", franq.provincia_id).single();
          if (prov) {
            setProvinceName(prov.nombre);
            const poly = prov.config_json?.poligono_geojson;
            const centro = prov.config_json?.centro_mapa;
            if (poly) {
              setProvinceGeoJSON(poly);
              // fitBounds
              setTimeout(() => {
                const map = mapRef.current?.getMap();
                if (map && poly.type === "Polygon") {
                  const coords = poly.coordinates[0] as [number, number][];
                  const lngs = coords.map(c => c[0]), lats = coords.map(c => c[1]);
                  map.fitBounds(
                    [[Math.min(...lngs), Math.min(...lats)], [Math.max(...lngs), Math.max(...lats)]],
                    { padding: 40, duration: 1500 }
                  );
                } else if (map && centro) {
                  map.flyTo({ center: [centro[1], centro[0]], zoom: 10, duration: 1500 });
                }
              }, 500);
            } else if (centro) {
              setViewState({ longitude: centro[1], latitude: centro[0], zoom: 10 });
            }
          }
        }
      }
    })();
  }, []);

  // ──────────────────────────────────────────────────
  // 2. LOAD ACTIVE TRIPS + GPIO TRACKS
  // ──────────────────────────────────────────────────
  const loadActiveTrips = useCallback(async () => {
    if (!provinceId) return;
    const { data } = await supabase
      .from("pasajeros.trips")
      .select("id, pasajero_id, conductor_id, status, origin, destination, route_polyline, started_at")
      .eq("status", "ongoing")
      .order("started_at", { ascending: false })
      .limit(50);

    if (!data?.length) { setActiveTrips([]); return; }

    // Get all user IDs
    const userIds = [...new Set(data.flatMap(t => [t.pasajero_id, t.conductor_id].filter(Boolean)))] as string[];

    // Get profiles
    const { data: perfiles } = await supabase.from("perfiles").select("id, nombre, apellido, telefono").in("id", userIds);
    const pfMap = new Map(perfiles?.map(p => [p.id, p]) || []);

    // Get vehicle for each driver
    const driverIds = [...new Set(data.map(t => t.conductor_id).filter(Boolean))] as string[];
    const { data: vehiculos } = driverIds.length ? await supabase.from("conductor_vehiculos").select("perfil_id, patente, marca, modelo").in("perfil_id", driverIds) : { data: [] };
    const vehMap = new Map(vehiculos?.map(v => [v.perfil_id, v]) || []);

    const trips: ActiveTrip[] = data.map(t => {
      const p = pfMap.get(t.pasajero_id);
      const c = pfMap.get(t.conductor_id);
      const v = vehMap.get(t.conductor_id);
      const origin = (t as any).origin?.coordinates || [0, 0];
      const dest = (t as any).destination?.coordinates || [0, 0];
      return {
        id: t.id, pasajero_id: t.pasajero_id, conductor_id: t.conductor_id,
        status: t.status,
        origin_lat: origin[1], origin_lng: origin[0],
        dest_lat: dest[1], dest_lng: dest[0],
        route_polyline: (t as any).route_polyline?.coordinates,
        pasajero_nombre: p ? `${p.nombre || ""} ${p.apellido || ""}`.trim() : "—",
        pasajero_telefono: p?.telefono || "—",
        conductor_nombre: c ? `${c.nombre || ""} ${c.apellido || ""}`.trim() : "—",
        conductor_telefono: c?.telefono || "—",
        patente: v?.patente || "—",
        modelo: v ? `${v.marca || ""} ${v.modelo || ""}`.trim() : "—",
        started_at: t.started_at,
      };
    });

    setActiveTrips(trips);
  }, [provinceId]);

  useEffect(() => { if (mapLoaded) loadActiveTrips(); }, [mapLoaded, loadActiveTrips]);

  // ──────────────────────────────────────────────────
  // 3. LOAD SELECTED TRIPS GPS HISTORY
  // ──────────────────────────────────────────────────
  useEffect(() => {
    if (selectedTripIds.size === 0) { setGpsTracks({}); return; }
    (async () => {
      const ids = [...selectedTripIds];
      const { data } = await supabase
        .from("trip_gps_history")
        .select("trip_id, location, recorded_at, speed_kmh")
        .in("trip_id", ids)
        .order("recorded_at", { ascending: true })
        .limit(2000);

      const tracks: Record<string, GPSPoint[]> = {};
      data?.forEach(row => {
        const coords = (row as any).location?.coordinates || [0, 0];
        if (!tracks[row.trip_id]) tracks[row.trip_id] = [];
        tracks[row.trip_id].push({
          lng: coords[0], lat: coords[1],
          recorded_at: row.recorded_at,
          speed_kmh: row.speed_kmh,
        });
      });
      setGpsTracks(tracks);
    })();
  }, [selectedTripIds]);

  // ──────────────────────────────────────────────────
  // 4. H3 HEATMAP (Demanda / Oferta)
  // ──────────────────────────────────────────────────
  useEffect(() => {
    if (!showHeatmap || !provinceGeoJSON || !mapLoaded) { setHexCells([]); return; }
    (async () => {
      await loadH3();
      if (!H3) return;

      // Get province bbox
      const coords = provinceGeoJSON.type === "Polygon"
        ? provinceGeoJSON.coordinates[0] as [number, number][]
        : [];
      if (!coords.length) return;
      const lngs = coords.map(c => c[0]), lats = coords.map(c => c[1]);
      const bbox: [number, number, number, number] = [Math.min(...lngs), Math.min(...lats), Math.max(...lngs), Math.max(...lats)];

      const res = provinceGeoJSON.coordinates[0].length < 50 ? 7 : 8;
      const cells = bboxToCells(bbox, res);
      if (!cells.length) return;

      // Get supply (driver positions)
      const { data: drivers } = await supabase.from("driver_positions").select("location").eq("is_online", true);
      const driverPoints: Coord[] = (drivers || []).map(d => {
        const c = (d as any).location?.coordinates || [0, 0];
        return { lng: c[0], lat: c[1] };
      });

      // Get demand (passenger searches)
      const { data: pax } = await supabase.from("passenger_searches").select("location").eq("status", "searching");
      const paxPoints: Coord[] = (pax || []).map(p => {
        const c = (p as any).location?.coordinates || [0, 0];
        return { lng: c[0], lat: c[1] };
      });

      // 🧪 DEMO DATA FALLBACK: if no real data, generate fake H3 heatmap
      const isDemo = driverPoints.length === 0 && paxPoints.length === 0;
      let demoDrivers: Record<string, number> = {};
      let demoPax: Record<string, number> = {};

      if (isDemo) {
        console.log("[H3] 🧪 Modo DEMO — generando datos sintéticos para Buenos Aires");
        // BA center: -34.6, -58.4
        const demoCells = cells.filter(() => Math.random() < 0.45);
        for (const cell of demoCells) {
          const [clat, clng] = H3.cellToLatLng(cell);
          // Only cells near BA area
          if (clat < -35.2 || clat > -34.0 || clng < -59.0 || clng > -57.8) continue;
          const d = Math.floor(Math.random() * 8);
          const p = Math.floor(Math.random() * 12);
          if (d > 0) demoDrivers[cell] = d;
          if (p > 0) demoPax[cell] = p;
        }
      }

      // Build hex features
      const features: any[] = [];
      for (const cell of cells) {
        const boundary = H3.cellToBoundary(cell) as [number, number][]; // H3 returns [lat, lng] ⚠️
        if (!boundary?.length) continue;
        // SWAP lat↔lng: MapLibre GeoJSON requires [lng, lat]
        const polyCoords = [boundary.map(([lat, lng]) => [lng, lat])];

        // Check if cell center is inside province bounding box
        const [clat, clng] = H3.cellToLatLng(cell);
        if (clng < bbox[0] || clng > bbox[2] || clat < bbox[1] || clat > bbox[3]) continue;

        // Count drivers and passengers within this hex
        const driversInCell = isDemo
          ? (demoDrivers[cell] || 0)
          : driverPoints.filter(d => {
              try { return H3.latLngToCell(d.lat, d.lng, res) === cell; } catch { return false; }
            }).length;
        const paxInCell = isDemo
          ? (demoPax[cell] || 0)
          : paxPoints.filter(p => {
              try { return H3.latLngToCell(p.lat, p.lng, res) === cell; } catch { return false; }
            }).length;

        if (driversInCell === 0 && paxInCell === 0) continue;

        // Color: green = supply > demand, red = demand > supply
        const ratio = driversInCell + paxInCell > 0 ? driversInCell / (driversInCell + paxInCell + 1) : 0.5;
        const r = Math.round(255 * (1 - ratio));
        const g = Math.round(255 * ratio);
        const color = `rgba(${r},${g},60,0.45)`;

        features.push({
          type: "Feature",
          geometry: { type: "Polygon", coordinates: polyCoords },
          properties: {
            drivers: driversInCell,
            passengers: paxInCell,
            color,
            cell,
            demo: isDemo,
          }
        });
      }

      setHexCells(features);
      console.log(`[H3] ${isDemo ? "🧪 DEMO" : "📡 LIVE"} — ${features.length} hexágonos generados. Muestra: [${features.slice(0,2).map(f => `${f.properties.drivers}🚗/${f.properties.passengers}👤`).join(", ")}...]`);
    })();
  }, [showHeatmap, provinceGeoJSON, mapLoaded]);

  // ──────────────────────────────────────────────────
  // 5. SEARCH
  // ──────────────────────────────────────────────────
  useEffect(() => {
    if (!searchQuery || searchQuery.length < 3) { setSearchResults([]); return; }
    const t = setTimeout(async () => {
      const q = searchQuery.trim();
      // Search by trip ID
      if (q.length === 36 && q.includes("-")) {
        const { data } = await supabase.from("pasajeros.trips").select("id").eq("id", q).limit(1);
        if (data?.length) {
          setSearchResults(activeTrips.filter(t => t.id === q));
          return;
        }
      }
      // Search by phone
      const { data: perfiles } = await supabase.from("perfiles").select("id, nombre, apellido, telefono").or(`telefono.ilike.%${q}%,email.ilike.%${q}%`).limit(10);
      const ids = perfiles?.map(p => p.id) || [];
      if (ids.length) {
        const matches = activeTrips.filter(t => ids.includes(t.pasajero_id) || ids.includes(t.conductor_id));
        setSearchResults(matches);
      } else {
        setSearchResults([]);
      }
    }, 400);
    return () => clearTimeout(t);
  }, [searchQuery, activeTrips]);

  // ──────────────────────────────────────────────────
  // 6. REAL-TIME PANIC / SOS (Supabase Realtime)
  // ──────────────────────────────────────────────────
  useEffect(() => {
    const channel = supabase
      .channel("torre-control-sos")
      .on("postgres_changes",
        { event: "INSERT", schema: "public", table: "security_incidents", filter: "incident_type=eq.panic_button" },
        async (payload: any) => {
          const inc = payload.new;
          const coords = inc.location?.coordinates || [0, 0];
          const alert: PanicAlert = {
            id: inc.id, lng: coords[0], lat: coords[1],
            severity: inc.severity, trip_id: inc.trip_id,
            reporter_id: inc.reporter_id, created_at: inc.created_at,
          };

          // Get passenger + driver + vehicle details
          let detail: any = {};
          if (inc.trip_id) {
            const { data: trip } = await supabase.from("pasajeros.trips").select("pasajero_id, conductor_id").eq("id", inc.trip_id).single();
            if (trip) {
              const { data: perfiles } = await supabase.from("perfiles").select("id, nombre, apellido, telefono").in("id", [trip.pasajero_id, trip.conductor_id].filter(Boolean));
              const pfMap = new Map(perfiles?.map(p => [p.id, p]) || []);
              const pax = pfMap.get(trip.pasajero_id);
              const drv = pfMap.get(trip.conductor_id);
              detail.pasajero_nombre = pax ? `${pax.nombre} ${pax.apellido}` : "—";
              detail.pasajero_telefono = pax?.telefono || "—";
              detail.conductor_nombre = drv ? `${drv.nombre} ${drv.apellido}` : "—";
              detail.conductor_telefono = drv?.telefono || "—";

              const { data: veh } = await supabase.from("conductor_vehiculos").select("patente, marca, modelo").eq("perfil_id", trip.conductor_id).limit(1).single();
              if (veh) {
                detail.patente = veh.patente;
                detail.modelo = `${veh.marca} ${veh.modelo}`;
              }
            }
          }

          setPanicAlerts(prev => [alert, ...prev]);
          setActiveSOS(alert);
          setSOSDetail(detail);

          // Alert sound
          if (sosAudioRef.current) {
            sosAudioRef.current.play().catch(() => {});
          }

          // Fly to location
          mapRef.current?.flyTo({ center: [alert.lng, alert.lat], zoom: 16, duration: 2000 });
        }
      )
      .subscribe();

    return () => { supabase.removeChannel(channel); };
  }, []);

  // ──────────────────────────────────────────────────
  // RENDER
  // ──────────────────────────────────────────────────
  const toggleTrip = (id: string) => {
    setSelectedTripIds(prev => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id); else next.add(id);
      return next;
    });
  };

  const selectAllTrips = () => {
    if (selectedTripIds.size === activeTrips.length) setSelectedTripIds(new Set());
    else setSelectedTripIds(new Set(activeTrips.map(t => t.id)));
  };

  const flyToTrip = (trip: ActiveTrip) => {
    mapRef.current?.flyTo({
      center: [trip.origin_lng, trip.origin_lat],
      zoom: 15,
      duration: 1200,
    });
  };

  const displayedTrips = searchQuery.length >= 3 ? searchResults : activeTrips;

  return (
    <div className="h-screen w-screen flex bg-[#0F172A] overflow-hidden">
      {/* ── SOS AUDIO (hidden) ── */}
      <audio ref={sosAudioRef} src="data:audio/wav;base64,UklGRnoGAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YQoGAACAf39/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/f4B/f3+Af39/gH9/" />

      {/* ── LEFT SIDEBAR ── */}
      <div className={`${sidebarOpen ? "w-80" : "w-0"} transition-all duration-300 bg-slate-900/95 border-r border-slate-700/50 flex flex-col shrink-0 overflow-hidden`}>
        {/* Search */}
        <div className="p-3 border-b border-slate-700/50">
          <div className="relative">
            <Search size={14} className="absolute left-2.5 top-1/2 -translate-y-1/2 text-slate-500" />
            <input
              type="text"
              placeholder="Buscar viaje, pasajero, conductor..."
              value={searchQuery}
              onChange={e => setSearchQuery(e.target.value)}
              className="w-full bg-slate-800 border border-slate-700 rounded-md pl-8 pr-3 py-1.5 text-xs text-slate-200 placeholder-slate-500 focus:outline-none focus:border-cyan-500/50"
            />
          </div>
        </div>

        {/* Trip list header */}
        <div className="flex items-center justify-between px-3 py-2 border-b border-slate-700/50">
          <span className="text-[10px] uppercase tracking-wider text-slate-500 font-bold">
            Viajes activos ({displayedTrips.length})
          </span>
          <button onClick={selectAllTrips} className="text-[10px] text-cyan-400 hover:text-cyan-300">
            {selectedTripIds.size === activeTrips.length && activeTrips.length > 0 ? "Deseleccionar" : "Seleccionar todos"}
          </button>
        </div>

        {/* Trip list */}
        <div className="flex-1 overflow-y-auto">
          {displayedTrips.length === 0 ? (
            <div className="p-6 text-center text-slate-500 text-xs">
              {searchQuery.length >= 3 ? "Sin resultados" : "Sin viajes activos"}
            </div>
          ) : (
            displayedTrips.map(trip => {
              const sel = selectedTripIds.has(trip.id);
              return (
                <div
                  key={trip.id}
                  onClick={() => toggleTrip(trip.id)}
                  className={`px-3 py-2 border-b border-slate-800 cursor-pointer hover:bg-slate-800/50 transition-colors ${sel ? "bg-cyan-950/30 border-l-2 border-l-cyan-400" : ""}`}
                >
                  <div className="flex items-start gap-2">
                    <button className="mt-0.5 shrink-0">
                      {sel ? <CheckSquare size={14} className="text-cyan-400" /> : <Square size={14} className="text-slate-600" />}
                    </button>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center justify-between">
                        <span className="text-[11px] font-semibold text-slate-200 truncate font-mono">
                          {trip.id.slice(0, 8)}...
                        </span>
                        <button onClick={(e) => { e.stopPropagation(); flyToTrip(trip); }} className="text-slate-600 hover:text-cyan-400">
                          <Crosshair size={12} />
                        </button>
                      </div>
                      <div className="text-[10px] text-slate-400 mt-0.5">
                        <span title={trip.pasajero_nombre}>👤 {trip.pasajero_nombre}</span>
                        <span className="mx-1">→</span>
                        <span title={trip.conductor_nombre}>🚗 {trip.conductor_nombre}</span>
                      </div>
                      <div className="text-[10px] text-slate-500 mt-0.5">
                        🚘 {trip.patente} • {trip.modelo}
                      </div>
                    </div>
                  </div>
                </div>
              );
            })
          )}
        </div>

        {/* Panic alerts */}
        {panicAlerts.length > 0 && (
          <div className="border-t border-red-500/30 bg-red-950/20 p-3">
            <div className="flex items-center gap-2 mb-2">
              <AlertTriangle size={14} className="text-red-500 animate-pulse" />
              <span className="text-[11px] font-bold text-red-400 uppercase tracking-wider">SOS Activos ({panicAlerts.length})</span>
            </div>
            {panicAlerts.slice(0, 3).map(a => (
              <div key={a.id} className="text-[10px] text-red-300/80">
                🆔 {String(a.id).slice(-6)} • {new Date(a.created_at).toLocaleTimeString()}
              </div>
            ))}
          </div>
        )}
      </div>

      {/* ── MAP ── */}
      <div className="flex-1 relative">
        <Map
          ref={mapRef}
          {...viewState}
          onLoad={() => setMapLoaded(true)}
          onMove={evt => setViewState(evt.viewState)}
          mapStyle="https://rutmy.com/style.json"
          style={{ width: "100%", height: "100%" }}
          attributionControl={false}
        >
          <NavigationControl position="top-right" />
          <GeolocateControl position="top-right" positionOptions={{ enableHighAccuracy: true }} trackUserLocation={true} />

          {/* Province boundary (red border) */}
          {provinceGeoJSON && (
            <Source id="province-boundary" type="geojson" data={provinceGeoJSON}>
              <Layer id="province-line" type="line" paint={{ "line-color": "#ef4444", "line-width": 2.5, "line-opacity": 0.8 }} />
              <Layer id="province-fill" type="fill" paint={{ "fill-color": "#ef4444", "fill-opacity": 0.05 }} />
            </Source>
          )}

          {/* H3 heatmap — rendered above water but below labels */}
          {showHeatmap && hexCells.length > 0 && (
            <Source id="h3-hex-source" type="geojson" data={{ type: "FeatureCollection", features: hexCells }}>
              <Layer id="h3-hex-fill" type="fill" beforeId="road-labels-motorway" paint={{
                "fill-color": ["get", "color"],
                "fill-opacity": 0.55,
                "fill-outline-color": "rgba(255,255,255,0.2)",
              }} />
            </Source>
          )}

          {/* Offered routes (BLUE) — from route_polyline */}
          {[...selectedTripIds].map(tripId => {
            const trip = activeTrips.find(t => t.id === tripId);
            if (!trip?.route_polyline?.length) return null;
            return (
              <Source key={`offered-${tripId}`} id={`offered-${tripId}`} type="geojson"
                data={{ type: "Feature", geometry: { type: "LineString", coordinates: trip.route_polyline } }}>
                <Layer id={`offered-line-${tripId}`} type="line" paint={{
                  "line-color": "#3b82f6", "line-width": 3, "line-opacity": 0.8,
                  "line-dasharray": [2, 1],
                }} />
              </Source>
            );
          })}

          {/* GPS tracks (ORANGE/RED) — actual route */}
          {Object.entries(gpsTracks).map(([tripId, points]) => {
            if (points.length < 2) return null;
            const coords = points.map(p => [p.lng, p.lat]);
            return (
              <Source key={`gps-${tripId}`} id={`gps-${tripId}`} type="geojson"
                data={{ type: "Feature", geometry: { type: "LineString", coordinates: coords } }}>
                <Layer id={`gps-line-${tripId}`} type="line" paint={{
                  "line-color": "#f97316", "line-width": 3.5, "line-opacity": 0.9,
                }} />
              </Source>
            );
          })}

          {/* Trip markers: origin (green) and destination (red) */}
          {[...selectedTripIds].map(tripId => {
            const trip = activeTrips.find(t => t.id === tripId);
            if (!trip) return null;
            return (
              <div key={`markers-${tripId}`}>
                <Marker longitude={trip.origin_lng} latitude={trip.origin_lat} anchor="center">
                  <div className="h-3 w-3 rounded-full bg-emerald-500 ring-2 ring-white shadow-lg" title="Origen" />
                </Marker>
                <Marker longitude={trip.dest_lng} latitude={trip.dest_lat} anchor="center">
                  <div className="h-3 w-3 rounded-full bg-red-500 ring-2 ring-white shadow-lg" title="Destino" />
                </Marker>
              </div>
            );
          })}

          {/* Active SOS marker */}
          {activeSOS && (
            <Marker longitude={activeSOS.lng} latitude={activeSOS.lat} anchor="center">
              <div className="flex flex-col items-center">
                <span className="absolute inline-flex h-8 w-8 animate-ping rounded-full bg-red-500 opacity-50" />
                <span className="relative inline-flex h-6 w-6 rounded-full bg-red-600 ring-3 ring-white shadow-lg items-center justify-center">
                  <AlertTriangle size={12} className="text-white" />
                </span>
              </div>
            </Marker>
          )}

          {/* Zoom indicator */}
          <div style={{ position: "absolute", bottom: 12, right: 12, background: "rgba(15,23,42,0.9)", color: "#94A3B8", padding: "3px 8px", borderRadius: "5px", fontSize: "10px", fontFamily: "monospace", fontWeight: 600, zIndex: 10 }}>
            Z {viewState.zoom.toFixed(2)}
          </div>

          {/* Sidebar toggle */}
          <div style={{ position: "absolute", bottom: 12, left: 12, zIndex: 10 }}>
            <button onClick={() => setSidebarOpen(!sidebarOpen)} className="bg-slate-900/90 text-slate-300 hover:text-white p-2 rounded-lg border border-slate-700/50 text-xs">
              {sidebarOpen ? "◀" : "▶"}
            </button>
          </div>
        </Map>

        {/* ── TOP STATUS BAR ── */}
        <div className="absolute top-0 left-0 right-0 flex items-center justify-between px-4 py-1.5 bg-slate-900/90 border-b border-slate-700/50 z-10 pointer-events-none">
          <div className="flex items-center gap-3 text-xs">
            <Radio size={14} className="text-purple-400" />
            <span className="text-slate-200 font-bold tracking-wide">TORRE DE CONTROL</span>
            <span className="text-slate-500">•</span>
            <span className="text-slate-400">{provinceName}</span>
            <span className="text-[10px] text-slate-600 font-mono">({activeTrips.length} activos)</span>
          </div>
          <div className="flex items-center gap-3 text-[10px] text-slate-500 pointer-events-auto">
            <button onClick={() => setShowHeatmap(!showHeatmap)} className={`px-2 py-0.5 rounded ${showHeatmap ? "bg-orange-500/20 text-orange-400" : "bg-slate-800 text-slate-500"}`}>
              Heatmap {showHeatmap ? "ON" : "OFF"}
            </button>
            <button onClick={loadActiveTrips} className="px-2 py-0.5 rounded bg-slate-800 hover:bg-slate-700 text-slate-400">
              ↻ Actualizar
            </button>
            <span className="font-mono">{new Date().toLocaleTimeString("es-AR", { hour: "2-digit", minute: "2-digit" })}</span>
          </div>
        </div>
      </div>

      {/* ── SOS DETAIL PANEL ── */}
      {activeSOS && sosDetail && (
        <div className="absolute bottom-4 left-1/2 -translate-x-1/2 z-20 bg-red-950/95 border-2 border-red-500 rounded-xl p-4 shadow-2xl max-w-lg w-full animate-pulse">
          <div className="flex items-center justify-between mb-3">
            <div className="flex items-center gap-2">
              <AlertTriangle size={20} className="text-red-500" />
              <span className="text-red-300 font-bold text-sm">⚠️ BOTÓN DE PÁNICO ACTIVADO</span>
            </div>
            <button onClick={() => setActiveSOS(null)} className="text-red-400 hover:text-red-200">
              <X size={18} />
            </button>
          </div>
          <div className="grid grid-cols-2 gap-2 text-xs text-slate-200">
            <div><span className="text-slate-500">Pasajero:</span> {sosDetail.pasajero_nombre}</div>
            <div><span className="text-slate-500">Tel pasajero:</span> {sosDetail.pasajero_telefono}</div>
            <div><span className="text-slate-500">Conductor:</span> {sosDetail.conductor_nombre}</div>
            <div><span className="text-slate-500">Tel conductor:</span> {sosDetail.conductor_telefono}</div>
            <div><span className="text-slate-500">Patente:</span> {sosDetail.patente}</div>
            <div><span className="text-slate-500">Modelo:</span> {sosDetail.modelo}</div>
          </div>
        </div>
      )}
    </div>
  );
}
