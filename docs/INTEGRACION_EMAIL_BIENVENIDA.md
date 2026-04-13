# 📧 Integración de Email de Bienvenida

## 📋 Descripción

Guía completa para integrar el correo de bienvenida automático en el flujo de registro de usuarios de Scertta.

## 🏗️ Arquitectura

```
Usuario se registra
    ↓
Supabase Auth crea usuario
    ↓
Se crea perfil en tabla perfiles
    ↓
Edge Function envía correo de bienvenida
    ↓
Usuario recibe email elegante
```

## 📁 Archivos Creados

1. **`supabase/functions/enviar-bienvenida/index.ts`** - Edge Function principal
2. **`supabase/functions/enviar-bienvenida/deno.json`** - Configuración de Deno
3. **`supabase/functions/enviar-bienvenida/test.json`** - Datos de prueba
4. **`supabase/functions/enviar-bienvenida/README.md`** - Documentación
5. **`lib/emailService.ts`** - Servicio de email para el frontend

## 🚀 Despliegue

### Paso 1: Desplegar la Edge Function

**Opción A: Usando Supabase CLI**

```bash
# Instalar Supabase CLI
npm install -g supabase

# Login
supabase login

# Link al proyecto
supabase link --project-ref tu-project-ref

# Desplegar
supabase functions deploy enviar-bienvenida
```

**Opción B: Usando Dashboard**

1. Ve a [Supabase Dashboard](https://app.supabase.com)
2. Selecciona tu proyecto
3. Ve a **Edge Functions** → **Create Function**
4. Nombre: `enviar-bienvenida`
5. Copia el contenido de `index.ts`
6. Click en **Deploy**

### Paso 2: Verificar el Despliegue

```bash
# Ver logs
supabase functions logs enviar-bienvenida

# Probar la función
curl -X POST https://tu-proyecto.supabase.co/functions/v1/enviar-bienvenida \
  -H "Authorization: Bearer TU_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"email": "test@ejemplo.com", "nombre": "Test User"}'
```

## 💻 Integración en el Código

### Ejemplo 1: En Página de Registro (Básico)

```typescript
// app/registro/page.tsx
"use client";

import { useState } from "react";
import { supabase } from "@/lib/supabaseClient";
import { enviarCorreoBienvenida } from "@/lib/emailService";

export default function RegistroPage() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [nombre, setNombre] = useState("");
  const [cargando, setCargando] = useState(false);

  const handleRegistro = async (e: React.FormEvent) => {
    e.preventDefault();
    setCargando(true);

    try {
      // 1. Crear usuario en Supabase Auth
      const { data: authData, error: authError } = await supabase.auth.signUp({
        email,
        password,
      });

      if (authError) throw authError;

      // 2. Crear perfil
      const { error: profileError } = await supabase.from("perfiles").insert({
        id: authData.user?.id,
        email,
        nombre,
        rol: "solicitante",
      });

      if (profileError) throw profileError;

      // 3. Enviar correo de bienvenida
      const resultado = await enviarCorreoBienvenida(email, nombre);

      if (resultado.success) {
        alert("¡Registro exitoso! Revisa tu correo.");
      } else {
        console.warn("Usuario registrado pero email no enviado:", resultado.error);
      }
    } catch (error: any) {
      console.error("Error en registro:", error);
      alert("Error al registrar: " + error.message);
    } finally {
      setCargando(false);
    }
  };

  return (
    <form onSubmit={handleRegistro}>
      <input
        type="text"
        placeholder="Nombre"
        value={nombre}
        onChange={(e) => setNombre(e.target.value)}
        required
      />
      <input
        type="email"
        placeholder="Email"
        value={email}
        onChange={(e) => setEmail(e.target.value)}
        required
      />
      <input
        type="password"
        placeholder="Contraseña"
        value={password}
        onChange={(e) => setPassword(e.target.value)}
        required
      />
      <button type="submit" disabled={cargando}>
        {cargando ? "Registrando..." : "Registrarse"}
      </button>
    </form>
  );
}
```

### Ejemplo 2: Con Hook Personalizado

```typescript
// app/registro/page.tsx
"use client";

import { useState } from "react";
import { supabase } from "@/lib/supabaseClient";
import { useEnviarBienvenida } from "@/lib/emailService";

export default function RegistroPage() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [nombre, setNombre] = useState("");
  const [cargando, setCargando] = useState(false);
  
  const { enviarBienvenida, cargando: enviandoEmail } = useEnviarBienvenida();

  const handleRegistro = async (e: React.FormEvent) => {
    e.preventDefault();
    setCargando(true);

    try {
      // Registro de usuario
      const { data: authData, error: authError } = await supabase.auth.signUp({
        email,
        password,
      });

      if (authError) throw authError;

      // Crear perfil
      await supabase.from("perfiles").insert({
        id: authData.user?.id,
        email,
        nombre,
        rol: "solicitante",
      });

      // Enviar email (no bloqueante)
      enviarBienvenida(email, nombre);

      alert("¡Registro exitoso!");
    } catch (error: any) {
      alert("Error: " + error.message);
    } finally {
      setCargando(false);
    }
  };

  return (
    <form onSubmit={handleRegistro}>
      {/* ... campos del formulario ... */}
      <button type="submit" disabled={cargando || enviandoEmail}>
        {cargando ? "Registrando..." : "Registrarse"}
      </button>
    </form>
  );
}
```

### Ejemplo 3: Con Database Trigger (Automático)

Para enviar el email automáticamente cuando se crea un perfil:

```sql
-- Crear función que se ejecuta al insertar en perfiles
CREATE OR REPLACE FUNCTION enviar_email_bienvenida_trigger()
RETURNS TRIGGER AS $$
BEGIN
  -- Llamar a la Edge Function usando pg_net
  PERFORM
    net.http_post(
      url := 'https://tu-proyecto.supabase.co/functions/v1/enviar-bienvenida',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key')
      ),
      body := jsonb_build_object(
        'email', NEW.email,
        'nombre', NEW.nombre
      )
    );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Crear trigger
CREATE TRIGGER after_perfil_insert
  AFTER INSERT ON perfiles
  FOR EACH ROW
  EXECUTE FUNCTION enviar_email_bienvenida_trigger();
```

## 🎨 Personalización del Email

### Cambiar Colores

En `index.ts`, busca y modifica:

```typescript
// Color principal
background: linear-gradient(135deg, #0b4bb3 0%, #0a3d8f 100%);

// Color de botones
background-color: #0b4bb3;
```

### Cambiar Contenido

Modifica la variable `htmlContent` en `index.ts`:

```typescript
const htmlContent = `
  <!-- Tu HTML personalizado aquí -->
`;
```

### Agregar Más Información

```typescript
// En el body del request, agregar más campos
interface RequestBody {
  email: string;
  nombre: string;
  telefono?: string;  // Opcional
  ciudad?: string;    // Opcional
}

// Usar en el HTML
<p>Teléfono: ${telefono || 'No proporcionado'}</p>
```

## 🔐 Seguridad

### Mover API Key a Secrets

```bash
# Crear secret en Supabase
supabase secrets set RESEND_API_KEY=re_W2phdeDF_KQwrnGJRZEipcfvPMv87qRYq

# Actualizar index.ts
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY");
```

### Validar Autenticación

```typescript
// En index.ts, agregar al inicio
const authHeader = req.headers.get("Authorization");
if (!authHeader) {
  return new Response(
    JSON.stringify({ error: "No autorizado" }),
    { status: 401, headers: corsHeaders }
  );
}

// Validar token
const token = authHeader.replace("Bearer ", "");
const { data: { user }, error } = await supabaseClient.auth.getUser(token);

if (error || !user) {
  return new Response(
    JSON.stringify({ error: "Token inválido" }),
    { status: 401, headers: corsHeaders }
  );
}
```

### Rate Limiting

```typescript
// Limitar envíos por usuario
const RATE_LIMIT = 3; // 3 emails por hora
const userKey = `email_sent:${email}`;

// Verificar límite (usando Redis o similar)
const count = await redis.incr(userKey);
if (count > RATE_LIMIT) {
  return new Response(
    JSON.stringify({ error: "Límite de envíos excedido" }),
    { status: 429, headers: corsHeaders }
  );
}

await redis.expire(userKey, 3600); // 1 hora
```

## 🧪 Testing

### Probar Localmente

```bash
# Terminal 1: Servir la función
supabase functions serve enviar-bienvenida

# Terminal 2: Hacer request
curl -X POST http://localhost:54321/functions/v1/enviar-bienvenida \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@ejemplo.com",
    "nombre": "Test User"
  }'
```

### Probar en Producción

```typescript
// test-email.ts
import { enviarCorreoBienvenida } from "./lib/emailService";

async function test() {
  const resultado = await enviarCorreoBienvenida(
    "tu-email@ejemplo.com",
    "Tu Nombre"
  );
  
  console.log("Resultado:", resultado);
}

test();
```

```bash
# Ejecutar
npx tsx test-email.ts
```

## 📊 Monitoreo

### Ver Logs en Supabase

```bash
# Logs en tiempo real
supabase functions logs enviar-bienvenida --tail

# Logs históricos
supabase functions logs enviar-bienvenida --limit 100
```

### Dashboard de Resend

Monitorea tus envíos en:
- https://resend.com/emails
- Ver tasa de entrega
- Ver tasa de apertura
- Ver bounces y quejas

## 🔄 Actualizar Remitente

Cuando tengas tu dominio verificado:

1. **Verificar dominio en Resend**:
   - Ve a https://resend.com/domains
   - Agrega tu dominio
   - Configura registros DNS
   - Espera verificación

2. **Actualizar código**:
```typescript
from: "Scertta <hola@tudominio.com>",
```

3. **Redesplegar**:
```bash
supabase functions deploy enviar-bienvenida
```

## 🐛 Troubleshooting

### Email no llega

1. **Verificar spam**: El email puede estar en spam
2. **Verificar logs**: `supabase functions logs enviar-bienvenida`
3. **Verificar Resend**: Revisar dashboard de Resend
4. **Verificar email**: Asegurarse que el email sea válido

### Error 401

- Verificar que la API Key sea correcta
- Verificar que no haya espacios extra
- Verificar que el secret esté configurado

### Error CORS

- Verificar headers CORS en la función
- Asegurarse de manejar OPTIONS requests

### Función no responde

- Verificar que esté desplegada: `supabase functions list`
- Verificar logs: `supabase functions logs enviar-bienvenida`
- Verificar URL: debe ser `/functions/v1/enviar-bienvenida`

## 📚 Recursos

- [Resend API](https://resend.com/docs)
- [Supabase Edge Functions](https://supabase.com/docs/guides/functions)
- [Deno Deploy](https://deno.com/deploy)
- [Email HTML Best Practices](https://www.campaignmonitor.com/dev-resources/guides/coding/)

## 🎉 ¡Listo!

Tu sistema de correos de bienvenida está completamente configurado y listo para usar.

### Checklist Final

- [ ] Edge Function desplegada
- [ ] API Key configurada
- [ ] Servicio de email integrado en el código
- [ ] Probado con email real
- [ ] Logs monitoreados
- [ ] Dominio verificado (opcional)
- [ ] Rate limiting configurado (opcional)

---

**¡Bienvenida automática y elegante para todos tus usuarios!** 📧✨
