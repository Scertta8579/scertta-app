'use client'

import { useEffect, useState } from 'react'
import { createClient } from '@/lib/supabaseClient'
import Link from 'next/link'

interface Ingreso {
  id: string
  monto: number
  categoria: string
  descripcion: string | null
  fecha: string
  region_id: string | null
  created_at: string
}

export default function IngresosPage() {
  const [ingresos, setIngresos] = useState<Ingreso[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const supabase = createClient()

  useEffect(() => {
    cargarIngresos()
  }, [])

  async function cargarIngresos() {
    try {
      const { data, error: err } = await supabase
        .from('ingresos_plataforma')
        .select('*')
        .order('fecha', { ascending: false })
        .limit(100)

      if (err) throw err
      setIngresos(data ?? [])
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : 'Error al cargar ingresos')
    } finally {
      setLoading(false)
    }
  }

  function formatPesos(value: number) {
    return new Intl.NumberFormat('es-AR', {
      style: 'currency',
      currency: 'ARS',
    }).format(value)
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-black flex items-center justify-center">
        <div className="text-white">Cargando ingresos...</div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-black text-white p-8">
      <div className="max-w-5xl mx-auto">
        <div className="mb-6 flex items-center gap-4">
          <Link
            href="/libro-numeros"
            className="text-gray-400 hover:text-white text-sm"
          >
            ← Libro de Números
          </Link>
        </div>

        <div className="mb-8">
          <h1 className="text-4xl font-bold text-green-400 mb-2">Ingresos</h1>
          <p className="text-gray-400">Registro de ingresos de la plataforma</p>
        </div>

        {error && (
          <div className="bg-red-900/40 border border-red-600 rounded-lg p-4 mb-6 text-red-300">
            {error}
          </div>
        )}

        <div className="bg-[#1a1a1a] rounded-lg border border-green-600 overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="border-b border-gray-700">
                  <th className="text-left py-3 px-4 text-gray-400">Fecha</th>
                  <th className="text-left py-3 px-4 text-gray-400">Categoría</th>
                  <th className="text-left py-3 px-4 text-gray-400">Descripción</th>
                  <th className="text-right py-3 px-4 text-gray-400">Monto</th>
                </tr>
              </thead>
              <tbody>
                {ingresos.map((ingreso) => (
                  <tr
                    key={ingreso.id}
                    className="border-b border-gray-800 hover:bg-[#2a2a2a]"
                  >
                    <td className="py-3 px-4 text-sm text-gray-300">
                      {new Date(ingreso.fecha).toLocaleDateString('es-AR')}
                    </td>
                    <td className="py-3 px-4">
                      <span className="px-2 py-1 rounded text-xs bg-green-900/50 text-green-400">
                        {ingreso.categoria}
                      </span>
                    </td>
                    <td className="py-3 px-4 text-sm text-gray-400">
                      {ingreso.descripcion ?? '—'}
                    </td>
                    <td className="py-3 px-4 text-right font-medium text-green-400">
                      {formatPesos(ingreso.monto)}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {ingresos.length === 0 && (
            <div className="text-center py-12 text-gray-400">
              No hay ingresos registrados
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
