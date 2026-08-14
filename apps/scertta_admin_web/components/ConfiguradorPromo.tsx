"use client";

import { useState, useEffect } from "react";
import { Save, X } from "lucide-react";

interface ConfiguradorPromoProps {
  onGuardar: (datos: {
    nombre: string;
    porcentajeDescuento: number;
    horarioInicio: string;
    horarioFin: string;
    activa: boolean;
  }) => void;
  onCancelar: () => void;
  valoresIniciales?: {
    nombre?: string;
    descuento?: number;
  };
}

export default function ConfiguradorPromo({
  onGuardar,
  onCancelar,
  valoresIniciales,
}: ConfiguradorPromoProps) {
  const [nombre, setNombre] = useState(valoresIniciales?.nombre || "");
  const [porcentajeDescuento, setPorcentajeDescuento] = useState(
    valoresIniciales?.descuento || 10
  );
  const [horarioInicio, setHorarioInicio] = useState("08:00");
  const [horarioFin, setHorarioFin] = useState("20:00");
  const [activa, setActiva] = useState(false);
  const [errores, setErrores] = useState<Record<string, string>>({});

  useEffect(() => {
    if (valoresIniciales) {
      if (valoresIniciales.nombre) setNombre(valoresIniciales.nombre);
      if (valoresIniciales.descuento)
        setPorcentajeDescuento(valoresIniciales.descuento);
    }
  }, [valoresIniciales]);

  const validarFormulario = () => {
    const nuevosErrores: Record<string, string> = {};

    if (!nombre.trim()) {
      nuevosErrores.nombre = "El nombre es obligatorio";
    }

    if (porcentajeDescuento < 0 || porcentajeDescuento > 100) {
      nuevosErrores.porcentaje = "El descuento debe estar entre 0% y 100%";
    }

    if (horarioInicio >= horarioFin) {
      nuevosErrores.horario = "El horario de inicio debe ser anterior al de fin";
    }

    setErrores(nuevosErrores);
    return Object.keys(nuevosErrores).length === 0;
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();

    if (validarFormulario()) {
      onGuardar({
        nombre,
        porcentajeDescuento,
        horarioInicio,
        horarioFin,
        activa,
      });
    }
  };

  return (
    <div className="bg-white dark:bg-gray-900 rounded-lg border border-gray-200 dark:border-gray-800 p-6 shadow-lg">
      <div className="flex items-center justify-between mb-4">
        <h3 className="text-lg font-semibold">Configurar Promoción</h3>
        <button
          onClick={onCancelar}
          className="text-gray-500 hover:text-gray-700 dark:hover:text-gray-300"
        >
          <X className="w-5 h-5" />
        </button>
      </div>

      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label
            htmlFor="nombre"
            className="block text-sm font-medium mb-1"
          >
            Nombre de la Promoción
          </label>
          <input
            type="text"
            id="nombre"
            value={nombre}
            onChange={(e) => setNombre(e.target.value)}
            placeholder="ej: Promo Microcentro Lunes"
            className="w-full px-3 py-2 border border-gray-300 dark:border-gray-700 rounded-lg bg-white dark:bg-gray-800 focus:ring-2 focus:ring-rutmy-agua focus:border-transparent"
          />
          {errores.nombre && (
            <p className="text-red-500 text-xs mt-1">{errores.nombre}</p>
          )}
        </div>

        <div>
          <label
            htmlFor="descuento"
            className="block text-sm font-medium mb-1"
          >
            Porcentaje de Descuento
          </label>
          <div className="flex items-center gap-3">
            <input
              type="range"
              id="descuento"
              min="0"
              max="100"
              step="5"
              value={porcentajeDescuento}
              onChange={(e) => setPorcentajeDescuento(Number(e.target.value))}
              className="flex-1"
            />
            <span className="text-2xl font-bold text-rutmy-agua w-16 text-right">
              {porcentajeDescuento}%
            </span>
          </div>
          {errores.porcentaje && (
            <p className="text-red-500 text-xs mt-1">{errores.porcentaje}</p>
          )}
        </div>

        <div className="grid grid-cols-2 gap-3">
          <div>
            <label
              htmlFor="horarioInicio"
              className="block text-sm font-medium mb-1"
            >
              Horario Inicio
            </label>
            <input
              type="time"
              id="horarioInicio"
              value={horarioInicio}
              onChange={(e) => setHorarioInicio(e.target.value)}
              className="w-full px-3 py-2 border border-gray-300 dark:border-gray-700 rounded-lg bg-white dark:bg-gray-800 focus:ring-2 focus:ring-rutmy-agua focus:border-transparent"
            />
          </div>
          <div>
            <label
              htmlFor="horarioFin"
              className="block text-sm font-medium mb-1"
            >
              Horario Fin
            </label>
            <input
              type="time"
              id="horarioFin"
              value={horarioFin}
              onChange={(e) => setHorarioFin(e.target.value)}
              className="w-full px-3 py-2 border border-gray-300 dark:border-gray-700 rounded-lg bg-white dark:bg-gray-800 focus:ring-2 focus:ring-rutmy-agua focus:border-transparent"
            />
          </div>
        </div>
        {errores.horario && (
          <p className="text-red-500 text-xs">{errores.horario}</p>
        )}

        <div className="flex items-center justify-between p-4 bg-gray-50 dark:bg-gray-800 rounded-lg">
          <div>
            <p className="font-medium text-sm">Activar Promoción</p>
            <p className="text-xs text-gray-600 dark:text-gray-400">
              Los viajes en esta zona aplicarán el descuento automáticamente
            </p>
          </div>
          <label className="relative inline-flex items-center cursor-pointer">
            <input
              type="checkbox"
              checked={activa}
              onChange={(e) => setActiva(e.target.checked)}
              className="sr-only peer"
            />
            <div className="w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-blue-300 dark:peer-focus:ring-blue-800 rounded-full peer dark:bg-gray-700 peer-checked:after:translate-x-full rtl:peer-checked:after:-translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:start-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all dark:border-gray-600 peer-checked:bg-blue-600"></div>
          </label>
        </div>

        <div className="flex gap-2 pt-2">
          <button
            type="submit"
            className="flex-1 flex items-center justify-center gap-2 px-4 py-2 bg-rutmy-agua text-rutmy-deep rounded-lg hover:bg-rutmy-agua/90 transition-colors font-medium"
          >
            <Save className="w-4 h-4" />
            Guardar Promoción
          </button>
          <button
            type="button"
            onClick={onCancelar}
            className="px-4 py-2 border border-gray-300 dark:border-gray-700 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors"
          >
            Cancelar
          </button>
        </div>
      </form>
    </div>
  );
}
