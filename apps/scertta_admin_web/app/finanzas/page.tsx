import CfoDashboard from "@/components/finanzas/CfoDashboard";
import { Landmark } from "lucide-react";

export default function FinanzasPage() {
  return (
    <div className="min-h-screen bg-slate-100 text-slate-900 dark:bg-slate-950 dark:text-slate-100">
      <header className="sticky top-0 z-30 border-b border-slate-200/80 bg-white/90 backdrop-blur-md dark:border-slate-800 dark:bg-slate-950/90">
        <div className="mx-auto flex w-full max-w-[1600px] flex-wrap items-center justify-between gap-4 px-4 py-4 sm:px-6 lg:px-8">
          <div className="flex min-w-0 items-center gap-3">
            <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-gradient-to-br from-emerald-600 to-teal-700 text-white shadow-lg shadow-emerald-500/20">
              <Landmark className="h-5 w-5" />
            </div>
            <div>
              <p className="text-[11px] font-semibold uppercase tracking-wider text-slate-500">
                <span translate="no" className="notranslate">
                  Scertta
                </span>{" "}
                Treasury
              </p>
              <h1 className="text-lg font-bold tracking-tight sm:text-xl">
                Control financiero (CFO)
              </h1>
            </div>
          </div>
          <span className="rounded-full border border-emerald-200 bg-emerald-50 px-3 py-1 text-xs font-semibold text-emerald-900 dark:border-emerald-900 dark:bg-emerald-950/50 dark:text-emerald-200">
            Libro mayor · Ciclos dominicales · Pasajeros
          </span>
        </div>
      </header>
      <main className="mx-auto w-full max-w-[1600px] px-4 py-8 sm:px-6 lg:px-8">
        <CfoDashboard />
      </main>
    </div>
  );
}
