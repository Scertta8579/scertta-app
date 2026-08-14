"use client";

import { Layers } from "lucide-react";

interface Props {
  zoom: number;
  h3Visible: boolean;
  onToggleH3: () => void;
  position?: "bottom-right" | "bottom-left";
}

export default function ZoomHexWidget({
  zoom,
  h3Visible,
  onToggleH3,
  position = "bottom-right",
}: Props) {
  const posClass =
    position === "bottom-right" ? "right-3" : "left-3";

  return (
    <div
      className={`absolute bottom-3 ${posClass} z-20 flex flex-col gap-1.5`}
      style={{ pointerEvents: "auto" }}
    >
      {/* Zoom reader */}
      <div
        style={{
          background: "rgba(15, 23, 42, 0.88)",
          color: "#FAFAF5",
          padding: "5px 12px",
          borderRadius: "8px",
          fontSize: "13px",
          fontFamily: "monospace",
          fontWeight: 600,
          backdropFilter: "blur(6px)",
          border: "1px solid rgba(212, 160, 23, 0.35)",
          boxShadow: "0 2px 12px rgba(0,0,0,0.3)",
          textAlign: "center",
        }}
      >
        Zoom: {zoom.toFixed(1)}
      </div>

      {/* H3 hexágonos toggle */}
      <button
        onClick={onToggleH3}
        className={`flex items-center gap-2 px-3 py-2 text-xs font-semibold rounded-lg shadow-lg transition-all backdrop-blur ${
          h3Visible
            ? "bg-[#64DEB2] text-[#0F172A] border border-[#64DEB2]"
            : "bg-white/90 text-slate-700 hover:bg-white border border-slate-200"
        }`}
        title={h3Visible ? "Ocultar hexágonos H3" : "Mostrar hexágonos H3"}
      >
        <Layers className="h-3.5 w-3.5" />
        {h3Visible ? "Hexágonos ON" : "Hexágonos OFF"}
      </button>
    </div>
  );
}
