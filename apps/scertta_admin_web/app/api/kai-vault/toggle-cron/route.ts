import { NextRequest, NextResponse } from "next/server";

/**
 * POST /api/kai-vault/toggle-cron
 * Activa/desactiva el cron job de regeneración del grafo Kai Vault.
 * 
 * Body: { activo: boolean }
 */
export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const { activo } = body;

    if (typeof activo !== "boolean") {
      return NextResponse.json({ error: "activo debe ser boolean" }, { status: 400 });
    }

    // Pausar o reanudar el cron job "Kai Graph Regenerator"
    const { execSync } = require("child_process");
    
    const jobId = "60a3d372018f"; // ID del cron job creado
    
    if (activo) {
      execSync(`hermes cronjob resume ${jobId}`, { encoding: "utf-8", timeout: 10000 });
    } else {
      execSync(`hermes cronjob pause ${jobId}`, { encoding: "utf-8", timeout: 10000 });
    }

    return NextResponse.json({ 
      success: true, 
      cron_activo: activo,
      message: activo 
        ? "Regeneración automática activada (cada 6h)" 
        : "Regeneración automática pausada"
    });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
