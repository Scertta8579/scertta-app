# 🔑 Configurar Service Role Key

## ⚠️ Importante

He integrado la llamada a la Edge Function en tu página de registro. Para que funcione correctamente con el `service_role` (y evitar errores de permisos), necesitas configurar la variable de entorno.

## 📝 Pasos para Configurar

### 1. Obtener el Service Role Key

1. Ve a [https://app.supabase.com](https://app.supabase.com)
2. Selecciona tu proyecto
3. Ve a **Settings** (⚙️) → **API**
4. Busca la sección **Project API keys**
5. Copia el **service_role** key (NO el anon public)

⚠️ **ADVERTENCIA**: El service_role key tiene permisos completos. NUNCA lo expongas en el frontend en producción.

### 2. Agregar a .env.local

Abre el archivo `.env.local` y agrega:

```env
NEXT_PUBLIC_SUPABASE_SERVICE_ROLE_KEY=tu_service_role_key_aqui
```

**Ejemplo completo de .env.local:**
```env
NEXT_PUBLIC_SUPABASE_URL=https://cmuhwyxmluhnlzcasceq.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=tu_anon_key
NEXT_PUBLIC_SUPABASE_SERVICE_ROLE_KEY=tu_service_role_key
NEXT_PUBLIC_MAPBOX_ACCESS_TOKEN=tu_mapbox_token
```

### 3. Reiniciar el Servidor de Desarrollo

```bash
# Detener el servidor (Ctrl+C)
# Iniciar nuevamente
npm run dev
```

## 🔐 Alternativa Más Segura (Recomendada para Producción)

En lugar de usar el service_role en el frontend, crea una API Route en Next.js:

### Crear API Route

```typescript
// app/api/enviar-bienvenida/route.ts
import { NextRequest, NextResponse } from 'next/server';

export async function POST(request: NextRequest) {
  try {
    const { email, nombre } = await request.json();

    const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY; // Sin NEXT_PUBLIC_

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

    const data = await response.json();
    return NextResponse.json(data);
  } catch (error: any) {
    return NextResponse.json(
      { error: error.message },
      { status: 500 }
    );
  }
}
```

### Actualizar .env.local (sin NEXT_PUBLIC_)

```env
SUPABASE_SERVICE_ROLE_KEY=tu_service_role_key
```

### Llamar desde el Frontend

```typescript
// En app/solicitante/registro/page.tsx
try {
  await fetch('/api/enviar-bienvenida', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      email: email,
      nombre: `${nombre} ${apellido}`
    })
  });
} catch (emailError) {
  console.error('Error al enviar email:', emailError);
}
```

## ✅ Verificar que Funciona

1. **Registra un usuario de prueba**
2. **Verifica el código OTP**
3. **Revisa tu email** - Deberías recibir el correo de bienvenida
4. **Revisa los logs** en Supabase Dashboard → Edge Functions → enviar-bienvenida

## 🐛 Troubleshooting

### Email no llega
- Verifica que la Edge Function esté desplegada
- Verifica los logs en Supabase Dashboard
- Verifica la carpeta de spam

### Error 401 (Unauthorized)
- Verifica que el service_role_key sea correcto
- Verifica que no haya espacios extra
- Reinicia el servidor de desarrollo

### Error 500
- Revisa los logs de la Edge Function
- Verifica que la API Key de Resend sea correcta

## 📚 Documentación

- **Integración completa**: `docs/INTEGRACION_EMAIL_BIENVENIDA.md`
- **Desplegar función**: `DESPLEGAR_FUNCION_DASHBOARD.md`

---

**¡Configura el service_role_key y el email de bienvenida funcionará automáticamente!** 🔑📧
