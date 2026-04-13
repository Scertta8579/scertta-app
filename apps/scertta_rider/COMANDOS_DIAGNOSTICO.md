# ⚡ Comandos para Diagnóstico Inmediato

## 🚀 Ejecutar la App

```powershell
cd c:\Users\andre\Desktop\scertta-app\flutter_app
flutter run
```

---

## 👀 Qué Observar

### En la Pantalla

**Cartelitos que aparecerán** (parte inferior):

```
1. PASO 1: Autenticando con Supabase... (azul, 1 seg)
2. ✅ PASO 1: Login exitoso (verde, 1 seg)
3. PASO 2: Refrescando sesión... (azul, 1 seg)
4. ✅ PASO 2: Sesión refrescada (verde, 1 seg)
5. PASO 3: Verificando sesión... (azul, 1 seg)
6. ✅ PASO 3: Sesión activa (verde, 1 seg)
7. PASO 4: Consultando perfil... (azul, 1 seg)
8. ✅ PASO 4: Perfil encontrado (verde, 1 seg)
9. PASO 5: Navegando a CEO Home... (azul, 1 seg)
10. [CEO HOME SE ABRE]
```

**Si se traba**: El ÚLTIMO cartelito te dice dónde.

### En la Consola (Terminal)

**Busca estas líneas**:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔐 INICIANDO SESIÓN
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Luego:

```
━━━ PASO 1: Login exitoso ━━━
━━━ PASO 1 COMPLETADO ━━━

━━━ PASO 2: Refrescando sesión ━━━
━━━ PASO 2 COMPLETADO ━━━

━━━ PASO 3: Verificando sesión activa ━━━
━━━ PASO 3 COMPLETADO ━━━

━━━ PASO 4: Consultando tabla perfiles ━━━
━━━ PASO 4 COMPLETADO ━━━

━━━ PASO 5: Intentando navegar a CEO Home ━━━
━━━ PASO 5 COMPLETADO ━━━

✅ LOGIN COMPLETADO EXITOSAMENTE
```

**El ÚLTIMO paso completado** te dice hasta dónde llegó.

---

## 🔍 Diagnóstico Rápido

### Caso A: Se Traba en PASO 1

**Último Cartelito**: "PASO 1: Autenticando con Supabase..."

**Último Log**: `Llamando a supabase.auth.signInWithPassword...`

**Problema**: Supabase no responde.

**Solución**:
```powershell
# Verifica conexión
ping cmuhwyxmluhnlzcasceq.supabase.co
```

### Caso B: Se Traba en PASO 2

**Último Cartelito**: "✅ PASO 1: Login exitoso"

**Último Log**: `━━━ PASO 1 COMPLETADO ━━━`

**Problema**: refreshSession() cuelga.

**Solución**: Verifica sesión en Supabase Dashboard.

### Caso C: Se Traba en PASO 4

**Último Cartelito**: "✅ PASO 3: Sesión activa"

**Último Log**: `━━━ PASO 3 COMPLETADO ━━━`

**Problema**: Query a tabla perfiles cuelga.

**Solución**:
```sql
-- En Supabase SQL Editor
SELECT * FROM perfiles WHERE email = 'tu_email@ejemplo.com';
```

### Caso D: Se Traba en PASO 5

**Último Cartelito**: "✅ PASO 4: Perfil encontrado"

**Último Log**: `━━━ PASO 4 COMPLETADO ━━━`

**Problema**: Navigator cuelga.

**Solución**: Verifica que `ceo_home.dart` no tenga errores.

---

## 📋 Información a Reportar

### Formato Simple

```
ÚLTIMO CARTELITO: [pega aquí]
ÚLTIMO LOG: [pega aquí]
```

### Formato Completo

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
DIAGNÓSTICO DE PROBLEMA
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ÚLTIMO CARTELITO EN PANTALLA:
[pega aquí]

ÚLTIMO LOG EN CONSOLA:
[pega aquí]

LOGS COMPLETOS:
[pega todos los logs desde "INICIANDO SESIÓN" hasta donde se detenga]

CAPTURA DE PANTALLA:
[adjunta si es posible]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## 🛠️ Soluciones Rápidas

### Si Se Traba en Cualquier Paso

#### Opción 1: Hot Restart

```
R  # En el terminal (mayúscula)
```

#### Opción 2: Rebuild

```powershell
# Detener app
q

# Limpiar
flutter clean

# Reinstalar
flutter pub get

# Ejecutar
flutter run
```

#### Opción 3: Verificar Supabase

1. Abre Supabase Dashboard
2. Authentication → Users
3. Busca tu email
4. Verifica que esté confirmado

---

## ✅ Checklist de 3 Puntos

1. **Ejecutar**:
   ```powershell
   cd c:\Users\andre\Desktop\scertta-app\flutter_app
   flutter run
   ```

2. **Login**:
   - Email: tu_email@ejemplo.com
   - Password: tu_contraseña_correcta
   - Click "Iniciar Sesión"

3. **Observar**:
   - 👀 Pantalla → Cartelitos
   - 👀 Consola → Logs con `━━━`
   - 📋 Anotar último de cada uno

---

## 🎯 Resultado Esperado

**Si funciona**:
- ✅ Verás 10 cartelitos (5 azules, 5 verdes)
- ✅ Verás ~15 bloques de logs
- ✅ CEO Home se abrirá
- ✅ Mapa visible
- ✅ NO volverás al Login

**Si se traba**:
- ❌ Verás menos de 10 cartelitos
- ❌ Logs se detendrán en algún paso
- ❌ Pantalla congelada o negra

**En ambos casos**: Los logs te dirán EXACTAMENTE qué pasó.

---

## 🚀 Ejecuta AHORA

```powershell
cd c:\Users\andre\Desktop\scertta-app\flutter_app
flutter run
```

**Observa y reporta** 👀

**¡Con los logs podré darte la solución exacta!** 🎯

---

**COMANDOS LISTOS PARA EJECUTAR** ✅
