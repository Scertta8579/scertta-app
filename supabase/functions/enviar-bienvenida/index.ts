import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { Resend } from 'npm:resend'

const resend = new Resend('re_W2phdeDF_KQwrnGJRZEipcfvPMv67qRYq')

serve(async (req) => {
  try {
    const { email, nombre } = await req.json()

    const data = await resend.emails.send({
      from: 'Scertta <onboarding@resend.dev>',
      to: [email],
      subject: '¡Bienvenido a Scertta!',
      html: `
        <div style="font-family: sans-serif; padding: 20px; color: #333;">
          <h1 style="color: #007bff;">¡Hola, ${nombre}!</h1>
          <p style="font-size: 16px;">Gracias por unirte a <strong>Scertta</strong>. Estamos felices de tenerte con nosotros.</p>
          <p>Pronto recibirás más novedades sobre el lanzamiento en tu zona.</p>
          <hr style="border: 0; border-top: 1px solid #eee; margin: 20px 0;">
          <p style="font-size: 12px; color: #777;">Este es un mensaje automático de bienvenida.</p>
        </div>
      `,
    })

    return new Response(JSON.stringify(data), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})