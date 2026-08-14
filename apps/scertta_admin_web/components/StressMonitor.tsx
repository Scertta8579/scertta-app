"use client";

import { useState, useEffect, useRef } from "react";
import { Activity, Cpu, HardDrive, Zap, AlertTriangle, CheckCircle2 } from "lucide-react";

interface ServiceMetrics {
  status: "up" | "down" | "degraded";
  latency_ms: number;
  cpu_pct: number;
  ram_mb: number;
  rps: number;
}

interface SystemMetrics {
  cpu_total_pct: number;
  ram_used_mb: number;
  ram_total_mb: number;
  load_1min: number;
}

interface StressReport {
  timestamp: string;
  services: Record<string, ServiceMetrics>;
  system: SystemMetrics;
  alerts: string[];
}

const THRESHOLDS = {
  latency: { warn: 300, critical: 600 },   // ms
  cpu: { warn: 60, critical: 85 },          // %
  rps: { low: 5, high: 50 },               // requests/sec
};

export default function StressMonitor() {
  const [data, setData] = useState<StressReport | null>(null);
  const [history, setHistory] = useState<number[]>([]);
  const [expanded, setExpanded] = useState(false);
  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null);

  useEffect(() => {
    const fetchStress = async () => {
      try {
        const res = await fetch("/api/stress");
        if (!res.ok) return;
        const json: StressReport = await res.json();
        setData(json);

        // Track Martin latency history (last 20 points)
        const martinLat = json.services.martin_tiles?.latency_ms ?? 0;
        setHistory((prev) => [...prev.slice(-19), martinLat]);
      } catch {
        // silencio — no spamear consola
      }
    };

    fetchStress();
    intervalRef.current = setInterval(fetchStress, 2500);
    return () => {
      if (intervalRef.current) clearInterval(intervalRef.current);
    };
  }, []);

  const getLatencyColor = (ms: number) =>
    ms > THRESHOLDS.latency.critical
      ? "text-red-500"
      : ms > THRESHOLDS.latency.warn
      ? "text-amber-500"
      : "text-emerald-400";

  const getCpuColor = (pct: number) =>
    pct > THRESHOLDS.cpu.critical
      ? "text-red-500"
      : pct > THRESHOLDS.cpu.warn
      ? "text-amber-500"
      : "text-emerald-400";

  const getStatusBadge = (status: string) => {
    switch (status) {
      case "up":
        return <CheckCircle2 className="h-3.5 w-3.5 text-emerald-400" />;
      case "degraded":
        return <AlertTriangle className="h-3.5 w-3.5 text-amber-400" />;
      default:
        return <AlertTriangle className="h-3.5 w-3.5 text-red-500 animate-pulse" />;
    }
  };

  const hasAlerts = data && data.alerts.length > 0;

  return (
    <div
      className={`rounded-xl border transition-colors ${
        hasAlerts
          ? "border-red-500/50 bg-red-500/5"
          : "border-zinc-700 bg-zinc-900"
      }`}
    >
      {/* Header */}
      <button
        onClick={() => setExpanded(!expanded)}
        className="w-full flex items-center justify-between px-4 py-3"
      >
        <div className="flex items-center gap-2">
          <Activity
            className={`h-5 w-5 ${
              hasAlerts ? "text-red-400 animate-pulse" : "text-zinc-400"
            }`}
          />
          <span className="text-sm font-semibold text-zinc-200">
            Stress Monitor
          </span>
          {hasAlerts && (
            <span className="flex items-center gap-1 px-2 py-0.5 rounded-full bg-red-500/20 text-red-400 text-xs font-bold">
              <AlertTriangle className="h-3 w-3" />
              {data!.alerts.length}
            </span>
          )}
        </div>
        <span className="text-xs text-zinc-500">{expanded ? "▲" : "▼"}</span>
      </button>

      {expanded && data && (
        <div className="px-4 pb-4 space-y-4">
          {/* Alertas */}
          {data.alerts.length > 0 && (
            <div className="space-y-1">
              {data.alerts.map((a, i) => (
                <div
                  key={i}
                  className="flex items-center gap-2 px-3 py-1.5 rounded bg-red-500/10 border border-red-500/20 text-xs text-red-400"
                >
                  <AlertTriangle className="h-3.5 w-3.5 shrink-0" />
                  {a}
                </div>
              ))}
            </div>
          )}

          {/* Servicios */}
          <div className="grid grid-cols-2 gap-2">
            {Object.entries(data.services).map(([key, s]) => (
              <div
                key={key}
                className="flex flex-col gap-1 px-3 py-2 rounded-lg bg-zinc-800/50"
              >
                <div className="flex items-center justify-between">
                  <span className="text-xs text-zinc-400 capitalize">
                    {key.replace("_", " ")}
                  </span>
                  {getStatusBadge(s.status)}
                </div>
                <div className="flex items-center gap-3">
                  <span className={`text-lg font-mono font-bold ${getLatencyColor(s.latency_ms)}`}>
                    {s.latency_ms}
                    <span className="text-[10px] font-normal ml-0.5">ms</span>
                  </span>
                  <span className="text-[10px] text-zinc-500">
                    {s.rps} rps
                  </span>
                </div>
                <div className="flex gap-2 text-[10px] text-zinc-500">
                  <span className="flex items-center gap-0.5">
                    <Cpu className="h-3 w-3" />
                    <span className={getCpuColor(s.cpu_pct)}>
                      {s.cpu_pct.toFixed(0)}%
                    </span>
                  </span>
                  <span className="flex items-center gap-0.5">
                    <HardDrive className="h-3 w-3" />
                    {s.ram_mb.toFixed(0)} MB
                  </span>
                </div>
              </div>
            ))}
          </div>

          {/* Sistema */}
          <div className="flex items-center justify-between px-3 py-2 rounded-lg bg-zinc-800/30 text-xs">
            <div className="flex items-center gap-4">
              <span className="text-zinc-500">
                <Zap className="h-3.5 w-3.5 inline mr-1" />
                Load {data.system.load_1min}
              </span>
              <span className="text-zinc-500">
                RAM {data.system.ram_used_mb}/{data.system.ram_total_mb} MB
              </span>
            </div>
            <span className="text-zinc-600 font-mono text-[10px]">
              {new Date(data.timestamp).toLocaleTimeString()}
            </span>
          </div>

          {/* Mini latency chart */}
          {history.length > 1 && (
            <div className="flex items-end gap-0.5 h-8">
              {history.map((ms, i) => (
                <div
                  key={i}
                  className="flex-1 rounded-t"
                  style={{
                    height: `${Math.min((ms / 200) * 100, 100)}%`,
                    backgroundColor:
                      ms > THRESHOLDS.latency.critical
                        ? "#ef4444"
                        : ms > THRESHOLDS.latency.warn
                        ? "#f59e0b"
                        : "#10b981",
                    opacity: 0.7,
                  }}
                  title={`${ms}ms`}
                />
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
