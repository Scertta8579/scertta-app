# Infraestructura Scertta — Guía Operativa

## Frente 1 — Túnel Cloudflare (servidor ASUS local)

### Requisito
Exponer las PWAs (Rider, Driver, CEO) externamente sin IP pública fija.

### Pasos (ejecutar en el servidor ASUS)

```bash
# 1. Instalar cloudflared
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 \
  -o /usr/local/bin/cloudflared && chmod +x /usr/local/bin/cloudflared

# 2. Autenticar con Cloudflare (abre el browser para iniciar sesión)
cloudflared tunnel login

# 3. Crear el túnel
cloudflared tunnel create scertta-local

# 4. Crear config.yml en ~/.cloudflared/config.yml
cat > ~/.cloudflared/config.yml <<EOF
tunnel: scertta-local
credentials-file: /root/.cloudflared/<TUNNEL_ID>.json

ingress:
  - hostname: rider.scertta.test
    service: http://localhost:3001
  - hostname: driver.scertta.test
    service: http://localhost:3002
  - hostname: ceo.scertta.test
    service: http://localhost:3003
  - service: http_status:404
EOF

# 5. Crear registros DNS en Cloudflare (panel o CLI)
cloudflared tunnel route dns scertta-local rider.scertta.test
cloudflared tunnel route dns scertta-local driver.scertta.test
cloudflared tunnel route dns scertta-local ceo.scertta.test

# 6. Correr el túnel (foreground para pruebas)
cloudflared tunnel run scertta-local

# 6b. Correr como servicio systemd (producción)
cloudflared service install
systemctl enable cloudflared
systemctl start cloudflared
```

> **Alternativa rápida con ngrok** (para pruebas inmediatas, sin dominio):
> ```bash
> ngrok http 3001  # Rider
> ngrok http 3002  # Driver
> ngrok http 3003  # CEO
> ```
> Las URLs temporales de ngrok deben publicarse en el comentario de SCE-21.

---

## Frente 6 — Compilación APKs Producción

### Prerequisitos
- Flutter SDK ≥ 3.19 instalado y en `$PATH`
- `android/local.properties` con `sdk.dir` apuntando al Android SDK
- Keystore firmado configurado en `android/key.properties`

### Pasos

```bash
# Desde la raíz del proyecto Flutter

# 1. Limpiar build anterior
flutter clean

# 2. Obtener dependencias
flutter pub get

# 3. Verificar parches de seguridad pendientes
flutter pub outdated

# 4. Aplicar upgrades menores compatibles
flutter pub upgrade --minor-versions

# 5. Build APK release — Rider
flutter build apk --release --flavor rider \
  --dart-define=APP_VARIANT=rider \
  -t lib/main_rider.dart

# 6. Build APK release — Driver
flutter build apk --release --flavor driver \
  --dart-define=APP_VARIANT=driver \
  -t lib/main_driver.dart

# 7. Rutas de salida
# build/app/outputs/flutter-apk/app-rider-release.apk
# build/app/outputs/flutter-apk/app-driver-release.apk

# 8. Copiar a carpeta de descarga del servidor
cp build/app/outputs/flutter-apk/app-rider-release.apk  /srv/downloads/scertta/rider-v$(date +%Y%m%d).apk
cp build/app/outputs/flutter-apk/app-driver-release.apk /srv/downloads/scertta/driver-v$(date +%Y%m%d).apk

# 9. Verificar firma del APK
keytool -printcert -jarfile build/app/outputs/flutter-apk/app-rider-release.apk
```

### URLs de descarga (publicar en SCE-21 cuando estén disponibles)
```
Rider:  https://<servidor>/downloads/scertta/rider-vYYYYMMDD.apk
Driver: https://<servidor>/downloads/scertta/driver-vYYYYMMDD.apk
```

---

## Flujo de Comisión MercadoPago

| Paso | Descripción |
|------|-------------|
| 1 | Pasajero solicita viaje y selecciona "MercadoPago" |
| 2 | App genera deep link `mercadopago://` con `amount` = tarifa total |
| 3 | Deep link abre la app de MercadoPago del pasajero |
| 4 | Pasajero realiza la transferencia (o escanea QR) |
| 5 | MP notifica el pago via webhook a la Edge Function `mp-webhook` |
| 6 | Edge Function realiza el **split automático**: 85% → cuenta del driver, 15% → cuenta Scertta |
| 7 | Viaje se marca como `paid` y se habilita la calificación |

> **Nota:** El split requiere la API de MercadoPago Marketplace.
> La cuenta Scertta debe estar configurada como Marketplace en el panel de MP.
> Credenciales MP (`MP_ACCESS_TOKEN`, `MP_PUBLIC_KEY`) se almacenan en Supabase Secrets,
> nunca en el código fuente.
