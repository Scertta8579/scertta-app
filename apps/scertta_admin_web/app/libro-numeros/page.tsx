'use client'

import { useEffect, useState } from 'react'
import { createClient } from '@/lib/supabaseClient'
import Link from 'next/link'

interface ResumenContable {
  total_ingresos: number
  total_egresos: number
  balance: number
}

export default function LibroNumerosPage() {
  const [resumen, setResumen] = useState<ResumenContable | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const supabase = createClient()

  useEffect(() => {
    cargarResumen()
  }, [])

  async function cargarResumen() {
    try {
      const [{ data: ingresos, error: errI }, { data: egresos, error: errE }] =
        await Promise.all([
          supabase.from('ingresos_plataforma').select('monto'),
          supabase.from('egresos_plataforma').select('monto'),
        ])

      if (errI) throw errI
      if (errE) throw errE

      const totalIngresos = (ingresos ?? []).reduce(
        (acc, r) => acc + Number(r.monto),
        0
      )
      const totalEgresos = (egresos ?? []).reduce(
        (acc, r) => acc + Number(r.monto),
        0
      )

      setResumen({
        total_ingresos: totalIngresos,
        total_egresos: totalEgresos,
        balance: totalIngresos - totalEgresos,
      })
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : 'Error al cargar datos contables')
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
        <div className="text-white">Cargando libro de números...</div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-black text-white p-8">
      <div className="max-w-5xl mx-auto">
        {/* Header */}
        <div className="mb-8">
          <h1 className="text-4xl font-bold text-[#0b4bb3] mb-2">
            Libro de Números
          </h1>
          <p className="text-gray-400">
            Gestión contable de ingresos y egresos de la plataforma
          </p>
        </div>

        {error && (
          <div className="bg-red-900/40 border border-red-600 rounded-lg p-4 mb-6 text-red-300">
            {error}
          </div>
        )}

        {/* Resumen financiero */}
        {resumen && (
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
            <div className="bg-[#1a1a1a] p-6 rounded-lg border border-green-600">
              <h3 className="text-gray-400 text-sm mb-2">Total Ingresos</h3>
              <p className="text-2xl font-bold text-green-400">
                {formatPesos(resumen.total_ingresos)}
              </p>
            </div>

            <div className="bg-[#1a1a1a] p-6 rounded-lg border border-red-600">
              <h3 className="text-gray-400 text-sm mb-2">Total Egresos</h3>
              <p className="text-2xl font-bold text-red-400">
                {formatPesos(resumen.total_egresos)}
              </p>
            </div>

            <div
              className={`bg-[#1a1a1a] p-6 rounded-lg border ${
                resumen.balance >= 0 ? 'border-[#0b4bb3]' : 'border-orange-600'
              }`}
            >
              <h3 className="text-gray-400 text-sm mb-2">Balance</h3>
              <p
                className={`text-2xl font-bold ${
                  resumen.balance >= 0 ? 'text-[#0b4bb3]' : 'text-orange-400'
                }`}
              >
                {formatPesos(resumen.balance)}
              </p>
            </div>
          </div>
        )}

        {/* Accesos rápidos */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <Link
            href="/libro-numeros/ingresos"
            className="bg-[#1a1a1a] p-6 rounded-lg border border-green-600 hover:border-green-400 transition-colors block"
          >
            <h2 className="text-xl font-bold text-green-400 mb-2">
              Ingresos
            </h2>
            <p className="text-gray-400 text-sm">
              Registrar y consultar ingresos de la plataforma
            </p>
          </Link>

          <Link
            href="/libro-numeros/egresos"
            className="bg-[#1a1a1a] p-6 rounded-lg border border-red-600 hover:border-red-400 transition-colors block"
          >
            <h2 className="text-xl font-bold text-red-400 mb-2">Egresos</h2>
            <p className="text-gray-400 text-sm">
              Registrar y consultar egresos de la plataforma
            </p>
          </Link>
        </div>
      </div>
    </div>
  )
}
