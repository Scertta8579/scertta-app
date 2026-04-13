"use client";

import { useCallback, useEffect, useState } from "react";
import { Loader2, Receipt } from "lucide-react";
import { supabase } from "@/lib/supabaseClient";

type SettlementRow = {
  id: string;
  trip_id: string | null;
  driver_id: string;
  payment_method: string;
  monto_bruto: number;
  comision_scertta_pct: number;
  gastos_operativos_pct: number;
  comision_scertta_ars: number;
  gastos_operativos_ars: number;
  conductor_delta_ars: number;
  plataforma_total_ars: number;
  created_at: string;
};

export default function CeoLiquidacionesWallet() {
  const [rows, setRows] = useState<SettlementRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setErr(null);
    const { data, error } = await supabase
      .from("trip_financial_settlements")
      .select(
        "id,trip_id,driver_id,payment_method,monto_bruto,comision_scertta_pct,gastos_operativos_pct,comision_scertta_ars,gastos_operativos_ars,conductor_delta_ars,plataforma_total_ars,created_at"
      )
      .order("created_at", { ascending: false })
      .limit(40);
    setLoading(false);
    if (error) {
      setErr(error.message);
      setRows([]);
      return;
    }
    setRows((data as SettlementRow[]) ?? []);
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  return (
    <div className="mt-6 rounded-2xl border border-black/10 bg-white p-6 dark:border-white/10 dark:bg-zinc-950">
      <div className="mb-4 flex flex-wrap items-center justify-between gap-2">
        <div className="flex items-center gap-2">
          <Receipt className="h-5 w-5 text-emerald-600" />
          <h3 className="font-semibold">Liquidaciones de viajes (billetera)</h3>
        </div>
        <button
          type="button"
          onClick={() => void load()}
          disabled={loading}
          className="inline-flex items-center gap-2 rounded-xl border border-black/10 px-3 py-1.5 text-xs font-medium dark:border-white/15"
        >
          {loading ? (
            <Loader2 className="h-3.5 w-3.5 animate-spin" />
          ) : null}
          Actualizar
        </button>
      </div>
      <p className="mb-4 text-xs text-apple-gray">
        Registros en{" "}
        <code className="rounded bg-black/5 px-1 dark:bg-white/10">
          trip_financial_settlements
        </code>{" "}
        al confirmar pago en la app conductor. Efectivo: descuento en saldo;
        tarjeta: abono neto al conductor.
      </p>
      {err ? (
        <p className="text-sm text-red-600 dark:text-red-400">{err}</p>
      ) : null}
      {loading && !rows.length ? (
        <div className="flex justify-center py-10">
          <Loader2 className="h-8 w-8 animate-spin text-zinc-400" />
        </div>
      ) : !rows.length ? (
        <p className="py-8 text-center text-sm text-apple-gray">
          Aún no hay liquidaciones registradas.
        </p>
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full min-w-[720px] text-left text-xs">
            <thead>
              <tr className="border-b border-black/10 text-apple-gray dark:border-white/10">
                <th className="py-2 pr-2">Fecha</th>
                <th className="py-2 pr-2">Método</th>
                <th className="py-2 pr-2">Bruto</th>
                <th className="py-2 pr-2">Plataforma</th>
                <th className="py-2 pr-2">Δ conductor</th>
                <th className="py-2 pr-2">Viaje</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((r) => (
                <tr
                  key={r.id}
                  className="border-b border-black/5 dark:border-white/5"
                >
                  <td className="py-2 pr-2 whitespace-nowrap">
                    {new Date(r.created_at).toLocaleString("es-AR")}
                  </td>
                  <td className="py-2 pr-2 capitalize">{r.payment_method}</td>
                  <td className="py-2 pr-2 font-mono">
                    ${Number(r.monto_bruto).toFixed(2)}
                  </td>
                  <td className="py-2 pr-2 font-mono text-emerald-700 dark:text-emerald-400">
                    ${Number(r.plataforma_total_ars).toFixed(2)}
                  </td>
                  <td className="py-2 pr-2 font-mono">
                    ${Number(r.conductor_delta_ars).toFixed(2)}
                  </td>
                  <td className="max-w-[120px] truncate py-2 pr-2 font-mono text-apple-gray">
                    {r.trip_id?.slice(0, 8) ?? "—"}…
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
