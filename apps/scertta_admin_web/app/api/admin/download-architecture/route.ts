import { NextResponse } from "next/server";
import fs from "fs";
import path from "path";

export async function GET() {
  const archPath = path.resolve(process.cwd(), "../../../ARCHITECTURE.md");
  
  try {
    const content = fs.readFileSync(archPath, "utf-8");
    return new NextResponse(content, {
      headers: {
        "Content-Type": "text/markdown; charset=utf-8",
        "Content-Disposition": `attachment; filename="ARCHITECTURE.md"`,
      },
    });
  } catch {
    // Fallback: embedded content
    const fallback = `# Scertta Architecture\n\nSee ARCHITECTURE.md in repository root.\n`;
    return new NextResponse(fallback, {
      headers: {
        "Content-Type": "text/markdown; charset=utf-8",
        "Content-Disposition": `attachment; filename="ARCHITECTURE.md"`,
      },
    });
  }
}
