# 🔐 PLAN MIGRACIÓN CADDY — Scertta/Rutmy

> Arquitectura de defensa en capas: Cloudflare (edge) → Caddy (proxy interno) → Next.js / Apps

---

## 1. Caddyfile — Configuración Completa

```caddyfile
# ═══════════════════════════════════════════════════════════
# CADDY — Proxy Central Scertta/Rutmy
# Reemplaza Nginx en todas las funciones de reverse proxy
# ═══════════════════════════════════════════════════════════

{
    # ── Seguridad global ──
    servers {
        # Solo aceptar tráfico de Cloudflare
        trusted_proxies static {
            173.245.48.0/20
            103.21.244.0/22
            103.22.200.0/22
            103.31.4.0/22
            141.101.64.0/18
            108.162.192.0/18
            190.93.240.0/20
            188.114.96.0/20
            197.234.240.0/22
            198.41.128.0/17
            162.158.0.0/15
            104.16.0.0/13
            104.24.0.0/14
            172.64.0.0/13
            131.0.72.0/22
            2400:cb00::/32
            2606:4700::/32
            2803:f800::/32
            2405:b500::/32
            2405:8100::/32
            2a06:98c0::/29
            2c0f:f248::/32
        }
        client_ip_headers CF-Connecting-IP X-Real-IP
    }
}

# ═══════════════════════════════════════════════════════════
# PÁGINAS PÚBLICAS — scertta.com / rutmy.com
# ═══════════════════════════════════════════════════════════

scertta.com, www.scertta.com {
    # ── Bloqueo de bots de IA ──
    @ai_bots {
        header User-Agent *GPTBot*
        header User-Agent *Claude* 
        header User-Agent *anthropic*
        header User-Agent *CCBot*
        header User-Agent *Google-Extended*
        header User-Agent *FacebookBot*
        header User-Agent *Bytespider*
        header User-Agent *cohere*
        header User-Agent *PerplexityBot*
        header User-Agent *YouBot*
    }
    respond @ai_bots "Access Denied" 403

    # ── Rate Limiting público ──
    rate_limit {
        zone dynamic {
            key {remote_host}
            events 30
            window 10s
        }
    }

    # ── Headers de seguridad ──
    header {
        X-Frame-Options "DENY"
        X-Content-Type-Options "nosniff"
        Referrer-Policy "strict-origin-when-cross-origin"
        -Server
    }

    root * /var/www/html/scertta
    file_server
    try_files {path} /index.html
}

rutmy.com, www.rutmy.com {
    @ai_bots {
        header User-Agent *GPTBot*
        header User-Agent *Claude*
        header User-Agent *anthropic*
        header User-Agent *CCBot*
        header User-Agent *Google-Extended*
        header User-Agent *FacebookBot*
        header User-Agent *Bytespider*
        header User-Agent *cohere*
        header User-Agent *PerplexityBot*
        header User-Agent *YouBot*
    }
    respond @ai_bots "Access Denied" 403

    rate_limit {
        zone dynamic {
            key {remote_host}
            events 30
            window 10s
        }
    }

    header {
        X-Frame-Options "DENY"
        X-Content-Type-Options "nosniff"
        Referrer-Policy "strict-origin-when-cross-origin"
        -Server
    }

    root * /var/www/html/rutmy
    file_server
    try_files {path} /index.html

    # APKs públicas sin rate limit
    handle_path /apps/* {
        root * /var/www/html/apps
        file_server
    }
}

# ═══════════════════════════════════════════════════════════
# APPS FLUTTER — API Gateway sin Bot Barrier
# ═══════════════════════════════════════════════════════════

app.scertta.com {
    # ── SIN bloqueo de bots — las apps necesitan acceso libre ──

    rate_limit {
        zone dynamic {
            key {remote_host}
            events 100
            window 10s
        }
    }

    header {
        X-Frame-Options "DENY"
        X-Content-Type-Options "nosniff"
        Referrer-Policy "strict-origin-when-cross-origin"
        -Server
    }

    reverse_proxy localhost:3003
}

# ═══════════════════════════════════════════════════════════
# PORTAL — Next.js (producción)
# ═══════════════════════════════════════════════════════════

portal.scertta.com {
    @ai_bots {
        header User-Agent *GPTBot*
        header User-Agent *Claude*
        header User-Agent *anthropic*
        header User-Agent *CCBot*
    }
    respond @ai_bots "Access Denied" 403

    rate_limit {
        zone dynamic {
            key {remote_host}
            events 60
            window 10s
        }
    }

    header {
        X-Frame-Options "DENY"
        X-Content-Type-Options "nosniff"
        Referrer-Policy "strict-origin-when-cross-origin"
        -Server
    }

    reverse_proxy localhost:3006
}

# ═══════════════════════════════════════════════════════════
# PWAs INTERNAS — Acceso restringido por IP corporativa
# ═══════════════════════════════════════════════════════════

# PWA: Gerencia (acceso solo desde red interna)
gerencia.scertta.com {
    @corp_ip {
        remote_ip 192.168.0.0/16
        remote_ip 10.0.0.0/8
    }
    handle @corp_ip {
        reverse_proxy localhost:3006 {
            header_up Host portal.scertta.com
        }
    }
    respond "Acceso restringido a red corporativa" 403
}

# PWA: Soporte
soporte.scertta.com {
    @corp_ip {
        remote_ip 192.168.0.0/16
        remote_ip 10.0.0.0/8
    }
    handle @corp_ip {
        reverse_proxy localhost:3006 {
            header_up Host portal.scertta.com
        }
    }
    respond "Acceso restringido a red corporativa" 403
}

# PWA: RRHH
rrhh.scertta.com {
    @corp_ip {
        remote_ip 192.168.0.0/16
        remote_ip 10.0.0.0/8
    }
    handle @corp_ip {
        reverse_proxy localhost:3006 {
            header_up Host portal.scertta.com
        }
    }
    respond "Acceso restringido a red corporativa" 403
}

# PWA: Legales
legales.scertta.com {
    @corp_ip {
        remote_ip 192.168.0.0/16
        remote_ip 10.0.0.0/8
    }
    handle @corp_ip {
        reverse_proxy localhost:3006 {
            header_up Host portal.scertta.com
        }
    }
    respond "Acceso restringido a red corporativa" 403
}
```

---

## 2. Integración IA — Excepciones para agentes internos

```caddyfile
# ── EXCEPCIONES PARA AGENTES IA ──
# Insertar en cada bloque de sitio donde los agentes necesiten acceso

(ia_agent_exception) {
    @ia_agent {
        header Authorization "Bearer TOKEN_IA_*"
        # O usar header personalizado:
        # header X-Agent-Key "sk-scertta-agent-*"
    }

    # Bypass rate limit para agentes IA
    vars @ia_agent rate_limit off

    # Bypass bot blocking para agentes IA
    # (no se aplica porque los agentes no usan User-Agent de bot público)
}
```

### Cómo se integra en cada bloque:

```caddyfile
portal.scertta.com {
    import ia_agent_exception

    @ai_bots {
        header User-Agent *GPTBot*
        # ...
    }
    respond @ai_bots "Access Denied" 403

    # Rate limit NO aplica a agentes IA (vars lo desactiva)
    @not_agent {
        not vars {rate_limit_off} true
    }
    rate_limit @not_agent {
        zone dynamic {
            key {remote_host}
            events 60
            window 10s
        }
    }

    reverse_proxy localhost:3006
}
```

---

## 3. Validación Cloudflare IPs (caddy-cloudflare-ip)

### Instalación del módulo:

```bash
# Build Caddy con el módulo Cloudflare IP
xcaddy build \
    --with github.com/WeidiDeng/caddy-cloudflare-ip
```

### Uso en Caddyfile:

```caddyfile
(scertta_global) {
    # Solo aceptar tráfico de IPs de Cloudflare
    cloudflare_ip {
        # Rechazar tráfico que no venga de IPs de Cloudflare
        deny
    }
}

scertta.com {
    import scertta_global
    # ... resto de config
}
```

### Alternativa sin módulo (ya incluida arriba):

Usando `trusted_proxies` y `client_ip_headers` en el bloque global `{ servers }`, Caddy usa la IP real del cliente (vía `CF-Connecting-IP`) y ya sabe que las IPs de Cloudflare son proxies de confianza.

---

## 4. Plan de Migración Paso a Paso

### Fase A: Instalación
```bash
# ZimaOS — instalar Caddy via script oficial o binario
curl -fsSL https://getcaddy.com | bash -s personal

# Verificar
caddy version
```

### Fase B: Configuración
```bash
# Detener Nginx
systemctl stop nginx
systemctl disable nginx

# Crear Caddyfile
mkdir -p /etc/caddy
cp PLAN_MIGRACION_CADDY.md/Caddyfile /etc/caddy/Caddyfile

# Validar sintaxis
caddy validate --config /etc/caddy/Caddyfile
```

### Fase C: Prueba en staging
```bash
# Levantar en staging (puerto 8081) sin afectar producción
caddy run --config /etc/caddy/Caddyfile --adapter caddyfile --watch &
# Probar con curl en todos los dominios
```

### Fase D: Producción
```bash
# Instalar como servicio systemd
caddy environ
systemctl enable caddy
systemctl start caddy

# Migrar cloudflared para apuntar a Caddy (puerto 443/80) en vez de :8080
```

---

## 5. Ventajas sobre Nginx actual

| Aspecto | Nginx actual | Caddy propuesto |
|---------|-------------|-----------------|
| Configuración | 4 server blocks, reglas regex manuales | 1 archivo declarativo |
| HTTPS | No maneja (Cloudflare lo hace) | Igual |
| Rate Limiting | Requiere módulo externo | Nativo, por host |
| Bot Blocking | No implementado | Nativo, por User-Agent |
| IP Filtering | Manual con allow/deny | `trusted_proxies` + `cloudflare_ip` |
| IA Agent Bypass | No implementado | `vars` + excepciones |
| Recarga | `nginx -s reload` manual | Auto-reload con `--watch` |
| Logging | access.log + error.log | JSON structured logs nativo |

---

## 6. Riesgos y mitigación

| Riesgo | Mitigación |
|--------|-----------|
| Caddy no disponible en ZimaOS repo | Binario estático de GitHub Releases |
| Curva de aprendizaje | Caddyfile más simple que nginx.conf |
| cloudflared ya configurado | Solo cambiar `service: http://localhost:8080` → puerto de Caddy |
| Coexistencia con Nginx | Deshabilitar Nginx, no desinstalar — rollback instantáneo |

---

> **Elaborado:** 30 de junio de 2026
> **Autor:** Hermes (agente IA)
> **Estado:** Borrador para revisión de Andres
