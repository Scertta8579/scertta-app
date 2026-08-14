// POST /api/kyc/upload — Subir un documento para verificación
import { NextRequest, NextResponse } from "next/server";
import { createServerClient } from "@supabase/ssr";

export async function POST(req: NextRequest) {
  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() { return req.cookies.getAll(); },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) => req.cookies.set(name, value));
        },
      },
    }
  );
  const { data: { session } } = await supabase.auth.getSession();
  if (!session) return NextResponse.json({ error: "No autorizado" }, { status: 401 });

  const form = await req.formData();
  const tipo = form.get("tipo_documento") as string;
  const archivo = form.get("archivo") as File;

  if (!tipo || !archivo) {
    return NextResponse.json({ error: "tipo_documento y archivo requeridos" }, { status: 400 });
  }

  const tiposValidos = ["dni_frente","dni_dorso","licencia_frente","licencia_dorso","cedula_vehiculo","vtv_rto","seguro"];
  if (!tiposValidos.includes(tipo)) {
    return NextResponse.json({ error: "Tipo de documento inválido" }, { status: 400 });
  }

  const conductorId = session.user.id;
  const fileName = `${conductorId}/${tipo}-${Date.now()}.${archivo.name.split(".").pop()}`;

  // Subir a Supabase Storage
  const { data: upload, error: uploadErr } = await supabase.storage
    .from("documentos-conductores")
    .upload(fileName, archivo, { upsert: true });

  if (uploadErr) {
    return NextResponse.json({ error: "Error al subir archivo" }, { status: 500 });
  }

  const { data: urlData } = supabase.storage.from("documentos-conductores").getPublicUrl(fileName);

  // Upsert en conductor_documentos
  const { data: doc, error: docErr } = await supabase
    .from("conductor_documentos")
    .upsert({
      conductor_id: conductorId,
      tipo_documento: tipo,
      archivo_url: urlData.publicUrl,
      estado: "pendiente",
      fecha_subida: new Date().toISOString(),
    }, { onConflict: "conductor_id,tipo_documento" });

  if (docErr) {
    return NextResponse.json({ error: "Error al registrar documento" }, { status: 500 });
  }

  // Enviar a Gemma 4 para análisis (o a cola manual si no responde)
  try {
    const gemmaResp = await fetch("http://192.168.0.4:8003/kyc/analyze", {
      method: "POST",
      body: JSON.stringify({ tipo_documento: tipo, archivo_url: urlData.publicUrl }),
      headers: { "Content-Type": "application/json" },
      signal: AbortSignal.timeout(10000),
    });

    if (gemmaResp.ok) {
      const gemmaData = await gemmaResp.json();
      await supabase.from("conductor_documentos").update({
        score_ia: gemmaData.score,
        observaciones_ia: gemmaData.observaciones,
        fecha_procesado_ia: new Date().toISOString(),
        estado: gemmaData.score >= 90 ? "aprobado" : "en_proceso",
      }).eq("conductor_id", conductorId).eq("tipo_documento", tipo);
    } else {
      throw new Error("Gemma 4 no disponible");
    }
  } catch {
    // Gemma 4 caída → cola manual
    await supabase.from("cola_aprobacion_manual").insert({
      conductor_id: conductorId,
      tipo_documento: tipo,
      archivo_url: urlData.publicUrl,
      prioridad: 0,
    });
  }

  return NextResponse.json({ success: true, tipo_documento: tipo });
}
