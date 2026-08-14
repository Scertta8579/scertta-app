"use client";

import { useState, useCallback } from "react";

export default function TestAnalisisPage() {
  const [image, setImage] = useState<File | null>(null);
  const [preview, setPreview] = useState<string | null>(null);
  const [result, setResult] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [modelInfo, setModelInfo] = useState<string>("");

  const handleDrop = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    const file = e.dataTransfer.files[0];
    if (file && file.type.startsWith("image/")) {
      setImage(file);
      setPreview(URL.createObjectURL(file));
      setResult(null);
      setError(null);
    }
  }, []);

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      setImage(file);
      setPreview(URL.createObjectURL(file));
      setResult(null);
      setError(null);
    }
  };

  const handleAnalyze = async () => {
    if (!image) return;
    setLoading(true);
    setError(null);
    setResult(null);

    try {
      const reader = new FileReader();
      const base64Promise = new Promise<string>((resolve) => {
        reader.onload = () => {
          const base64 = (reader.result as string).split(",")[1];
          resolve(base64);
        };
      });
      reader.readAsDataURL(image);
      const imageBase64 = await base64Promise;

      const resp = await fetch("/api/test-analisis", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ image: imageBase64, filename: image.name }),
      });

      const data = await resp.json();

      if (data.error) {
        setError(data.error);
      } else {
        setResult(JSON.stringify(data.extracted, null, 2));
        setModelInfo(data.model || "");
      }
    } catch (err: any) {
      setError(err.message || "Error al procesar la imagen");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-[#0F172A] text-white p-6">
      <div className="max-w-2xl mx-auto">
        <h1 className="text-2xl font-bold mb-2">🔐 Test KYC — Procesamiento Local</h1>
        <p className="text-slate-400 mb-6">
          Subí una foto de un documento. Se procesa <strong>100% en local</strong> — 
          sin enviar datos a internet.
          {modelInfo && (
            <span className="block mt-1 text-cyan-400 text-sm">
              Modelo activo: {modelInfo}
            </span>
          )}
        </p>

        {/* Drop zone */}
        <div
          onDrop={handleDrop}
          onDragOver={(e) => e.preventDefault()}
          className="border-2 border-dashed border-slate-600 rounded-xl p-8 text-center cursor-pointer
                     hover:border-cyan-500 transition-colors mb-4"
          onClick={() => document.getElementById("fileInput")?.click()}
        >
          {preview ? (
            <img
              src={preview}
              alt="Preview"
              className="max-h-64 mx-auto rounded-lg shadow-lg"
            />
          ) : (
            <div className="text-slate-400">
              <div className="text-4xl mb-2">📄</div>
              <p>Arrastrá una imagen acá o hacé clic para seleccionar</p>
              <p className="text-sm mt-1">JPG, PNG, WEBP</p>
            </div>
          )}
          <input
            id="fileInput"
            type="file"
            accept="image/*"
            onChange={handleFileChange}
            className="hidden"
          />
        </div>

        {/* Analyze button */}
        <button
          onClick={handleAnalyze}
          disabled={!image || loading}
          className="w-full py-3 rounded-lg font-semibold transition-all
                     bg-cyan-600 hover:bg-cyan-500 disabled:bg-slate-700 disabled:text-slate-500
                     text-white"
        >
          {loading ? (
            <span className="flex items-center justify-center gap-2">
              <span className="animate-spin">⏳</span> Procesando con Gemma 4...
            </span>
          ) : (
            "🔍 Analizar Documento"
          )}
        </button>

        {/* Error */}
        {error && (
          <div className="mt-4 p-4 bg-red-900/50 border border-red-700 rounded-lg text-red-300">
            <strong>Error:</strong> {error}
          </div>
        )}

        {/* Result */}
        {result && (
          <div className="mt-4 p-4 bg-slate-800 border border-slate-700 rounded-lg">
            <h2 className="text-lg font-semibold mb-2 text-cyan-400">📋 Datos Extraídos</h2>
            <pre className="text-sm text-slate-300 overflow-x-auto whitespace-pre-wrap font-mono">
              {result}
            </pre>
          </div>
        )}

        {/* Info footer */}
        <div className="mt-8 text-xs text-slate-600">
          <p>🛡️ Privacidad: La imagen se procesa en el servidor local (ZimaOS).</p>
          <p>No se almacena ni se envía a servicios externos.</p>
        </div>
      </div>
    </div>
  );
}
