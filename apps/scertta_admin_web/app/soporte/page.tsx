import SoporteDashboard from "@/components/soporte/SoporteDashboard";
import { LayoutDashboard } from "lucide-react";

export default function SoportePage() {
  return (
    <div className="min-h-screen bg-zinc-100 text-zinc-900 dark:bg-zinc-950 dark:text-zinc-100">
      <header className="sticky top-0 z-30 border-b border-zinc-200/80 bg-white/90 backdrop-blur-md dark:border-zinc-800 dark:bg-zinc-950/90">
        <div className="mx-auto flex w-full max-w-[1600px] flex-wrap items-center justify-between gap-4 px-4 py-4 sm:px-6 lg:px-8">
          <div className="flex min-w-0 items-center gap-3">
            <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-gradient-to-br from-rutmy-agua to-blue-600 text-white shadow-lg shadow-cyan-500/25">
              <LayoutDashboard className="h-5 w-5" />
            </div>
            <div className="min-w-0">
              <p className="text-[11px] font-semibold uppercase tracking-wider text-zinc-500">
                <span translate="no" className="notranslate">Rutmy</span>{" "}Soporte
              </p>
              <h1 className="truncate text-lg font-bold tracking-tight sm:text-xl">Centro de soporte</h1>
            </div>
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <span className="rounded-full border border-emerald-200 bg-emerald-50 px-3 py-1 text-xs font-semibold text-emerald-800 dark:border-emerald-900 dark:bg-emerald-950/60 dark:text-emerald-300">
              KYC · Soporte L1 · Búsqueda
            </span>
          </div>
        </div>
      </header>
      <main className="mx-auto w-full max-w-[1600px] px-4 py-8 sm:px-6 lg:px-8">
        <SoporteDashboard />
      </main>
    </div>
  );
}
