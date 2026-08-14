"use client";

import { useState } from "react";
import {
  verificarPromocionEnPunto,
  aplicarDescuentoPromocion,
  registrarMetricaPromocion,
} from "@/lib/promocionesGeograficas";
import { MapPin, DollarSign, Percent } from "lucide-react";

export default function EjemploIntegracionPromocion() {
  const [coordenadas, setCoordenadas] = useState({
    lat: -34.603722,
    lng: -58.381592,
  });
  const [precioBase, setPrecioBase] = useState(1500);
  const [resultado, setResultado] = useState<any>(null);
  const [cargando, setCargando] = useState(false);

  const verificarYAplicarDescuento = async () => {
    setCargando(true);
    setResultado(null);

    const promocion = await verificarPromocionEnPunto(
      coordenadas.lat,
      coordenadas.lng
    );

    if (promocion) {
      const precioConDescuento = aplicarDescuentoPromocion(
        precioBase,
        promocion.porcentaje_descuento
      );

      await registrarMetricaPromocion(
        promocion.id,
        precioConDescuento.precioOriginal,
        precioConDescuento.descuento
      );

      setResultado({
        tienePromocion: true,
        promocion: promocion.nombre,
        porcentajeDescuento: promocion.porcentaje_descuento,
        ...precioConDescuento,
      });
    } else {
      setResultado({
        tienePromocion: false,
        precioFinal: precioBase,
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

  return (
    <div className="max-w-2xl mx-auto p-6 space-y-6">
      <div className="bg-white dark:bg-gray-900 rounded-lg border border-gray-200 dark:border-gray-800 p-6">
        <h2 className="text-xl font-bold mb-4">
          Ejemplo: Integración de Promociones en Solicitud de Viaje
        </h2>
        <p className="text-sm text-gray-600 dark:text-gray-400 mb-6">
          Este componente demuestra cómo verificar y aplicar promociones
          geográficas automáticamente cuando un pasajero solicita un viaje.
        </p>

        <div className="space-y-4">
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium mb-1">
                <MapPin className="w-4 h-4 inline mr-1" />
                Latitud
              </label>
              <input
                type="number"
                step="0.000001"
                value={coordenadas.lat}
                onChange={(e) =>
                  setCoordenadas({ ...coordenadas, lat: Number(e.target.value) })
                }
                className="w-full px-3 py-2 border border-gray-300 dark:border-gray-700 rounded-lg bg-white dark:bg-gray-800"
              />
            </div>
            <div>
              <label className="block text-sm font-medium mb-1">
                <MapPin className="w-4 h-4 inline mr-1" />
                Longitud
              </label>
              <input
                type="number"
                step="0.000001"
                value={coordenadas.lng}
                onChange={(e) =>
                  setCoordenadas({ ...coordenadas, lng: Number(e.target.value) })
                }
                className="w-full px-3 py-2 border border-gray-300 dark:border-gray-700 rounded-lg bg-white dark:bg-gray-800"
              />
            </div>
          </div>

          <div>
            <label className="block text-sm font-medium mb-1">
              <DollarSign className="w-4 h-4 inline mr-1" />
              Precio Base del Viaje (ARS)
            </label>
            <input
              type="number"
              value={precioBase}
              onChange={(e) => setPrecioBase(Number(e.target.value))}
              className="w-full px-3 py-2 border border-gray-300 dark:border-gray-700 rounded-lg bg-white dark:bg-gray-800"
            />
          </div>

          <button
            onClick={verificarYAplicarDescuento}
            disabled={cargando}
            className="w-full flex items-center justify-center gap-2 px-4 py-3 bg-rutmy-agua text-rutmy-deep rounded-lg hover:bg-rutmy-agua/90 transition-colors font-medium disabled:opacity-50"
          >
            {cargando ? (
              <>
                <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-white"></div>
                Verificando...
              </>
            ) : (
              <>
                <Percent className="w-4 h-4" />
                Verificar Promoción y Calcular Precio
              </>
            )}
          </button>
        </div>

        {resultado && (
          <div className="mt-6 p-4 rounded-lg border-2 border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-800">
            {resultado.tienePromocion ? (
              <div className="space-y-3">
                <div className="flex items-center gap-2 text-green-600 dark:text-green-400">
                  <Percent className="w-5 h-5" />
                  <span className="font-semibold">
                    ¡Promoción Aplicada!
                  </span>
                </div>
                <div className="space-y-2 text-sm">
                  <div className="flex justify-between">
                    <span className="text-gray-600 dark:text-gray-400">
                      Promoción:
                    </span>
                    <span className="font-medium">{resultado.promocion}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-600 dark:text-gray-400">
                      Descuento:
                    </span>
                    <span className="font-medium text-green-600">
                      {resultado.porcentajeDescuento}%
                    </span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-600 dark:text-gray-400">
                      Precio Original:
                    </span>
                    <span className="line-through">
                      {formatCurrency(resultado.precioOriginal)}
                    </span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-600 dark:text-gray-400">
                      Ahorro:
                    </span>
                    <span className="text-green-600 font-medium">
                      -{formatCurrency(resultado.descuento)}
                    </span>
                  </div>
                  <div className="pt-2 border-t border-gray-300 dark:border-gray-600 flex justify-between items-center">
                    <span className="font-semibold">Precio Final:</span>
                    <span className="text-2xl font-bold text-rutmy-agua">
                      {formatCurrency(resultado.precioFinal)}
                    </span>
                  </div>
                </div>
              </div>
            ) : (
              <div className="space-y-3">
                <div className="flex items-center gap-2 text-gray-600 dark:text-gray-400">
                  <MapPin className="w-5 h-5" />
                  <span className="font-semibold">
                    Sin Promoción en esta Zona
                  </span>
                </div>
                <div className="pt-2 flex justify-between items-center">
                  <span className="font-semibold">Precio:</span>
                  <span className="text-2xl font-bold">
                    {formatCurrency(resultado.precioFinal)}
                  </span>
                </div>
              </div>
            )}
          </div>
        )}

        <div className="mt-6 p-4 bg-blue-50 dark:bg-blue-900/20 rounded-lg border border-blue-200 dark:border-blue-800">
          <h3 className="font-semibold text-sm mb-2">💡 Coordenadas de Ejemplo</h3>
          <ul className="text-xs space-y-1 text-gray-700 dark:text-gray-300">
            <li>
              <strong>Microcentro:</strong> -34.603722, -58.381592
            </li>
            <li>
              <strong>Palermo:</strong> -34.588, -58.425
            </li>
            <li>
              <strong>Recoleta:</strong> -34.588, -58.393
            </li>
          </ul>
        </div>
      </div>

      <div className="bg-white dark:bg-gray-900 rounded-lg border border-gray-200 dark:border-gray-800 p-6">
        <h3 className="font-semibold mb-3">Código de Integración</h3>
        <pre className="text-xs bg-gray-100 dark:bg-gray-800 p-4 rounded-lg overflow-x-auto">
{`// En tu componente de solicitud de viaje
import { 
  verificarPromocionEnPunto,
  aplicarDescuentoPromocion 
} from "@/lib/promocionesGeograficas";

// 1. Verificar si hay promoción activa
const promocion = await verificarPromocionEnPunto(
  origenLat,
  origenLng
);

// 2. Aplicar descuento si existe
if (promocion) {
  const precio = aplicarDescuentoPromocion(
    precioBase,
    promocion.porcentaje_descuento
  );
  
  // Mostrar precio con descuento al usuario
  console.log(\`Precio final: \${precio.precioFinal}\`);
}`}
        </pre>
      </div>
    </div>
  );
}
