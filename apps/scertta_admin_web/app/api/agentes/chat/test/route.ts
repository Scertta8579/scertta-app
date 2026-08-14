import { NextResponse, type NextRequest } from "next/server";

export async function POST(request: NextRequest) {
  const body = await request.json();
  const key = request.headers.get("x-service-key") || "";
  
  if (key !== process.env.SUPABASE_SERVICE_ROLE_KEY) {
    return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  }
  
  const DEEPSEEK_KEY = process.env.DEEPSEEK_API_KEY || "";
  if (!DEEPSEEK_KEY) {
    return NextResponse.json({ error: "DEEPSEEK_API_KEY not set" }, { status: 500 });
  }

  const res = await fetch("https://api.deepseek.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${DEEPSEEK_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "deepseek-chat",
      messages: [
        {
          role: "system",
          content:
            "Eres el Gerente AI de Rutmy, plataforma de movilidad premium. Responde breve, profesional y en español.",
        },
        { role: "user", content: body.mensaje || "Hola" },
      ],
      max_tokens: 300,
      temperature: 0.7,
    }),
  });

  const data = await res.json();
  return NextResponse.json({
    respuesta: data.choices?.[0]?.message?.content || "Sin respuesta",
    provider: "deepseek",
  });
}
