import GestorPromocionesGeograficas from "@/components/GestorPromocionesGeograficas";

export default function CeoDashboardPage() {
  return (
    <div className="min-h-screen bg-background text-foreground">
      <header className="border-b border-black/10 bg-white dark:border-white/15 dark:bg-black">
        <div className="mx-auto flex w-full max-w-7xl items-center justify-between px-6 py-5">
          <h1 className="text-lg font-semibold tracking-tight">
            CEO dashboard — <span translate="no" className="notranslate">Scertta</span>
          </h1>
          <span className="rounded-full bg-scertta-blue/10 px-3 py-1 text-xs font-medium text-scertta-blue">
            Analítica avanzada y control estratégico
          </span>
        </div>
      </header>
      <main className="mx-auto w-full max-w-7xl px-6 py-10">
        <GestorPromocionesGeograficas />
      </main>
    </div>
  );
}

