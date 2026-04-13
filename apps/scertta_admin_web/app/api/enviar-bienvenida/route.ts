import { NextRequest, NextResponse } from 'next/server';

export async function POST(request: NextRequest) {
  try {
    const { email, nombre } = await request.json();

    if (!email || !nombre) {
      return NextResponse.json(
        { error: 'Email y nombre son requeridos' },
        { status: 400 }
      );
    }

    const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

    if (!serviceRoleKey) {
      console.error('SUPABASE_SERVICE_ROLE_KEY no está configurado');
      return NextResponse.json(
        { error: 'Configuración del servidor incompleta' },
        { status: 500 }
      );
    }

    const response = await fetch(
      'https://cmuhwyxmluhnlzcasceq.supabase.co/functions/v1/enviar-bienvenida',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${serviceRoleKey}`
        },
        body: JSON.stringify({ email, nombre })
      }
    );

    if (!response.ok) {
      const errorData = await response.text();
      console.error('Error de la Edge Function:', errorData);
      return NextResponse.json(
        { error: 'Error al enviar el correo', details: errorData },
        { status: response.status }
      );
    }

    const data = await response.json();
    
    return NextResponse.json({
      success: true,
      message: 'Correo de bienvenida enviado',
      data
    });
  } catch (error: any) {
    console.error('Error en API route:', error);
    return NextResponse.json(
      { error: 'Error interno del servidor', details: error.message },
      { status: 500 }
    );
  }
}
