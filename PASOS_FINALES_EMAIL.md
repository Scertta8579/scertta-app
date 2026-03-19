# ✅ Pasos Finales para Activar el Email de Bienvenida

## 🎯 Resumen de lo Implementado

He actualizado tu código de registro para que automáticamente envíe un email de bienvenida cuando un usuario complete el registro exitosamente.

### ✅ Cambios Realizados

1. **Edge Function creada**: `supabase/functions/enviar-bienvenida/index.ts`
2. **API Route creada**: `app/api/enviar-bienvenida/route.ts` (más segura)
3. **Registro actualizado**: `app/solicitante/registro/page.tsx` (integración completa)
4. **Ejemplo de .env**: `.env.example` (variables necesarias)

## 🚀 Pasos para Activar (10 minutos)

### Paso 1: Desplegar la Edge Function (5 min)

**Opción A: Usando Dashboard (Más Fácil)**

1. Ve a [https://app.supabase.com](https://app.supabase.com)
2. Selecciona tu proyecto
3. Click en **Edge Functions** → **Create Function**
4. Nombre: `enviar-bienvenida`
5. Copia el contenido de: `supabase\functions\enviar-bienvenida\index.ts`
6. Pégalo en el editor
7. Click en **Deploy**

**Opción B: Usando CLI (si tienes Scoop instalado)**

```powershell
# Instalar Supabase CLI con Scoop
scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
scoop install supabase

# Desplegar
supabase login
supabase link --project-ref cmuhwyxmluhnlzcasceq
cd supabase\functions
supabase functions deploy enviar-bienvenida
```

### Paso 2: Configurar Service Role Key (2 min)

1. Ve a [https://app.supabase.com](https://app.supabase.com)
2. Selecciona tu proyecto
3. Ve a **Settings** → **API**
4. Copia el **service_role** key
5. Abre tu archivo `.env.local`
6. Agrega esta línea:

```env
SUPABASE_SERVICE_ROLE_KEY=tu_service_role_key_aqui
```

⚠️ **IMPORTANTE**: Es `SUPABASE_SERVICE_ROLE_KEY` (sin `NEXT_PUBLIC_`) para que solo esté disponible en el servidor.

### Paso 3: Reiniciar el Servidor (1 min)

```bash
# Detener el servidor (Ctrl+C en la terminal)
# Iniciar nuevamente
npm run dev
```

### Paso 4: Probar el Registro (2 min)

1. Ve a `http://localhost:3000/solicitante/registro`
2. Completa el formulario con tus datos reales
3. Ingresa el código OTP que recibes
4. **¡Deberías recibir el email de bienvenida!**

## 🔍 Verificar que Funciona

### Checklist

- [ ] Edge Function desplegada en Supabase
- [ ] Service Role Key configurado en `.env.local`
- [ ] Servidor de desarrollo reiniciado
- [ ] Usuario de prueba registrado
- [ ] Email de bienvenida recibido

### Ver Logs

**En Supabase Dashboard:**
1. Ve a **Edge Functions** → `enviar-bienvenida`
2. Click en la pestaña **Logs**
3. Verás cada llamada a la función

**En tu consola del navegador:**
- Abre DevTools (F12)
- Ve a la pestaña **Console**
- Busca mensajes de error si algo falla

## 🔄 Flujo Completo

```
1. Usuario completa formulario de registro
   ↓
2. Click en "Registrarme"
   ↓
3. Supabase envía código OTP al email
   ↓
4. Usuario ingresa código OTP
   ↓
5. Click en "Confirmar y Entrar"
   ↓
6. Se verifica el OTP
   ↓
7. Se crea el perfil en tabla 'perfiles'
   ↓
8. Se llama a /api/enviar-bienvenida
   ↓
9. API Route llama a Edge Function con service_role
   ↓
10. Edge Function envía email con Resend
   ↓
11. Usuario recibe email de bienvenida
   ↓
12. Redirección a /solicitante/mapa
```

## 📧 Contenido del Email

El usuario recibirá un email simple con:
- **De**: Scertta <onboarding@resend.dev>
- **Asunto**: ¡Bienvenido a Scertta!
- **Contenido**: "Hola [Nombre Apellido], bienvenido a bordo."

## 🎨 Mejorar el Diseño (Opcional)

Si quieres un email más elegante, puedes usar el código HTML que creé anteriormente. Está en los archivos de documentación con diseño completo, colores de marca, etc.

## 🔐 Seguridad

### ✅ Implementación Segura (Actual)

- Service Role Key está en el servidor (API Route)
- No se expone en el frontend
- Solo se usa para llamar a la Edge Function

### ⚠️ NO Hacer

- NO pongas el service_role_key con `NEXT_PUBLIC_` (se expondría al frontend)
- NO compartas el service_role_key públicamente
- NO lo subas a Git (asegúrate de que `.env.local` esté en `.gitignore`)

## 🐛 Solución Rápida de Problemas

### Email no llega

```powershell
# 1. Verificar que la función esté desplegada
# En Dashboard: Edge Functions → Buscar "enviar-bienvenida"

# 2. Probar la función directamente
.\test-email-function.ps1

# 3. Ver logs
# Dashboard → Edge Functions → enviar-bienvenida → Logs
```

### Error en el registro

```typescript
// Agregar más logs en app/solicitante/registro/page.tsx
try {
  const response = await fetch('/api/enviar-bienvenida', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      email: email,
      nombre: `${nombre} ${apellido}`
    })
  });
  
  const result = await response.json();
  console.log('Resultado del email:', result);
} catch (emailError) {
  console.error('Error al enviar email:', emailError);
}
```

## 🎉 ¡Listo!

Una vez completados estos pasos, cada vez que un usuario se registre en tu plataforma:

1. ✅ Se creará su cuenta en Supabase Auth
2. ✅ Se creará su perfil en la tabla `perfiles`
3. ✅ Recibirá automáticamente un email de bienvenida
4. ✅ Será redirigido a su dashboard

---

**¡Sistema de bienvenida automático completamente funcional!** 📧✨

## 📞 Siguiente Paso

**Ejecuta estos comandos ahora:**

1. **Configura el service_role_key** en `.env.local`
2. **Reinicia el servidor**: `npm run dev`
3. **Prueba el registro** en `http://localhost:3000/solicitante/registro`

¡Y listo! 🚀
