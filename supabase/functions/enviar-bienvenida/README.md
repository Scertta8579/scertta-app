# Edge Function: Enviar Bienvenida

## 📧 Descripción

Esta Edge Function envía un correo de bienvenida elegante y personalizado a los nuevos usuarios de Scertta utilizando la API de Resend.

## 🎨 Características

- ✅ Diseño HTML responsive y elegante
- ✅ Colores de marca Scertta (#0b4bb3)
- ✅ Personalización con nombre del usuario
- ✅ Lista de características disponibles
- ✅ Botón de llamada a la acción
- ✅ Footer con información de la empresa
- ✅ Manejo de errores robusto
- ✅ CORS habilitado

## 🚀 Desplegar la Función

### Opción 1: Usando Supabase CLI

```bash
# Instalar Supabase CLI (si no lo tienes)
npm install -g supabase

# Login en Supabase
supabase login

# Link al proyecto
supabase link --project-ref tu-project-ref

# Desplegar la función
supabase functions deploy enviar-bienvenida
```

### Opción 2: Usando el Dashboard de Supabase

1. Ve a tu proyecto en [Supabase Dashboard](https://app.supabase.com)
2. Navega a **Edge Functions** en el menú lateral
3. Haz clic en **Create Function**
4. Nombre: `enviar-bienvenida`
5. Copia y pega el contenido de `index.ts`
6. Haz clic en **Deploy**

## 🔑 Configurar Variables de Entorno (Opcional)

Para mayor seguridad, puedes mover la API Key a variables de entorno:

```bash
# Crear secret
supabase secrets set RESEND_API_KEY=re_W2phdeDF_KQwrnGJRZEipcfvPMv87qRYq

# Actualizar el código para usar:
# const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY");
```

## 📝 Uso

### Desde el Frontend (JavaScript/TypeScript)

```typescript
import { supabase } from "@/lib/supabaseClient";

async function enviarBienvenida(email: string, nombre: string) {
  const { data, error } = await supabase.functions.invoke("enviar-bienvenida", {
    body: {
      email,
      nombre,
    },
  });

  if (error) {
    console.error("Error:", error);
    return;
  }

  console.log("Correo enviado:", data);
}

// Ejemplo de uso
await enviarBienvenida("usuario@ejemplo.com", "Juan Pérez");
```

### Desde cURL

```bash
curl -X POST https://tu-proyecto.supabase.co/functions/v1/enviar-bienvenida \
  -H "Authorization: Bearer TU_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "usuario@ejemplo.com",
    "nombre": "Juan Pérez"
  }'
```

### Probar Localmente

```bash
# Servir la función localmente
supabase functions serve enviar-bienvenida

# En otra terminal, hacer una petición de prueba
curl -X POST http://localhost:54321/functions/v1/enviar-bienvenida \
  -H "Content-Type: application/json" \
  -d @test.json
```

## 📋 Request Body

```typescript
{
  email: string;    // Email del destinatario (requerido)
  nombre: string;   // Nombre del usuario (requerido)
}
```

## 📤 Response

### Éxito (200)
```json
{
  "success": true,
  "message": "Correo de bienvenida enviado exitosamente",
  "data": {
    "id": "email-id-from-resend"
  }
}
```

### Error (400)
```json
{
  "error": "Email y nombre son requeridos"
}
```

### Error (500)
```json
{
  "error": "Error al enviar el correo",
  "details": "..."
}
```

## 🎨 Personalización del Diseño

El correo incluye:

1. **Header**: Logo Scertta con gradiente azul
2. **Saludo personalizado**: Con el nombre del usuario
3. **Mensaje de bienvenida**: Texto amigable
4. **Tarjeta de características**: Lista de beneficios
5. **Botón CTA**: "Comenzar Ahora"
6. **Footer**: Información de la empresa

### Colores Utilizados

- **Azul Scertta**: `#0b4bb3`
- **Azul Oscuro**: `#0a3d8f`
- **Gris Apple**: `#8e8e93`
- **Fondo**: `#f5f5f7`

## 🔧 Integración con Registro de Usuarios

### Ejemplo: Trigger después del registro

```typescript
// En tu página de registro
async function handleRegistro(email: string, password: string, nombre: string) {
  // 1. Crear usuario en Supabase Auth
  const { data: authData, error: authError } = await supabase.auth.signUp({
    email,
    password,
  });

  if (authError) {
    console.error("Error al registrar:", authError);
    return;
  }

  // 2. Crear perfil en la tabla perfiles
  const { error: profileError } = await supabase.from("perfiles").insert({
    id: authData.user?.id,
    email,
    nombre,
    rol: "solicitante",
  });

  if (profileError) {
    console.error("Error al crear perfil:", profileError);
    return;
  }

  // 3. Enviar correo de bienvenida
  await supabase.functions.invoke("enviar-bienvenida", {
    body: { email, nombre },
  });

  console.log("¡Usuario registrado y correo enviado!");
}
```

## 🔐 Seguridad

### Recomendaciones:

1. **Mover API Key a Secrets**: No dejar la API key hardcodeada en producción
2. **Validar Email**: Agregar validación de formato de email
3. **Rate Limiting**: Implementar límites de envío por usuario
4. **Verificar Autenticación**: Validar que el usuario esté autenticado

### Ejemplo con Validación de Auth:

```typescript
// En index.ts, agregar al inicio:
const authHeader = req.headers.get("Authorization");
if (!authHeader) {
  return new Response(
    JSON.stringify({ error: "No autorizado" }),
    { status: 401, headers: corsHeaders }
  );
}
```

## 📊 Monitoreo

### Ver Logs

```bash
# Ver logs en tiempo real
supabase functions logs enviar-bienvenida --tail

# Ver logs históricos
supabase functions logs enviar-bienvenida
```

### Dashboard de Resend

Puedes ver estadísticas de envío en:
https://resend.com/emails

## 🔄 Actualizar el Remitente

Cuando tengas tu dominio verificado en Resend:

1. Verifica tu dominio en Resend Dashboard
2. Actualiza la línea en `index.ts`:

```typescript
from: "Scertta <hola@tudominio.com>",
```

## 🐛 Troubleshooting

### Error: "Invalid API Key"
- Verifica que la API Key sea correcta
- Asegúrate de que no haya espacios extra

### Error: "Email not sent"
- Verifica que el email sea válido
- Revisa los logs de Resend

### Error: "CORS"
- Verifica que los headers CORS estén configurados
- Asegúrate de manejar OPTIONS requests

## 📚 Referencias

- [Resend API Docs](https://resend.com/docs)
- [Supabase Edge Functions](https://supabase.com/docs/guides/functions)
- [Deno Deploy](https://deno.com/deploy)

## 🎉 ¡Listo!

Tu función está lista para enviar correos de bienvenida elegantes y personalizados a tus usuarios.
