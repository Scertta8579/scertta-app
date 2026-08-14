"use client";

import { useState } from "react";
import {
  obtenerSugerenciasPromociones,
  obtenerColorPorNivelUrgencia,
  type SugerenciaPromocion,
} from "@/lib/heatmapUtils";
import {
  Sparkles,
  TrendingUp,
  MapPin,
  Users,
  Percent,
  AlertTriangle,
  CheckCircle,
  X,
} from "lucide-react";

interface SugerenciaPromoProps {
  onAplicarSugerencia: (sugerencia: SugerenciaPromocion) => void;
}

export default function SugerenciaPromo({
  onAplicarSugerencia,
}: SugerenciaPromoProps) {
  const [sugerencias, setSugerencias] = useState<SugerenciaPromocion[]>([]);
  const [cargando, setCargando] = useState(false);
  const [mostrarPanel, setMostrarPanel] = useState(false);

  const analizarYSugerir = async () => {
    setCargando(true);
    setMostrarPanel(true);

    const resultados = await obtenerSugerenciasPromociones();
    setSugerencias(resultados);
    setCargando(false);
  };

  const handleAplicar = (sugerencia: SugerenciaPromocion) => {
    onAplicarSugerencia(sugerencia);
    setMostrarPanel(false);
  };

  return (
    <>
      <button
        onClick={analizarYSugerir}
        disabled={cargando}
        className="flex items-center gap-2 px-4 py-2 bg-gradient-to-r from-purple-600 to-pink-600 text-white rounded-lg hover:from-purple-700 hover:to-pink-700 transition-all shadow-lg hover:shadow-xl disabled:opacity-50"
      >
        <Sparkles className="w-4 h-4" />
        {cargando ? "Analizando..." : "Sugerir Promo"}
      </button>

      {mostrarPanel && (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-white dark:bg-gray-900 rounded-xl shadow-2xl max-w-4xl w-full max-h-[90vh] overflow-hidden flex flex-col">
            <div className="p-6 border-b border-gray-200 dark:border-gray-800 flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className="p-2 bg-gradient-to-r from-purple-600 to-pink-600 rounded-lg">
                  <Sparkles className="w-6 h-6 text-white" />
                </div>
                <div>
                  <h2 className="text-xl font-bold">
                    Sugerencias Inteligentes de Promociones
                  </h2>
                  <p className="text-sm text-gray-600 dark:text-gray-400">
                    Basadas en análisis de demanda en tiempo real
                  </p>
                </div>
              </div>
              <button
                onClick={() => setMostrarPanel(false)}
                className="p-2 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-lg transition-colors"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="flex-1 overflow-y-auto p-6">
              {cargando ? (
                <div className="flex flex-col items-center justify-center py-12">
                  <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-purple-600 mb-4"></div>
                  <p className="text-gray-600 dark:text-gray-400">
                    Analizando patrones de demanda...
                  </p>
                </div>
              ) : sugerencias.length === 0 ? (
                <div className="flex flex-col items-center justify-center py-12">
                  <CheckCircle className="w-16 h-16 text-green-500 mb-4" />
                  <h3 className="text-lg font-semibold mb-2">
                    ¡Todo está equilibrado!
                  </h3>
                  <p className="text-gray-600 dark:text-gray-400 text-center max-w-md">
                    No se detectaron zonas con alta demanda que requieran
                    promociones en este momento.
                  </p>
                </div>
              ) : (
                <div className="space-y-4">
                  {sugerencias.map((sugerencia, index) => {
                    const { color, label } = obtenerColorPorNivelUrgencia(
                      sugerencia.urgencia
                    );

                    return (
                      <div
                        key={index}
                        className="border border-gray-200 dark:border-gray-800 rounded-lg p-5 hover:shadow-lg transition-shadow"
                      >
                        <div className="flex items-start justify-between mb-4">
                          <div className="flex items-start gap-3">
                            <div
                              className="p-2 rounded-lg"
                              style={{ backgroundColor: color + "20" }}
                            >
                              <MapPin
                                className="w-5 h-5"
                                style={{ color: color }}
                              />
                            </div>
                            <div>
                              <h3 className="font-semibold text-lg">
                                {sugerencia.barrio}
                              </h3>
                              <div className="flex items-center gap-2 mt-1">
                                <span
                                  className="text-xs font-medium px-2 py-1 rounded-full"
                                  style={{
                                    backgroundColor: color + "20",
                                    color: color,
                                  }}
                                >
                                  {label}
                                </span>
                                <span className="text-xs text-gray-500">
                                  Ratio: {sugerencia.ratio.toFixed(1)}:1
                                </span>
                              </div>
                            </div>
                          </div>
                          <div className="text-right">
                            <div className="text-2xl font-bold text-purple-600">
                              {sugerencia.descuento_sugerido}%
                            </div>
                            <div className="text-xs text-gray-500">
                              Descuento sugerido
                            </div>
                          </div>
                        </div>

                        <div className="grid grid-cols-2 gap-4 mb-4">
                          <div className="flex items-center gap-2 text-sm">
                            <TrendingUp className="w-4 h-4 text-orange-500" />
                            <span className="text-gray-600 dark:text-gray-400">
                              Solicitudes:
                            </span>
                            <span className="font-semibold">
                              {sugerencia.solicitudes}
                            </span>
                          </div>
                          <div className="flex items-center gap-2 text-sm">
                            <Users className="w-4 h-4 text-blue-500" />
                            <span className="text-gray-600 dark:text-gray-400">
                              Conductores:
                            </span>
                            <span className="font-semibold">
                              {sugerencia.conductores}
                            </span>
                          </div>
                        </div>

                        <div className="p-3 bg-gray-50 dark:bg-gray-800 rounded-lg mb-4">
                          <div className="flex items-start gap-2">
                            <AlertTriangle className="w-4 h-4 text-yellow-500 mt-0.5 flex-shrink-0" />
                            <p className="text-sm text-gray-700 dark:text-gray-300">
                              {sugerencia.justificacion}
                            </p>
                          </div>
                        </div>

                        <button
                          onClick={() => handleAplicar(sugerencia)}
                          className="w-full flex items-center justify-center gap-2 px-4 py-2 bg-gradient-to-r from-purple-600 to-pink-600 text-white rounded-lg hover:from-purple-700 hover:to-pink-700 transition-all font-medium"
                        >
                          <Percent className="w-4 h-4" />
                          Crear Promoción con {sugerencia.descuento_sugerido}%
                        </button>
                      </div>
                    );
                  })}
                </div>
              )}
            </div>

            <div className="p-4 border-t border-gray-200 dark:border-gray-800 bg-gray-50 dark:bg-gray-800">
              <div className="flex items-center gap-2 text-xs text-gray-600 dark:text-gray-400">
                <Sparkles className="w-4 h-4" />
                <span>
                  Las sugerencias se basan en datos de la última hora y análisis
                  de ratio solicitudes/conductores
                </span>
              </div>
            </div>
          </div>
        </div>
      )}
    </>
  );
}
