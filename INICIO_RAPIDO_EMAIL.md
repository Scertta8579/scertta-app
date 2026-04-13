# 🚀 Inicio Rápido - Email de Bienvenida

## ⚡ 3 Pasos para Activar

### Paso 1: Desplegar la Edge Function (5 minutos)

**Opción A: Usando Supabase CLI (Recomendado)**

```bash
# Instalar CLI (si no lo tienes)
npm install -g supabase

# Login
supabase login

# Link al proyecto
supabase link --project-ref tu-project-ref

# Desplegar
cd supabase/functions
supabase functions deploy enviar-bienvenida
```

**Opción B: Usando Dashboard**

1. Ve a [Supabase Dashboard](https://app.supabase.com)
2. Selecciona tu proyecto
3. Ve a **Edge Functions** → **Create Function**
4. Nombre: `enviar-bienvenida`
5. Copia el contenido de `supabase/functions/enviar-bienvenida/index.ts`
6. Click en **Deploy**

### Paso 2: Probar la Función (2 minutos)

```bash
# Obtener tu ANON_KEY desde Supabase Dashboard → Settings → API

# Probar
curl -X POST https://tu-proyecto.supabase.co/functions/v1/enviar-bienvenida \
  -H "Authorization: Bearer TU_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "tu-email@ejemplo.com",
    "nombre": "Tu Nombre"
  }'
```

**Resultado esperado:**
```json
{
  "success": true,
  "message": "Correo de bienvenida enviado exitosamente"
}
```

**Verifica tu email** - Deberías recibir un correo elegante con los colores de Scertta.

### Paso 3: Integrar en tu Código (3 minutos)

**En tu página de registro:**

```typescript
import { enviarCorreoBienvenida } from "@/lib/emailService";

async function handleRegistro() {
  // 1. Registrar usuario
  const { data } = await supabase.auth.signUp({ email, password });
  
  // 2. Crear perfil
  await supabase.from("perfiles").insert({
    id: data.user?.id,
    email,
    nombre,
    rol: "solicitante",
  });
  
  // 3. Enviar email de bienvenida
  await enviarCorreoBienvenida(email, nombre);
  
  alert("¡Registro exitoso! Revisa tu correo.");
}
```

## 🎨 Previsualización del Email

```
┌─────────────────────────────────────────┐
│                                         │
│         🔵 Scertta (Azul #0b4bb3)       │
│           Movilidad Premium             │
│                                         │
├─────────────────────────────────────────┤
│                                         │
│  ¡Bienvenido, [Nombre]! 👋             │
│                                         │
│  Estamos encantados de tenerte en       │
│  Scertta, tu plataforma de movilidad    │
│  premium.                               │
│                                         │
│  ┌───────────────────────────────────┐ │
│  │ ¿Qué puedes hacer ahora?          │ │
│  │                                   │ │
│  │ ✓ Solicitar viajes premium        │ │
│  │ ✓ Acceder a promociones           │ │
│  │ ✓ Gestionar tu perfil             │ │
│  │ ✓ Atención personalizada          │ │
│  └───────────────────────────────────┘ │
│                                         │
│     [ Comenzar Ahora ] (Botón azul)    │
│                                         │
├─────────────────────────────────────────┤
│  © 2024 Scertta                        │
│  Buenos Aires, Argentina                │
└─────────────────────────────────────────┘
```

## 📊 Ver Resultados

### Ver Logs de la Función

```bash
# Logs en tiempo real
supabase functions logs enviar-bienvenida --tail

# Logs históricos
supabase functions logs enviar-bienvenida --limit 50
```

### Dashboard de Resend

Ve a https://resend.com/emails para ver:
- ✅ Emails enviados
- ✅ Tasa de entrega
- ✅ Tasa de apertura
- ✅ Bounces

## 🔧 Personalización Rápida

### Cambiar el Remitente

Cuando tengas tu dominio verificado:

1. Edita `supabase/functions/enviar-bienvenida/index.ts`
2. Busca:
```typescript
from: "Scertta <onboarding@resend.dev>",
```
3. Cambia a:
```typescript
from: "Scertta <hola@tudominio.com>",
```
4. Redesplegar:
```bash
supabase functions deploy enviar-bienvenida
```

### Cambiar Colores

Busca en `index.ts` y modifica:
```typescript
// Color principal
background: linear-gradient(135deg, #0b4bb3 0%, #0a3d8f 100%);

// Cambiar a tu color
background: linear-gradient(135deg, #TU_COLOR 0%, #TU_COLOR_OSCURO 100%);
```

### Cambiar Contenido

Modifica la variable `htmlContent` en `index.ts`:
```typescript
<h2>¡Bienvenido, ${nombre}! 👋</h2>
<p>Tu mensaje personalizado aquí...</p>
```

## 🧪 Testing Completo

### Test 1: Función Local

```bash
# Terminal 1
supabase functions serve enviar-bienvenida

# Terminal 2
curl -X POST http://localhost:54321/functions/v1/enviar-bienvenida \
  -H "Content-Type: application/json" \
  -d '{"email": "test@ejemplo.com", "nombre": "Test"}'
```

### Test 2: Función en Producción

```bash
curl -X POST https://tu-proyecto.supabase.co/functions/v1/enviar-bienvenida \
  -H "Authorization: Bearer TU_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"email": "tu-email@ejemplo.com", "nombre": "Tu Nombre"}'
```

### Test 3: Desde el Frontend

```typescript
// Crear archivo: test-email.ts
import { enviarCorreoBienvenida } from "./lib/emailService";

async function test() {
  const resultado = await enviarCorreoBienvenida(
    "tu-email@ejemplo.com",
    "Tu Nombre"
  );
  console.log(resultado);
}

test();
```

```bash
# Ejecutar
npx tsx test-email.ts
```

## ✅ Checklist de Verificación

- [ ] Edge Function desplegada
- [ ] Probado con curl (recibiste el email)
- [ ] Integrado en código de registro
- [ ] Email llega correctamente (no en spam)
- [ ] Diseño se ve bien en móvil
- [ ] Diseño se ve bien en Gmail
- [ ] Diseño se ve bien en Outlook
- [ ] Logs monitoreados

## 🐛 Solución Rápida de Problemas

### Email no llega
1. Verifica spam
2. Verifica logs: `supabase functions logs enviar-bienvenida`
3. Verifica en Resend Dashboard

### Error 401
- Verifica que la API Key sea correcta
- Verifica que no haya espacios extra

### Error 400
- Verifica que envíes `email` y `nombre` en el body
- Verifica que sean strings válidos

### Función no responde
- Verifica que esté desplegada: `supabase functions list`
- Verifica la URL del endpoint

## 📚 Documentación Completa

- **README de la función**: `supabase/functions/enviar-bienvenida/README.md`
- **Guía de integración**: `docs/INTEGRACION_EMAIL_BIENVENIDA.md`
- **Resumen completo**: `RESUMEN_EMAIL_BIENVENIDA.md`

## 🎉 ¡Listo!

En menos de 10 minutos tienes un sistema profesional de emails de bienvenida.

### Próximos Pasos

1. **Verificar dominio** en Resend (opcional)
2. **Mover API Key a secrets** (recomendado para producción)
3. **Agregar más templates** (ej: recuperación de contraseña)
4. **Implementar rate limiting** (opcional)

---

**¡Emails de bienvenida elegantes en minutos!** 📧⚡
