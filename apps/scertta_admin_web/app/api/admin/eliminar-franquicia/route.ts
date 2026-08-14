// DEPRECATED — Redirige a /api/admin/rescindir-franquicia
// Esta ruta se mantiene solo para compatibilidad hacia atrás.
import { NextResponse, type NextRequest } from "next/server";

export async function POST(request: NextRequest) {
  const body = await request.json();
  const res = await fetch(`${request.nextUrl.origin}/api/admin/rescindir-franquicia`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  const data = await res.json();
  return NextResponse.json(data, { status: res.status });
}
