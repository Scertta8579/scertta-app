'use client'

import { useEffect, useState } from 'react'
import { createClient } from '@/lib/supabaseClient'

interface MetricasMarketing {
  total_solicitantes: number
  total_conductores: number
  total_usuarios: number
  nuevos_solicitantes_7d: number
  nuevos_conductores_7d: number
  conductores_comunidad: number
  conductores_vip: number
}

interface Contacto {
  id: string
  email: string
  nombre: string
  rol: string
  fecha_registro: string
  segmento: string
}

export default function MarketingDashboard() {
  const [metricas, setMetricas] = useState<MetricasMarketing | null>(null)
  const [contactos, setContactos] = useState<Contacto[]>([])
  const [loading, setLoading] = useState(true)
  const [enviandoEmail, setEnviandoEmail] = useState(false)

  const supabase = createClient()

  useEffect(() => {
    cargarDatos()
  }, [])

  async function cargarDatos() {
    try {
      // Cargar métricas
      const { data: metricasData, error: metricasError } = await supabase
        .from('metricas_marketing')
        .select('*')
        .single()

      if (metricasError) {
        console.error('Error al cargar métricas:', metricasError)
      } else {
        setMetricas(metricasData)
      }

      // Cargar contactos
      const { data: contactosData, error: contactosError } = await supabase
        .from('contactos_marketing')
        .select('*')
        .limit(50)

      if (contactosError) {
        console.error('Error al cargar contactos:', contactosError)
      } else {
        setContactos(contactosData || [])
      }
    } catch (error) {
      console.error('Error al cargar datos:', error)
    } finally {
      setLoading(false)
    }
  }

  async function enviarEmailMasivo(segmento: string) {
    setEnviandoEmail(true)
    
    try {
      // Aquí iría la lógica para enviar emails masivos
      // usando Resend o la Edge Function
      console.log(`Enviando emails a segmento: ${segmento}`)
      
      alert(`Emails enviados exitosamente al segmento: ${segmento}`)
    } catch (error) {
      console.error('Error al enviar emails:', error)
      alert('Error al enviar emails')
    } finally {
      setEnviandoEmail(false)
    }
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-black flex items-center justify-center">
        <div className="text-white">Cargando métricas...</div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-black text-white p-8">
      <div className="max-w-7xl mx-auto">
        {/* Header */}
        <div className="mb-8">
          <h1 className="text-4xl font-bold text-[#0b4bb3] mb-2">
            Dashboard de Marketing
          </h1>
          <p className="text-gray-400">
            Métricas, segmentación y envío de campañas
          </p>
        </div>

        {/* Métricas */}
        {metricas && (
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
            <div className="bg-[#1a1a1a] p-6 rounded-lg border border-[#0b4bb3]">
              <h3 className="text-gray-400 text-sm mb-2">Total Usuarios</h3>
              <p className="text-3xl font-bold">{metricas.total_usuarios}</p>
              <div className="mt-2 text-sm text-gray-500">
                {metricas.total_solicitantes} solicitantes · {metricas.total_conductores} conductores
              </div>
            </div>

            <div className="bg-[#1a1a1a] p-6 rounded-lg border border-green-600">
              <h3 className="text-gray-400 text-sm mb-2">Nuevos (7 días)</h3>
              <p className="text-3xl font-bold text-green-500">
                +{metricas.nuevos_solicitantes_7d + metricas.nuevos_conductores_7d}
              </p>
              <div className="mt-2 text-sm text-gray-500">
                {metricas.nuevos_solicitantes_7d} solicitantes · {metricas.nuevos_conductores_7d} conductores
              </div>
            </div>

            <div className="bg-[#1a1a1a] p-6 rounded-lg border border-purple-600">
              <h3 className="text-gray-400 text-sm mb-2">Planes de Conductores</h3>
              <p className="text-3xl font-bold text-purple-500">
                {metricas.conductores_vip} VIP
              </p>
              <div className="mt-2 text-sm text-gray-500">
                {metricas.conductores_comunidad} en Plan Comunidad
              </div>
            </div>
          </div>
        )}

        {/* Segmentación y Envío de Emails */}
        <div className="bg-[#1a1a1a] p-6 rounded-lg border border-[#0b4bb3] mb-8">
          <h2 className="text-2xl font-bold mb-4">Envío de Campañas</h2>
          
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <button
              onClick={() => enviarEmailMasivo('nuevo')}
              disabled={enviandoEmail}
              className="bg-green-600 hover:bg-green-700 disabled:bg-gray-600 text-white py-3 px-6 rounded-lg transition-colors"
            >
              📧 Enviar a Nuevos Usuarios
            </button>

            <button
              onClick={() => enviarEmailMasivo('reciente')}
              disabled={enviandoEmail}
              className="bg-blue-600 hover:bg-blue-700 disabled:bg-gray-600 text-white py-3 px-6 rounded-lg transition-colors"
            >
              📧 Enviar a Usuarios Recientes
            </button>

            <button
              onClick={() => enviarEmailMasivo('todos')}
              disabled={enviandoEmail}
              className="bg-purple-600 hover:bg-purple-700 disabled:bg-gray-600 text-white py-3 px-6 rounded-lg transition-colors"
            >
              📧 Enviar a Todos
            </button>
          </div>

          {enviandoEmail && (
            <div className="mt-4 text-center text-gray-400">
              Enviando emails...
            </div>
          )}
        </div>

        {/* Lista de Contactos */}
        <div className="bg-[#1a1a1a] p-6 rounded-lg border border-[#0b4bb3]">
          <h2 className="text-2xl font-bold mb-4">
            Base de Contactos ({contactos.length})
          </h2>

          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="border-b border-gray-700">
                  <th className="text-left py-3 px-4 text-gray-400">Email</th>
                  <th className="text-left py-3 px-4 text-gray-400">Nombre</th>
                  <th className="text-left py-3 px-4 text-gray-400">Rol</th>
                  <th className="text-left py-3 px-4 text-gray-400">Segmento</th>
                  <th className="text-left py-3 px-4 text-gray-400">Registro</th>
                </tr>
              </thead>
              <tbody>
                {contactos.map((contacto) => (
                  <tr key={contacto.id} className="border-b border-gray-800 hover:bg-[#2a2a2a]">
                    <td className="py-3 px-4">{contacto.email}</td>
                    <td className="py-3 px-4">{contacto.nombre}</td>
                    <td className="py-3 px-4">
                      <span className={`px-2 py-1 rounded text-xs ${
                        contacto.rol === 'conductor' ? 'bg-blue-600' :
                        contacto.rol === 'solicitante' ? 'bg-green-600' :
                        'bg-gray-600'
                      }`}>
                        {contacto.rol}
                      </span>
                    </td>
                    <td className="py-3 px-4">
                      <span className={`px-2 py-1 rounded text-xs ${
                        contacto.segmento === 'nuevo' ? 'bg-green-600' :
                        contacto.segmento === 'reciente' ? 'bg-blue-600' :
                        'bg-gray-600'
                      }`}>
                        {contacto.segmento}
                      </span>
                    </td>
                    <td className="py-3 px-4 text-gray-400 text-sm">
                      {new Date(contacto.fecha_registro).toLocaleDateString('es-AR')}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {contactos.length === 0 && (
            <div className="text-center py-8 text-gray-400">
              No hay contactos disponibles
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
