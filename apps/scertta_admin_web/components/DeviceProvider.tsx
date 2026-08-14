// components/DeviceProvider.tsx
// =============================================================================
// DeviceProvider — Contexto React para identidad de dispositivo
// -----------------------------------------------------------------------------
// No bloqueante: renderiza children inmediatamente.
// El fingerprint se calcula en useEffect asíncrono.
// Si falla → modo degradado (anonymous), nunca crashea la app.
// =============================================================================
"use client";

import {
  createContext,
  useContext,
  useEffect,
  useState,
  type ReactNode,
} from "react";
import {
  getDeviceIdentity,
  getAnonymousIdentity,
  getDeviceHeaders,
  type DeviceIdentity,
} from "@/lib/deviceFingerprint";

// ---------------------------------------------------------------------------
// Context
// ---------------------------------------------------------------------------
interface DeviceContextType {
  identity: DeviceIdentity;
  ready: boolean;              // true cuando fingerprint terminó de calcularse
  error: boolean;              // true si falló → usando identidad anónima
  headers: Record<string, string>; // headers listos para fetch()
}

const DeviceContext = createContext<DeviceContextType>({
  identity: getAnonymousIdentity(),
  ready: false,
  error: false,
  headers: {},
});

export function useDevice() {
  return useContext(DeviceContext);
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------
export function DeviceProvider({ children }: { children: ReactNode }) {
  const [identity, setIdentity] = useState<DeviceIdentity>(
    getAnonymousIdentity()
  );
  const [ready, setReady] = useState(false);
  const [error, setError] = useState(false);

  useEffect(() => {
    let cancelled = false;

    async function init() {
      try {
        // lookupFingerprint contra Supabase — para re-binding
        const lookup = async (fpHash: string): Promise<string | null> => {
          try {
            const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL;
            const SUPABASE_KEY = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
            if (!SUPABASE_URL || !SUPABASE_KEY) return null;

            const res = await fetch(
              `${SUPABASE_URL}/rest/v1/rpc/lookup_device_by_fingerprint`,
              {
                method: "POST",
                headers: {
                  "Content-Type": "application/json",
                  apikey: SUPABASE_KEY,
                  Authorization: `Bearer ${SUPABASE_KEY}`,
                },
                body: JSON.stringify({ p_fingerprint_hash: fpHash }),
              }
            );
            if (!res.ok) return null;
            const data = await res.json();
            return data?.device_id ?? null;
          } catch {
            return null; // server no disponible → no es crítico
          }
        };

        const id = await getDeviceIdentity(lookup);
        if (!cancelled) {
          setIdentity(id);
          setReady(true);
        }
      } catch {
        if (!cancelled) {
          setIdentity(getAnonymousIdentity());
          setError(true);
          setReady(true);
        }
      }
    }

    init();
    return () => {
      cancelled = true;
    };
  }, []);

  const headers = ready ? getDeviceHeaders(identity) : {};

  return (
    <DeviceContext.Provider value={{ identity, ready, error, headers }}>
      {children}
    </DeviceContext.Provider>
  );
}
