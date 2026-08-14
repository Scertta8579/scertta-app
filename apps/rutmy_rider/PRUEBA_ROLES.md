# ⚡ Prueba Rápida de Navegación por Roles

## 🚀 Ejecutar

```powershell
cd c:\Users\andre\Desktop\scertta-app\flutter_app
flutter run
```

---

## 🧪 Test de Roles

### Test 1: Usuario Solicitante

**Credenciales**: Email de usuario con rol `solicitante`

**Esperado**:
1. Login exitoso
2. Logs muestran: `🎯 ROL: solicitante`
3. Logs muestran: `📍 Destino: RiderHomeScreen`
4. ✅ Se abre `rider_home.dart`
5. ✅ Ves panel inferior para ingresar destino
6. ✅ Ves mapa de Buenos Aires

### Test 2: Usuario Conductor

**Credenciales**: Email de usuario con rol `conductor`

**Esperado**:
1. Login exitoso
2. Logs: `🎯 ROL: conductor`
3. Logs: `📍 Destino: DriverHomeScreen`
4. ✅ Se abre `driver_home.dart`
5. ✅ Ves botón grande "CONECTARSE"
6. ✅ Ves botón "MI PLAN DE TRABAJO"

### Test 3: Usuario CEO

**Credenciales**: Email de usuario con rol `ceo`

**Esperado**:
1. Login exitoso
2. Logs: `🎯 ROL: ceo`
3. Logs: `📍 Destino: CeoHomeScreen`
4. ✅ Se abre `ceo_home.dart`
5. ✅ Ves panel de "Autorizaciones Pendientes"
6. ✅ Ves botones flotantes (Gestión, Heatmap, Zonas)

---

## 👀 Qué Buscar en Logs

### Para Solicitante

```
━━━ PASO 4 COMPLETADO ━━━
   🎯 ROL: solicitante

━━━ PASO 5: Navegando según rol del usuario ━━━
🎯 Rol detectado: solicitante
📍 Destino: RiderHomeScreen (rol: solicitante)
✅ Navegación ejecutada exitosamente
   Destino: Rider Home (Solicitante)
   Rol: solicitante
```

### Para Conductor

```
   🎯 ROL: conductor
📍 Destino: DriverHomeScreen (rol: conductor)
   Destino: Driver Home (Conductor)
   Rol: conductor
```

### Para CEO

```
   🎯 ROL: ceo
📍 Destino: CeoHomeScreen (rol: ceo)
   Destino: CEO Home (CEO)
   Rol: ceo
```

---

## 🔍 Verificar Rol en Supabase

### Consultar Tu Rol

```sql
-- En Supabase SQL Editor
SELECT email, nombre, rol 
FROM perfiles 
WHERE email = 'tu_email@ejemplo.com';
```

### Cambiar Tu Rol (Para Testing)

```sql
-- Cambiar a solicitante
UPDATE perfiles SET rol = 'solicitante' WHERE email = 'tu_email@ejemplo.com';

-- Cambiar a conductor
UPDATE perfiles SET rol = 'conductor' WHERE email = 'tu_email@ejemplo.com';

-- Cambiar a ceo
UPDATE perfiles SET rol = 'ceo' WHERE email = 'tu_email@ejemplo.com';
```

**Luego**: Logout y login nuevamente para ver la pantalla correspondiente.

---

## 📊 Tabla de Resultados

| Rol | Pantalla Esperada | Panel/Botón Principal |
|-----|-------------------|----------------------|
| `solicitante` | Rider Home | Panel inferior para destino |
| `conductor` | Driver Home | Botón "CONECTARSE" + "MI PLAN" |
| `ceo` | CEO Home | Panel "Autorizaciones Pendientes" |
| `operador` | Admin Home | Drawer con buscador |
| `admin` | Admin Home | Drawer con buscador |
| `marketing` | Marketing Home | Panel superior con heatmap |
| `null` o desconocido | Rider Home (default) | Panel inferior |

---

## ✅ Checklist de Prueba

### Antes de Reportar Problema

- [ ] Ejecuté `flutter run`
- [ ] Verifiqué mi rol en Supabase
- [ ] Hice login
- [ ] Observé los logs en consola
- [ ] Busqué la línea `🎯 ROL: [mi_rol]`
- [ ] Busqué la línea `📍 Destino: [pantalla]`
- [ ] Verifiqué que la pantalla que se abrió sea la correcta

### Si la Pantalla es Incorrecta

**Envíame**:
1. Tu rol en Supabase: `[rol]`
2. Pantalla que se abrió: `[pantalla]`
3. Logs completos desde "PASO 4"

---

## 🎯 Comando Rápido

```powershell
cd c:\Users\andre\Desktop\scertta-app\flutter_app
flutter run
```

**Luego**:
1. Login con tus credenciales
2. Observa qué pantalla se abre
3. Verifica que sea la correcta según tu rol

**Si es correcta** → ✅ ¡Funciona!

**Si es incorrecta** → Envíame tu rol y la pantalla que viste.

---

## 🎉 Resultado Esperado

### Solicitante

```
Login → Rider Home
- Panel inferior para destino
- Mapa de Buenos Aires
- Botón de menú (drawer)
```

### Conductor

```
Login → Driver Home
- Botón grande "CONECTARSE"
- Botón "MI PLAN DE TRABAJO"
- Info del conductor arriba
- Mapa de Buenos Aires
```

### CEO

```
Login → CEO Home
- Panel "Autorizaciones Pendientes"
- 3 tarjetas con badges rojos
- Botón "Gestión Financiera"
- Botón "Heatmap"
- Botón "Marcar zonas"
- Mapa de Buenos Aires
```

---

**¡Prueba AHORA con tu usuario!** 🚀

**Tiempo de prueba**: 30 segundos ⚡

**Navegación por roles**: ✅ IMPLEMENTADA
