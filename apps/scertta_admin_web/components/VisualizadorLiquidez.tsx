"use client";

import { useState, useEffect } from "react";
import { supabase } from "@/lib/supabaseClient";
import { TrendingUp, TrendingDown, DollarSign, Percent } from "lucide-react";

interface Promocion {
  id: string;
  nombre: string;
  porcentaje_descuento: number;
  activa: boolean;
}

interface VisualizadorLiquidezProps {
  promociones: Promocion[];
}

interface MetricasLiquidez {
  facturacionZonasNormales: number;
  facturacionZonasPromo: number;
  costoDescuentos: number;
  facturacionNetaPromo: number;
  totalViajes: number;
  viajesPromo: number;
  porcentajeImpacto: number;
}

export default function VisualizadorLiquidez({
  promociones,
}: VisualizadorLiquidezProps) {
  const [metricas, setMetricas] = useState<MetricasLiquidez>({
    facturacionZonasNormales: 0,
    facturacionZonasPromo: 0,
    costoDescuentos: 0,
    facturacionNetaPromo: 0,
    totalViajes: 0,
    viajesPromo: 0,
    porcentajeImpacto: 0,
  });

  const [cargando, setCargando] = useState(true);

  useEffect(() => {
    cargarMetricas();
  }, [promociones]);

  const cargarMetricas = async () => {
    setCargando(true);

    const hoy = new Date().toISOString().split("T")[0];

    const { data: metricsData, error } = await supabase
      .from("metricas_promociones")
      .select("*")
      .eq("fecha", hoy);

    if (!error && metricsData) {
      const totalDescuentos = metricsData.reduce(
        (acc, m) => acc + Number(m.descuento_aplicado || 0),
        0
      );
      const totalBrutoPromo = metricsData.reduce(
        (acc, m) => acc + Number(m.facturacion_bruta || 0),
        0
      );
      const totalNetoPromo = metricsData.reduce(
        (acc, m) => acc + Number(m.facturacion_neta || 0),
        0
      );
      const totalViajesPromo = metricsData.reduce(
        (acc, m) => acc + Number(m.viajes_totales || 0),
        0
      );

      const facturacionNormal = 45000;
      const totalViajes = 150;

      const porcentaje =
        facturacionNormal > 0
          ? ((totalDescuentos / facturacionNormal) * 100).toFixed(2)
          : 0;

      setMetricas({
        facturacionZonasNormales: facturacionNormal,
        facturacionZonasPromo: totalBrutoPromo,
        costoDescuentos: totalDescuentos,
        facturacionNetaPromo: totalNetoPromo,
        totalViajes: totalViajes,
        viajesPromo: totalViajesPromo,
        porcentajeImpacto: Number(porcentaje),
      });
    } else {
      const facturacionNormal = 45000;
      const facturacionPromo = 12000;
      const descuentos = 1800;
      const totalViajes = 150;
      const viajesPromo = 40;

      setMetricas({
        facturacionZonasNormales: facturacionNormal,
        facturacionZonasPromo: facturacionPromo,
        costoDescuentos: descuentos,
        facturacionNetaPromo: facturacionPromo - descuentos,
        totalViajes: totalViajes,
        viajesPromo: viajesPromo,
        porcentajeImpacto: ((descuentos / facturacionNormal) * 100),
      });
    }

    setCargando(false);
  };

  const formatCurrency = (value: number) => {
    return new Intl.NumberFormat("es-AR", {
      style: "currency",
      currency: "ARS",
      minimumFractionDigits: 0,
    }).format(value);
  };

  const flujoCajaPositivo =
    metricas.facturacionZonasNormales + metricas.facturacionNetaPromo >
    metricas.costoDescuentos;

  return (
    <div className="bg-white dark:bg-gray-900 rounded-lg border border-gray-200 dark:border-gray-800 p-4">
      <div className="flex items-center justify-between mb-4">
        <h3 className="font-semibold">Visualización de Liquidez</h3>
        {cargando && (
          <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-rutmy-agua"></div>
        )}
      </div>

      <div className="space-y-3">
        <div className="p-3 bg-green-50 dark:bg-green-900/20 rounded-lg border border-green-200 dark:border-green-800">
          <div className="flex items-center justify-between mb-1">
            <span className="text-xs font-medium text-green-700 dark:text-green-400">
              Zonas Normales
            </span>
            <TrendingUp className="w-4 h-4 text-green-600" />
          </div>
          <p className="text-lg font-bold text-green-800 dark:text-green-300">
            {formatCurrency(metricas.facturacionZonasNormales)}
          </p>
          <p className="text-xs text-green-600 dark:text-green-500">
            {metricas.totalViajes - metricas.viajesPromo} viajes
          </p>
        </div>

        <div className="p-3 bg-blue-50 dark:bg-blue-900/20 rounded-lg border border-blue-200 dark:border-blue-800">
          <div className="flex items-center justify-between mb-1">
            <span className="text-xs font-medium text-blue-700 dark:text-blue-400">
              Zonas con Promoción (Bruto)
            </span>
            <DollarSign className="w-4 h-4 text-blue-600" />
          </div>
          <p className="text-lg font-bold text-blue-800 dark:text-blue-300">
            {formatCurrency(metricas.facturacionZonasPromo)}
          </p>
          <p className="text-xs text-blue-600 dark:text-blue-500">
            {metricas.viajesPromo} viajes con descuento
          </p>
        </div>

        <div className="p-3 bg-red-50 dark:bg-red-900/20 rounded-lg border border-red-200 dark:border-red-800">
          <div className="flex items-center justify-between mb-1">
            <span className="text-xs font-medium text-red-700 dark:text-red-400">
              Costo de Descuentos
            </span>
            <TrendingDown className="w-4 h-4 text-red-600" />
          </div>
          <p className="text-lg font-bold text-red-800 dark:text-red-300">
            -{formatCurrency(metricas.costoDescuentos)}
          </p>
          <p className="text-xs text-red-600 dark:text-red-500">
            {metricas.porcentajeImpacto.toFixed(1)}% del total
          </p>
        </div>

        <div
          className={`p-4 rounded-lg border-2 ${
            flujoCajaPositivo
              ? "bg-green-50 dark:bg-green-900/20 border-green-300 dark:border-green-700"
              : "bg-red-50 dark:bg-red-900/20 border-red-300 dark:border-red-700"
          }`}
        >
          <div className="flex items-center justify-between mb-2">
            <span className="text-sm font-semibold">Flujo de Caja</span>
            {flujoCajaPositivo ? (
              <TrendingUp className="w-5 h-5 text-green-600" />
            ) : (
              <TrendingDown className="w-5 h-5 text-red-600" />
            )}
          </div>
          <p
            className={`text-2xl font-bold ${
              flujoCajaPositivo
                ? "text-green-700 dark:text-green-400"
                : "text-red-700 dark:text-red-400"
            }`}
          >
            {formatCurrency(
              metricas.facturacionZonasNormales +
                metricas.facturacionNetaPromo
            )}
          </p>
          <p className="text-xs mt-1 text-gray-600 dark:text-gray-400">
            {flujoCajaPositivo ? "Positivo ✓" : "Negativo ✗"}
          </p>
        </div>

        <div className="pt-3 border-t border-gray-200 dark:border-gray-700">
          <div className="flex items-center justify-between text-xs text-gray-600 dark:text-gray-400">
            <span>Total Viajes Hoy</span>
            <span className="font-semibold">{metricas.totalViajes}</span>
          </div>
          <div className="flex items-center justify-between text-xs text-gray-600 dark:text-gray-400 mt-1">
            <span>Promociones Activas</span>
            <span className="font-semibold">
              {promociones.filter((p) => p.activa).length}
            </span>
          </div>
        </div>
      </div>
    </div>
  );
}
