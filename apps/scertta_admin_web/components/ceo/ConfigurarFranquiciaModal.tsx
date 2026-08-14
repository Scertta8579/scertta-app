"use client";
import { useEffect, useState, useCallback } from "react";
import { X, Upload, FileText, Trash2, Loader2 } from "lucide-react";
import { supabase } from "@/lib/supabaseClient";
import { useDropzone } from "react-dropzone";
import ValidarCUIT from "@/components/ValidarCUIT";
import { validarCUITAlgoritmo } from "@/components/ValidarCUIT";

interface Props {
  f: any;
  gerentes: any[];
  nuevoGerente: any;
  configMsg: string;
  onClose: () => void;
  onSuspender: (gid: string, activo: boolean) => void;
  onBlanquear: (gid: string) => void;
  onAgregar: (fid: string) => void;
  setNuevoGerente: (v: any) => void;
}

export default function ConfigurarFranquiciaModal({
  f, gerentes, nuevoGerente, configMsg,
  onClose, onSuspender, onBlanquear, onAgregar, setNuevoGerente,
}: Props) {
  // ── Reglas de Contrato ──
  const [reglas, setReglas] = useState({
    comision_porcentaje: "",
    periodo_gracia_meses: "",
    frecuencia_liquidacion: "mensual",
    dia_ejecucion: "",
  });
  const [reglasLoading, setReglasLoading] = useState(true);
  const [reglasSaving, setReglasSaving] = useState(false);
  const [reglasMsg, setReglasMsg] = useState("");

  // ── Documentos ──
  const [documentos, setDocumentos] = useState<any[]>([]);
  const [docsLoading, setDocsLoading] = useState(true);
  const [uploading, setUploading] = useState(false);
  const [docsMsg, setDocsMsg] = useState("");

  // ── Load config on mount ──
  useEffect(() => {
    if (!f) return;

    // Load reglas
    setReglasLoading(true);
    fetch(`/api/admin/franquicia-config?franquicia_id=${f.id}`)
      .then((res) => res.json())
      .then(({ data }) => {
        if (data) {
          setReglas({
            comision_porcentaje: data.comision_porcentaje?.toString() || "",
            periodo_gracia_meses: data.periodo_gracia_meses?.toString() || "",
            frecuencia_liquidacion: data.frecuencia_liquidacion || "mensual",
            dia_ejecucion: data.dia_ejecucion?.toString() || "",
          });
        }
      })
      .catch(() => {})
      .finally(() => setReglasLoading(false));

    // Load documentos
    cargarDocumentos();
  }, [f]);

  const cargarDocumentos = async () => {
    if (!f) return;
    setDocsLoading(true);
    const { data, error } = await supabase
      .from("franquicia_documentos")
      .select("*")
      .eq("franquicia_id", f.id)
      .order("created_at", { ascending: false });
    if (data) setDocumentos(data);
    setDocsLoading(false);
  };

  // ── Save reglas ──
  const guardarReglas = async () => {
    setReglasMsg("");
    setReglasSaving(true);
    try {
      const body: Record<string, any> = { franquicia_id: f.id };
      if (reglas.comision_porcentaje) body.comision_porcentaje = parseFloat(reglas.comision_porcentaje);
      if (reglas.periodo_gracia_meses) body.periodo_gracia_meses = parseInt(reglas.periodo_gracia_meses);
      if (reglas.frecuencia_liquidacion) body.frecuencia_liquidacion = reglas.frecuencia_liquidacion;
      if (reglas.dia_ejecucion) body.dia_ejecucion = parseInt(reglas.dia_ejecucion);

      const res = await fetch("/api/admin/franquicia-config", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });
      const data = await res.json();
      if (data.error) {
        setReglasMsg(`❌ ${data.error}`);
      } else {
        setReglasMsg("✅ Reglas de contrato guardadas");
        setTimeout(() => setReglasMsg(""), 3000);
      }
    } catch {
      setReglasMsg("❌ Error al guardar reglas");
    } finally {
      setReglasSaving(false);
    }
  };

  // ── Upload documento ──
  const onDrop = useCallback(async (acceptedFiles: File[]) => {
    if (!f) return;
    setDocsMsg("");
    setUploading(true);

    for (const file of acceptedFiles) {
      try {
        const filePath = `${f.id}/${Date.now()}_${file.name}`;
        const { error: uploadErr } = await supabase.storage
          .from("franquicia-docs")
          .upload(filePath, file, { cacheControl: "3600", upsert: false });

        if (uploadErr) {
          setDocsMsg(`❌ Error al subir ${file.name}: ${uploadErr.message}`);
          continue;
        }

        // Get public URL
        const { data: urlData } = supabase.storage
          .from("franquicia-docs")
          .getPublicUrl(filePath);

        // Save record
        await supabase.from("franquicia_documentos").insert({
          franquicia_id: f.id,
          nombre_archivo: file.name,
          ruta: filePath,
          url: urlData?.publicUrl || "",
          tamaño_bytes: file.size,
          tipo_mime: file.type,
        });
      } catch (err: any) {
        setDocsMsg(`❌ Error: ${err.message}`);
      }
    }

    setUploading(false);
    cargarDocumentos();
    if (!docsMsg) setDocsMsg("✅ Documento(s) subidos");
    setTimeout(() => setDocsMsg(""), 3000);
  }, [f, docsMsg]);

  const { getRootProps, getInputProps, isDragActive } = useDropzone({
    onDrop,
    accept: {
      "application/pdf": [".pdf"],
      "image/*": [".png", ".jpg", ".jpeg", ".webp"],
      "application/msword": [".doc"],
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document": [".docx"],
    },
    maxSize: 10 * 1024 * 1024, // 10 MB
    disabled: uploading,
  });

  // ── Delete documento ──
  const eliminarDocumento = async (docId: string, ruta: string) => {
    await supabase.storage.from("franquicia-docs").remove([ruta]);
    await supabase.from("franquicia_documentos").delete().eq("id", docId);
    cargarDocumentos();
  };

  if (!f) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm p-4">
      <div className="bg-rutmy-deep border border-white/10 rounded-2xl shadow-2xl w-full max-w-2xl max-h-[90vh] overflow-y-auto">
        <div className="sticky top-0 bg-rutmy-deep border-b border-white/10 px-6 py-4 flex items-center justify-between z-10">
          <div>
            <h3 className="text-lg font-bold">⚙️ Configurar: {f.nombre}</h3>
            <p className="text-xs text-white/90">{f.razon_social || "—"} · CUIT: {f.cuit_franquicia || "—"} · {f.provincias?.nombre}</p>
          </div>
          <button onClick={onClose} className="p-2 rounded-xl bg-white/5 hover:bg-white/10 text-white/90"><X size={18} /></button>
        </div>

        <div className="p-6 space-y-6">
          {/* ── Gerentes ── */}
          <div>
            <h4 className="text-sm font-semibold text-rutmy-agua mb-3">👤 Gerentes</h4>
            <div className="space-y-2">
              {gerentes.map((g: any) => (
                <div key={g.id} className={`flex items-center justify-between rounded-lg px-3 py-2 text-xs ${g.activo ? "bg-rutmy-agua/10 border border-rutmy-agua/20" : "bg-red-500/10 border border-red-500/20"}`}>
                  <div>
                    <span className="font-semibold text-white">{g.nombre} {g.apellido}</span>
                    <span className="text-white/90 ml-2">{g.email}</span>
                    {g.fecha_inicio && <span className="text-white/90 ml-2">· Inicio: {g.fecha_inicio}</span>}
                    <span className={`ml-2 text-[10px] px-1.5 py-0.5 rounded ${g.activo ? "bg-rutmy-agua/20 text-rutmy-agua" : "bg-red-500/20 text-red-400"}`}>{g.activo ? "activo" : "suspendido"}</span>
                  </div>
                  <div className="flex gap-1.5 shrink-0">
                    <button onClick={() => onSuspender(g.id, g.activo)} className={`px-2 py-1 rounded text-[10px] font-bold ${g.activo ? "bg-red-500/20 text-red-400" : "bg-rutmy-agua/20 text-rutmy-agua"}`}>{g.activo ? "Suspender" : "Reactivar"}</button>
                    <button onClick={() => onBlanquear(g.id)} className="px-2 py-1 rounded text-[10px] font-bold bg-amber-500/20 text-amber-400">Blanquear</button>
                  </div>
                </div>
              ))}
              {gerentes.length === 0 && <p className="text-xs text-white/90">Sin gerentes.</p>}
            </div>
          </div>

          {/* ── Agregar gerente ── */}
          <div>
            <h4 className="text-sm font-semibold text-rutmy-agua mb-3">+ Agregar gerente</h4>
            <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
              <input placeholder="Nombre" value={nuevoGerente.nombre} onChange={e => setNuevoGerente({ ...nuevoGerente, nombre: e.target.value })} className="rounded-lg border border-white/20 bg-white/10 px-2 py-1.5 text-xs text-white placeholder:text-white/60 outline-none focus:border-rutmy-agua" />
              <input placeholder="Apellido" value={nuevoGerente.apellido} onChange={e => setNuevoGerente({ ...nuevoGerente, apellido: e.target.value })} className="rounded-lg border border-white/20 bg-white/10 px-2 py-1.5 text-xs text-white placeholder:text-white/60 outline-none focus:border-rutmy-agua" />
              <input placeholder="Email" value={nuevoGerente.email} onChange={e => setNuevoGerente({ ...nuevoGerente, email: e.target.value })} className="rounded-lg border border-white/20 bg-white/10 px-2 py-1.5 text-xs text-white placeholder:text-white/60 outline-none focus:border-rutmy-agua" />
              <input placeholder="Password" value={nuevoGerente.password} onChange={e => setNuevoGerente({ ...nuevoGerente, password: e.target.value })} className="rounded-lg border border-white/20 bg-white/10 px-2 py-1.5 text-xs text-white placeholder:text-white/60 outline-none focus:border-rutmy-agua" />
              <div className="col-span-2 sm:col-span-3">
                <ValidarCUIT
                  value={nuevoGerente.cuit}
                  onChange={(cuit) => setNuevoGerente({ ...nuevoGerente, cuit })}
                  placeholder="CUIT del gerente"
                  mostrarValidacion={true}
                />
              </div>
              <input type="date" placeholder="Fecha Inicio" value={nuevoGerente.fecha_inicio} onChange={e => setNuevoGerente({ ...nuevoGerente, fecha_inicio: e.target.value })} className="rounded-lg border border-white/20 bg-white/10 px-2 py-1.5 text-xs text-white placeholder:text-white/60 outline-none focus:border-rutmy-agua [color-scheme:dark]" />
              <input type="number" placeholder="Duración (meses)" value={nuevoGerente.duracion_contrato_meses} onChange={e => setNuevoGerente({ ...nuevoGerente, duracion_contrato_meses: e.target.value })} className="rounded-lg border border-white/20 bg-white/10 px-2 py-1.5 text-xs text-white placeholder:text-white/60 outline-none focus:border-rutmy-agua" />
              <button onClick={() => onAgregar(f.id)} className="rounded-lg bg-rutmy-agua text-rutmy-deep px-3 py-1.5 text-xs font-bold">Agregar</button>
            </div>
          </div>

          {configMsg && <p className={`text-xs ${configMsg.startsWith("✅") ? "text-rutmy-agua" : "text-red-400"}`}>{configMsg}</p>}

          {/* ── Reglas de Contrato ── */}
          <div className="border-t border-white/10 pt-6">
            <h4 className="text-sm font-semibold text-amber-400 mb-3">📜 Reglas de Contrato</h4>
            {reglasLoading ? (
              <div className="flex items-center gap-2 text-xs text-white/90"><Loader2 size={14} className="animate-spin" /> Cargando...</div>
            ) : (
              <div className="space-y-3">
                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="text-[10px] text-white/90 mb-0.5 block">Comisión (%)</label>
                    <input type="number" step="0.01" placeholder="15" value={reglas.comision_porcentaje}
                      onChange={(e) => setReglas({ ...reglas, comision_porcentaje: e.target.value })}
                      className="w-full rounded-lg border border-white/20 bg-white/10 px-2 py-1.5 text-xs text-white outline-none focus:border-amber-400" />
                  </div>
                  <div>
                    <label className="text-[10px] text-white/90 mb-0.5 block">Período de Gracia (meses)</label>
                    <input type="number" placeholder="3" value={reglas.periodo_gracia_meses}
                      onChange={(e) => setReglas({ ...reglas, periodo_gracia_meses: e.target.value })}
                      className="w-full rounded-lg border border-white/20 bg-white/10 px-2 py-1.5 text-xs text-white outline-none focus:border-amber-400" />
                  </div>
                  <div>
                    <label className="text-[10px] text-white/90 mb-0.5 block">Frecuencia de Liquidación</label>
                    <select value={reglas.frecuencia_liquidacion}
                      onChange={(e) => setReglas({ ...reglas, frecuencia_liquidacion: e.target.value })}
                      className="w-full rounded-lg border border-white/20 bg-white/10 px-2 py-1.5 text-xs text-white outline-none focus:border-amber-400">
                      <option value="semanal" className="bg-rutmy-deep">Semanal</option>
                      <option value="quincenal" className="bg-rutmy-deep">Quincenal</option>
                      <option value="mensual" className="bg-rutmy-deep">Mensual</option>
                    </select>
                  </div>
                  <div>
                    <label className="text-[10px] text-white/90 mb-0.5 block">Día de Ejecución</label>
                    <input type="number" min="1" max="31" placeholder="5" value={reglas.dia_ejecucion}
                      onChange={(e) => setReglas({ ...reglas, dia_ejecucion: e.target.value })}
                      className="w-full rounded-lg border border-white/20 bg-white/10 px-2 py-1.5 text-xs text-white outline-none focus:border-amber-400" />
                  </div>
                </div>
                <button onClick={guardarReglas} disabled={reglasSaving}
                  className="rounded-lg bg-amber-500 text-rutmy-deep px-3 py-1.5 text-xs font-bold hover:bg-amber-400 disabled:opacity-60">
                  {reglasSaving ? "Guardando..." : "Guardar Reglas"}
                </button>
                {reglasMsg && <p className={`text-xs ${reglasMsg.startsWith("✅") ? "text-rutmy-agua" : "text-red-400"}`}>{reglasMsg}</p>}
              </div>
            )}
          </div>

          {/* ── Documentos ── */}
          <div className="border-t border-white/10 pt-6">
            <h4 className="text-sm font-semibold text-rutmy-agua mb-3">📄 Documentos</h4>

            {/* Upload zone */}
            <div
              {...getRootProps()}
              className={`border-2 border-dashed rounded-xl p-4 text-center cursor-pointer transition ${
                isDragActive ? "border-rutmy-agua bg-rutmy-agua/10" : "border-white/20 hover:border-rutmy-agua/50 hover:bg-white/5"
              } ${uploading ? "opacity-50 pointer-events-none" : ""}`}
            >
              <input {...getInputProps()} />
              {uploading ? (
                <div className="flex items-center justify-center gap-2 text-xs text-white/90">
                  <Loader2 size={16} className="animate-spin" /> Subiendo...
                </div>
              ) : isDragActive ? (
                <p className="text-xs text-rutmy-agua">Soltá los archivos aquí...</p>
              ) : (
                <div className="space-y-1">
                  <Upload size={20} className="mx-auto text-white/90" />
                  <p className="text-xs text-white/90">Arrastrá archivos o hacé click para subir</p>
                  <p className="text-[10px] text-white/85">PDF, imágenes, Word · Máx. 10 MB</p>
                </div>
              )}
            </div>

            {/* Lista de documentos */}
            {docsLoading ? (
              <div className="flex items-center gap-2 text-xs text-white/90 mt-3"><Loader2 size={14} className="animate-spin" /> Cargando documentos...</div>
            ) : documentos.length > 0 ? (
              <div className="space-y-1.5 mt-3">
                {documentos.map((doc) => (
                  <div key={doc.id} className="flex items-center justify-between bg-white/5 border border-white/10 rounded-lg px-3 py-2">
                    <div className="flex items-center gap-2 min-w-0">
                      <FileText size={14} className="text-white/90 shrink-0" />
                      <div className="min-w-0">
                        <p className="text-xs text-white truncate">{doc.nombre_archivo}</p>
                        <p className="text-[10px] text-white/90">{doc.tamaño_bytes ? `${(doc.tamaño_bytes / 1024).toFixed(1)} KB` : "—"} · {doc.created_at ? new Date(doc.created_at).toLocaleDateString("es-AR") : ""}</p>
                      </div>
                    </div>
                    <div className="flex items-center gap-1.5 shrink-0">
                      {doc.url && (
                        <a href={doc.url} target="_blank" rel="noopener noreferrer"
                          className="p-1 rounded text-[10px] text-rutmy-agua hover:bg-rutmy-agua/10">Ver</a>
                      )}
                      <button onClick={() => eliminarDocumento(doc.id, doc.ruta)}
                        className="p-1 rounded text-[10px] text-red-400 hover:bg-red-500/10">
                        <Trash2 size={12} />
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            ) : (
              <p className="text-xs text-white/90 mt-3">Sin documentos cargados.</p>
            )}
            {docsMsg && <p className={`text-xs mt-2 ${docsMsg.startsWith("✅") ? "text-rutmy-agua" : "text-red-400"}`}>{docsMsg}</p>}
          </div>
        </div>
      </div>
    </div>
  );
}
