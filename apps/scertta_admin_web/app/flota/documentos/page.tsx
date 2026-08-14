"use client";

import { FileText, Upload } from "lucide-react";

export default function FlotaDocumentosPage() {
  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-xl font-bold text-zinc-900">Documentos</h2>
        <p className="text-sm text-zinc-500">Remitos, facturas y declaraciones juradas de tu flota</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        {[
          { titulo: "Remitos digitales", desc: "Comprobantes de entrega de cada parada", icon: "📋" },
          { titulo: "Facturas C", desc: "Facturación semanal a conductores", icon: "🧾" },
          { titulo: "DDJJ Objetos personales", desc: "Declaraciones juradas de mudanzas", icon: "📦" },
        ].map((doc, i) => (
          <div key={i} className="bg-white rounded-2xl border border-zinc-100 p-5 space-y-3">
            <div className="text-3xl">{doc.icon}</div>
            <h3 className="font-bold">{doc.titulo}</h3>
            <p className="text-xs text-zinc-500">{doc.desc}</p>
            <button className="flex items-center gap-2 text-sm text-rutmy-agua font-semibold hover:underline">
              <Upload className="h-4 w-4" /> Subir documento
            </button>
          </div>
        ))}
      </div>

      <div className="bg-white rounded-2xl border border-zinc-100 p-6 text-center text-zinc-400">
        <FileText className="h-12 w-12 mx-auto mb-3 opacity-30" />
        <p>Los documentos aparecerán aquí cuando se generen viajes</p>
      </div>
    </div>
  );
}
