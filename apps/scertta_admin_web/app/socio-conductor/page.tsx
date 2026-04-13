export default function SocioConductorPage() {
  return (
    <div className="min-h-screen bg-background text-foreground">
      <header className="border-b border-black/10 bg-white dark:border-white/15 dark:bg-black">
        <div className="mx-auto flex w-full max-w-5xl items-center justify-between px-6 py-5">
          <h1 className="text-lg font-semibold tracking-tight">
            Socio-conductor — <span translate="no" className="notranslate">Scertta</span>
          </h1>
          <span className="rounded-full bg-scertta-blue/10 px-3 py-1 text-xs font-medium text-scertta-blue">
            Gestión del socio prestador
          </span>
        </div>
      </header>
      <main className="mx-auto w-full max-w-5xl px-6 py-10">
        <p className="text-apple-gray">
          Herramienta de gestión para el socio prestador del servicio de
          movilidad.
        </p>
      </main>
    </div>
  );
}

