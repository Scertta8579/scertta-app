"use client";

import type { SupabaseClient } from "@supabase/supabase-js";
import { useEffect, useMemo, useState } from "react";
import {
  CheckCircle2,
  Clock,
  FileWarning,
  Loader2,
  Maximize2,
  Upload,
  X,
  XCircle,
} from "lucide-react";

export type KycDocRow = {
  id: string;
  driver_id: string;
  document_type: string;
  status: string;
  document_url: string | null;
  created_at: string;
  notes: string | null;
  feedback_conductor?: string | null;
};

export type KycPerfilLite = {
  id: string;
  nombre: string | null;
  apellido: string | null;
  email: string | null;
  rol: string | null;
  dni: string | null;
};

type Props = {
  supabase: SupabaseClient;
  docs: KycDocRow[];
  perfilMap: Record<string, KycPerfilLite>;
  loading: boolean;
  acting: string | null;
  labelDoc: (t: string) => string;
  onSetDocStatus: (
    id: string,
    status: "approved" | "rejected" | "pending",
    reviewerNotes?: string
  ) => void | Promise<void>;
  onPedirResubida: (id: string, reviewerNotes?: string) => void | Promise<void>;
  onSaveDriverProfile: (
    driverId: string,
    patch: { nombre: string; apellido: string; dni: string }
  ) => void | Promise<void>;
};

function extractStoragePath(raw: string): string {
  const t = raw.trim();
  const marker = "conductor_verificacion/";
  const idx = t.indexOf(marker);
  if (idx >= 0) {
    return decodeURIComponent(t.slice(idx + marker.length).split("?")[0] ?? "");
  }
  return t.replace(/^\//, "");
}

export default function KycReviewPanel({
  supabase,
  docs,
  perfilMap,
  loading,
  acting,
  labelDoc,
  onSetDocStatus,
  onPedirResubida,
  onSaveDriverProfile,
}: Props) {
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [reviewerNotes, setReviewerNotes] = useState("");
  const [resolvedUrl, setResolvedUrl] = useState<string | null>(null);
  const [resolvingUrl, setResolvingUrl] = useState(false);
  const [lightboxOpen, setLightboxOpen] = useState(false);
  const [nombreEdit, setNombreEdit] = useState("");
  const [apellidoEdit, setApellidoEdit] = useState("");
  const [dniEdit, setDniEdit] = useState("");
  const [savingPerfil, setSavingPerfil] = useState(false);

  const selected = useMemo(() => {
    if (!docs.length) return null;
    if (selectedId) {
      const found = docs.find((d) => d.id === selectedId);
      if (found) return found;
    }
    return docs[0];
  }, [docs, selectedId]);

  useEffect(() => {
    if (docs.length && !selectedId) {
      setSelectedId(docs[0].id);
    }
  }, [docs, selectedId]);

  useEffect(() => {
    const fb = selected?.feedback_conductor?.trim();
    const n = selected?.notes?.trim();
    setReviewerNotes(fb || n || "");
  }, [selected?.id, selected?.feedback_conductor, selected?.notes]);

  const driverId = selected?.driver_id;
  const perfil = driverId ? perfilMap[driverId] : undefined;

  useEffect(() => {
    if (!perfil) {
      setNombreEdit("");
      setApellidoEdit("");
      setDniEdit("");
      return;
    }
    setNombreEdit(perfil.nombre ?? "");
    setApellidoEdit(perfil.apellido ?? "");
    setDniEdit(perfil.dni ?? "");
  }, [perfil?.id, perfil?.nombre, perfil?.apellido, perfil?.dni]);

  useEffect(() => {
    let cancelled = false;
    const raw = selected?.document_url?.trim();
    if (!raw) {
      setResolvedUrl(null);
      setResolvingUrl(false);
      return;
    }
    if (raw.startsWith("data:") || raw.startsWith("blob:")) {
      setResolvedUrl(raw);
      setResolvingUrl(false);
      return;
    }
    if (raw.startsWith("http") && !raw.includes("conductor_verificacion")) {
      setResolvedUrl(raw);
      setResolvingUrl(false);
      return;
    }
    setResolvingUrl(true);
    void (async () => {
      try {
        const path = extractStoragePath(raw);
        if (!path) {
          if (!cancelled) setResolvedUrl(raw);
          return;
        }
        const { data, error } = await supabase.storage
          .from("conductor_verificacion")
          .createSignedUrl(path, 3600);
        if (cancelled) return;
        if (error) {
          setResolvedUrl(raw.startsWith("http") ? raw : null);
          return;
        }
        setResolvedUrl(data?.signedUrl ?? null);
      } finally {
        if (!cancelled) setResolvingUrl(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [selected?.document_url, supabase]);

  if (loading) {
    return (
      <div className="flex min-h-[420px] items-center justify-center rounded-2xl border border-zinc-200 bg-white dark:border-zinc-800 dark:bg-zinc-950">
        <Loader2 className="h-10 w-10 animate-spin text-zinc-400" />
      </div>
    );
  }

  if (!docs.length) {
    return (
      <div className="rounded-2xl border border-zinc-200 bg-white px-6 py-16 text-center text-sm text-zinc-500 dark:border-zinc-800 dark:bg-zinc-950">
        No hay documentos en cola.
      </div>
    );
  }

  const busy = selected ? acting === selected.id : false;

  const handleSavePerfil = async () => {
    if (!driverId) return;
    setSavingPerfil(true);
    try {
      await onSaveDriverProfile(driverId, {
        nombre: nombreEdit.trim(),
        apellido: apellidoEdit.trim(),
        dni: dniEdit.trim(),
      });
    } finally {
      setSavingPerfil(false);
    }
  };

  return (
    <>
      <div className="flex min-h-[min(720px,calc(100vh-10rem))] flex-col gap-4 overflow-hidden rounded-2xl border border-zinc-200 bg-white shadow-sm lg:flex-row dark:border-zinc-800 dark:bg-zinc-950">
        <aside className="flex max-h-[220px] shrink-0 flex-col border-b border-zinc-100 dark:border-zinc-800 lg:max-h-none lg:w-56 lg:border-b-0 lg:border-r">
          <div className="flex items-center gap-2 border-b border-zinc-100 px-3 py-3 dark:border-zinc-800">
            <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-violet-100 text-violet-700 dark:bg-violet-950 dark:text-violet-300">
              <FileWarning className="h-4 w-4" />
            </div>
            <div className="min-w-0">
              <p className="truncate text-xs font-semibold text-zinc-900 dark:text-white">
                Cola KYC
              </p>
              <p className="text-[10px] text-zinc-500">{docs.length} ítems</p>
            </div>
          </div>
          <ul className="flex-1 overflow-y-auto p-1">
            {docs.map((d) => (
              <li key={d.id}>
                <button
                  type="button"
                  onClick={() => setSelectedId(d.id)}
                  className={`mb-0.5 w-full rounded-lg px-2.5 py-2 text-left text-xs transition ${
                    d.id === selected?.id
                      ? "bg-violet-100 font-medium text-violet-950 dark:bg-violet-950/60 dark:text-violet-100"
                      : "text-zinc-600 hover:bg-zinc-50 dark:text-zinc-400 dark:hover:bg-zinc-900/80"
                  }`}
                >
                  <span className="block truncate">{labelDoc(d.document_type)}</span>
                  <span className="block truncate font-mono text-[10px] opacity-70">
                    {d.driver_id.slice(0, 8)}…
                  </span>
                </button>
              </li>
            ))}
          </ul>
        </aside>

        <div className="relative flex min-h-[280px] flex-1 flex-col bg-zinc-900 lg:min-h-0">
          <div className="relative flex min-h-[240px] flex-1 items-center justify-center p-2">
            {resolvingUrl ? (
              <Loader2 className="h-10 w-10 animate-spin text-zinc-500" />
            ) : resolvedUrl ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img
                src={resolvedUrl}
                alt={selected ? labelDoc(selected.document_type) : ""}
                className="max-h-[min(420px,55vh)] max-w-full cursor-zoom-in object-contain lg:max-h-full"
                onClick={() => setLightboxOpen(true)}
              />
            ) : (
              <p className="px-6 text-center text-sm text-zinc-400">
                Sin archivo cargado o no se pudo firmar la URL de Storage.
              </p>
            )}
            {resolvedUrl ? (
              <button
                type="button"
                onClick={() => setLightboxOpen(true)}
                className="absolute bottom-3 right-3 inline-flex items-center gap-1.5 rounded-lg bg-black/60 px-3 py-2 text-xs font-semibold text-white backdrop-blur hover:bg-black/80"
              >
                <Maximize2 className="h-3.5 w-3.5" />
                Ampliar
              </button>
            ) : null}
          </div>
        </div>

        <aside className="flex w-full shrink-0 flex-col gap-4 border-t border-zinc-100 p-4 dark:border-zinc-800 lg:w-[22rem] lg:border-l lg:border-t-0">
          <div>
            <p className="text-xs font-semibold uppercase tracking-wide text-zinc-500">
              Conductor
            </p>
            <p className="font-medium text-zinc-900 dark:text-white">
              {[perfil?.nombre, perfil?.apellido].filter(Boolean).join(" ") || "—"}
            </p>
            <p className="text-xs text-zinc-500">{perfil?.email ?? "—"}</p>
          </div>

          <div className="space-y-2 rounded-xl border border-zinc-100 bg-zinc-50/80 p-3 dark:border-zinc-800 dark:bg-zinc-900/40">
            <p className="text-xs font-semibold uppercase tracking-wide text-zinc-500">
              Editar datos del perfil
            </p>
            <input
              value={nombreEdit}
              onChange={(e) => setNombreEdit(e.target.value)}
              placeholder="Nombre"
              className="w-full rounded-lg border border-zinc-200 bg-white px-3 py-2 text-sm dark:border-zinc-700 dark:bg-zinc-950 dark:text-white"
            />
            <input
              value={apellidoEdit}
              onChange={(e) => setApellidoEdit(e.target.value)}
              placeholder="Apellido"
              className="w-full rounded-lg border border-zinc-200 bg-white px-3 py-2 text-sm dark:border-zinc-700 dark:bg-zinc-950 dark:text-white"
            />
            <input
              value={dniEdit}
              onChange={(e) => setDniEdit(e.target.value)}
              placeholder="DNI / documento"
              className="w-full rounded-lg border border-zinc-200 bg-white px-3 py-2 text-sm dark:border-zinc-700 dark:bg-zinc-950 dark:text-white"
            />
            <button
              type="button"
              disabled={savingPerfil || !driverId || busy}
              onClick={() => void handleSavePerfil()}
              className="w-full rounded-lg bg-zinc-900 py-2.5 text-sm font-semibold text-white hover:bg-zinc-800 disabled:opacity-50 dark:bg-violet-600 dark:hover:bg-violet-500"
            >
              {savingPerfil ? "Guardando…" : "Guardar datos del conductor"}
            </button>
          </div>

          <div>
            <p className="text-xs font-semibold uppercase tracking-wide text-zinc-500">
              Documento
            </p>
            <p className="text-sm font-medium text-zinc-900 dark:text-white">
              {selected ? labelDoc(selected.document_type) : "—"}
            </p>
            <p className="text-xs text-zinc-500">
              Alta:{" "}
              {selected
                ? new Date(selected.created_at).toLocaleString("es-AR")
                : "—"}
            </p>
          </div>

          <div className="space-y-2">
            <label
              htmlFor="kyc-feedback-conductor"
              className="text-xs font-semibold uppercase tracking-wide text-zinc-500"
            >
              Comentarios / motivo (conductor)
            </label>
            <textarea
              id="kyc-feedback-conductor"
              rows={4}
              value={reviewerNotes}
              onChange={(e) => setReviewerNotes(e.target.value)}
              placeholder="Ej. Foto del seguro borrosa — lo verá en la app junto al estado."
              className="w-full resize-y rounded-xl border border-zinc-200 bg-white px-3 py-2 text-sm text-zinc-900 placeholder:text-zinc-400 focus:border-violet-500 focus:outline-none focus:ring-1 focus:ring-violet-500 dark:border-zinc-700 dark:bg-zinc-900 dark:text-white"
            />
          </div>

          <div className="mt-auto flex flex-col gap-2">
            <button
              type="button"
              disabled={busy || !selected}
              onClick={() =>
                selected &&
                void onSetDocStatus(selected.id, "approved", reviewerNotes)
              }
              className="inline-flex items-center justify-center gap-2 rounded-xl bg-emerald-600 px-4 py-3 text-sm font-semibold text-white hover:bg-emerald-700 disabled:opacity-50"
            >
              <CheckCircle2 className="h-4 w-4" />
              Aprobado
            </button>
            <button
              type="button"
              disabled={busy || !selected}
              onClick={() =>
                selected &&
                void onSetDocStatus(selected.id, "pending", reviewerNotes)
              }
              className="inline-flex items-center justify-center gap-2 rounded-xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm font-semibold text-amber-950 hover:bg-amber-100 disabled:opacity-50 dark:border-amber-900 dark:bg-amber-950/40 dark:text-amber-100"
            >
              <Clock className="h-4 w-4" />
              Pendiente
            </button>
            <button
              type="button"
              disabled={busy || !selected}
              onClick={() =>
                selected &&
                void onSetDocStatus(selected.id, "rejected", reviewerNotes)
              }
              className="inline-flex items-center justify-center gap-2 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm font-semibold text-red-800 hover:bg-red-100 disabled:opacity-50 dark:border-red-900 dark:bg-red-950/50 dark:text-red-200"
            >
              <XCircle className="h-4 w-4" />
              Rechazado
            </button>
            <button
              type="button"
              disabled={busy || !selected}
              onClick={() =>
                selected && void onPedirResubida(selected.id, reviewerNotes)
              }
              className="inline-flex items-center justify-center gap-2 rounded-xl border border-zinc-200 bg-zinc-50 px-4 py-2.5 text-xs font-semibold text-zinc-800 hover:bg-zinc-100 disabled:opacity-50 dark:border-zinc-700 dark:bg-zinc-900 dark:text-zinc-200"
            >
              <Upload className="h-3.5 w-3.5" />
              Solicitar re-subida
            </button>
          </div>
        </aside>
      </div>

      {lightboxOpen && resolvedUrl ? (
        <div
          className="fixed inset-0 z-[100] flex flex-col bg-black/95 p-4"
          role="dialog"
          aria-modal="true"
          aria-label="Vista ampliada del documento"
        >
          <div className="flex justify-end">
            <button
              type="button"
              onClick={() => setLightboxOpen(false)}
              className="rounded-full bg-white/10 p-2 text-white hover:bg-white/20"
              aria-label="Cerrar"
            >
              <X className="h-6 w-6" />
            </button>
          </div>
          <div className="flex min-h-0 flex-1 items-center justify-center overflow-hidden">
            <div className="h-full w-full overflow-auto">
              <div className="flex min-h-full min-w-full items-center justify-center p-4">
                <div className="inline-block max-h-[85vh] max-w-full origin-center">
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img
                    src={resolvedUrl}
                    alt=""
                    className="max-h-[85vh] max-w-full object-contain"
                  />
                </div>
              </div>
            </div>
          </div>
          <p className="text-center text-xs text-zinc-400">
            Usá zoom del navegador o gestos para ampliar la imagen.
          </p>
        </div>
      ) : null}
    </>
  );
}
