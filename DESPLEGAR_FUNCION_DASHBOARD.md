# 🚀 Desplegar Edge Function desde Supabase Dashboard

## ⚡ Método Más Fácil (Sin CLI)

Ya que Supabase CLI no se puede instalar globalmente con npm en Windows, usa el Dashboard:

### Paso 1: Acceder al Dashboard

1. Ve a [https://app.supabase.com](https://app.supabase.com)
2. Inicia sesión con tu cuenta
3. Selecciona tu proyecto de Scertta

### Paso 2: Crear la Edge Function

1. En el menú lateral, haz clic en **Edge Functions**
2. Haz clic en el botón **Create Function**
3. Nombre de la función: `enviar-bienvenida`
4. Deja el template por defecto (lo reemplazaremos)

### Paso 3: Copiar el Código

1. Abre el archivo: `c:\Users\andre\Desktop\scertta-app\supabase\functions\enviar-bienvenida\index.ts`
2. Copia **TODO** el contenido del archivo
3. En el Dashboard, **borra** el código de ejemplo
4. **Pega** el código que copiaste
5. Haz clic en **Deploy**

### Paso 4: Verificar el Despliegue

Deberías ver un mensaje de éxito. La función ahora está disponible en:
```
https://tu-proyecto.supabase.co/functions/v1/enviar-bienvenida
```

### Paso 5: Probar la Función

#### Opción A: Desde el Dashboard

1. En la página de la función, busca la sección **Test**
2. En el body, pega:
```json
{
  "email": "tu-email@ejemplo.com",
  "nombre": "Tu Nombre"
}
```
3. Haz clic en **Send Request**
4. Verifica que recibas el email

#### Opción B: Desde PowerShell

```powershell
# Obtener tu ANON_KEY desde: Settings → API → anon public

$headers = @{
    "Authorization" = "Bearer TU_ANON_KEY_AQUI"
    "Content-Type" = "application/json"
}

$body = @{
    email = "tu-email@ejemplo.com"
    nombre = "Tu Nombre"
} | ConvertTo-Json

Invoke-RestMethod -Uri "https://tu-proyecto.supabase.co/functions/v1/enviar-bienvenida" -Method Post -Headers $headers -Body $body
```

#### Opción C: Desde el Código

```typescript
import { enviarCorreoBienvenida } from "@/lib/emailService";

const resultado = await enviarCorreoBienvenida(
  "tu-email@ejemplo.com",
  "Tu Nombre"
);

console.log(resultado);
```

## 📊 Ver Logs

1. En el Dashboard, ve a **Edge Functions**
2. Selecciona `enviar-bienvenida`
3. Ve a la pestaña **Logs**
4. Verás todos los requests y errores

## 🔄 Actualizar la Función

Si necesitas hacer cambios:

1. Edita el archivo `index.ts` localmente
2. Ve al Dashboard → Edge Functions → `enviar-bienvenida`
3. Copia y pega el nuevo código
4. Haz clic en **Deploy**

## 🔑 Obtener tu ANON_KEY

1. En el Dashboard, ve a **Settings** (⚙️)
2. Ve a **API**
3. Copia el **anon public** key
4. Úsalo en los headers de tus requests

## ✅ Verificar que Funciona

### Test Completo

1. **Desplegar**: ✓ Función desplegada en Dashboard
2. **Probar**: ✓ Enviar request de prueba
3. **Email**: ✓ Verificar que llegó el email
4. **Logs**: ✓ Revisar logs sin errores

## 🎉 ¡Listo!

Tu función está desplegada y funcionando. Ahora puedes:

- ✅ Integrarla en tu código de registro
- ✅ Enviar emails de bienvenida automáticamente
- ✅ Monitorear los envíos desde el Dashboard

---

## 🔧 Alternativa: Instalar CLI con Scoop (Opcional)

Si prefieres usar la CLI en el futuro:

### Instalar Scoop (si no lo tienes)

```powershell
# En PowerShell como administrador
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
irm get.scoop.sh | iex
```

### Instalar Supabase CLI

```powershell
scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
scoop install supabase
```

### Verificar Instalación

```powershell
supabase --version
```

### Desplegar con CLI

```powershell
# Login
supabase login

# Link al proyecto
supabase link --project-ref tu-project-ref

# Desplegar
cd supabase\functions
supabase functions deploy enviar-bienvenida
```

---

**¡Función desplegada y lista para enviar emails!** 📧✨
