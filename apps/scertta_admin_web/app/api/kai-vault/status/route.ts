import { NextResponse } from "next/server";
import { execSync } from "child_process";
import { readFileSync, existsSync } from "fs";
import path from "path";

const GRAPH_PATH = "/DATA/obsidian-vault/.graph/graph.json";

export async function GET() {
  try {
    const status: any = {
      vault_exists: existsSync("/DATA/obsidian-vault"),
      graph_exists: existsSync(GRAPH_PATH),
      graph_stats: null,
      top_nodes: [],
      cron_active: true, // Por ahora hardcoded — el cron job "Kai Graph Regenerator" está activo
      last_regenerated: null,
      note_count: 0,
    };

    if (status.graph_exists) {
      const raw = readFileSync(GRAPH_PATH, "utf-8");
      const data = JSON.parse(raw);
      const nodes = data.nodes || [];
      const links = data.links || [];

      // Calcular grados
      const degree: Record<string, number> = {};
      for (const l of links) {
        degree[l.source] = (degree[l.source] || 0) + 1;
        degree[l.target] = (degree[l.target] || 0) + 1;
      }

      status.graph_stats = {
        nodes: nodes.length,
        edges: links.length,
        communities: new Set(nodes.map((n: any) => n.community).filter((c: any) => c !== undefined)).size,
      };

      status.top_nodes = Object.entries(degree)
        .sort(([, a], [, b]) => (b as number) - (a as number))
        .slice(0, 8)
        .map(([name, deg]) => ({ name, connections: deg }));
    }

    // Contar notas .md
    if (status.vault_exists) {
      const { execSync } = require("child_process");
      try {
        const count = execSync(
          `find /DATA/obsidian-vault -name "*.md" -not -path "*/.graph/*" -not -path "*/.git/*" | wc -l`,
          { encoding: "utf-8" }
        ).trim();
        status.note_count = parseInt(count, 10) || 0;
      } catch {}
    }

    // Última regeneración
    if (status.graph_exists) {
      try {
        const stat = require("fs").statSync(GRAPH_PATH);
        status.last_regenerated = stat.mtime.toISOString();
      } catch {}
    }

    return NextResponse.json(status);
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
