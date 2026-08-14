#!/bin/bash
# ═══════════════════════════════════════════════════
# BYPASS LOGIN — Acceso directo al Dashboard
# Uso: bash scripts/bypass-login.sh
# Abre el navegador autenticado como ceo_admin
# ═══════════════════════════════════════════════════

SUPABASE_URL="https://TU_PROYECTO.supabase.co"
ANON_KEY="TU_ANON_KEY_JWT"
APP_URL="http://localhost:3003"

echo "🔑 Solicitando sesión Supabase para ceo_admin..."

# 1. Sign in via Supabase Auth API
AUTH_RESP=$(curl -s -X POST "${SUPABASE_URL}/auth/v1/token?grant_type=password" \
  -H "apikey: ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"email":"scertta.principal@gmail.com","password":"TU_PASSWORD","gotrue_meta_security":{}}')

ACCESS_TOKEN=$(echo "$AUTH_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('access_token',''))" 2>/dev/null)
REFRESH_TOKEN=$(echo "$AUTH_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('refresh_token',''))" 2>/dev/null)
EXPIRES_AT=$(echo "$AUTH_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('expires_at',''))" 2>/dev/null)

if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" = "" ]; then
  echo "❌ Error: No se pudo autenticar."
  echo "   Respuesta: $AUTH_RESP"
  echo ""
  echo "   📋 Credencial manual:"
  echo "   Email: scertta.principal@gmail.com"
  echo "   Pass:  TU_PASSWORD"
  echo "   URL:   ${APP_URL}/login"
  exit 1
fi

echo "✅ Sesión obtenida (expira: $(date -d @$EXPIRES_AT 2>/dev/null || echo $EXPIRES_AT))"

# 2. Generate bypass HTML page that sets cookies + redirects
BYPASS_FILE="/tmp/rutmy_bypass_$(date +%s).html"

cat > "$BYPASS_FILE" << HTMLEOF
<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"><title>Rutmy — Acceso Directo</title></head>
<body style="background:#0F172A;color:#64DEB2;font-family:sans-serif;display:flex;align-items:center;justify-content:center;height:100vh;margin:0;flex-direction:column;gap:20px;">
  <h1 style="font-size:2rem;">Rutmy</h1>
  <p style="color:#ccc;">Redirigiendo al Dashboard...</p>
  <script>
    // Set Supabase session in localStorage
    const session = {
      access_token: "${ACCESS_TOKEN}",
      refresh_token: "${REFRESH_TOKEN}",
      expires_at: ${EXPIRES_AT},
      token_type: "bearer",
      user: { email: "scertta.principal@gmail.com" }
    };
    
    // Try to set via Supabase expected key formats
    const key = "sb-${SUPABASE_URL##https://}-auth-token";
    localStorage.setItem(key, JSON.stringify(session));
    
    // Also set raw cookie-like entries
    localStorage.setItem("supabase.auth.token", JSON.stringify(session));
    
    // Redirect to dashboard
    window.location.href = "${APP_URL}/ceo-dashboard";
  </script>
</body>
</html>
HTMLEOF

echo "📄 Página bypass generada: $BYPASS_FILE"

# 3. Open browser
if command -v xdg-open &>/dev/null; then
  xdg-open "$BYPASS_FILE" 2>/dev/null &
  echo "🚀 Abriendo navegador..."
elif command -v open &>/dev/null; then
  open "$BYPASS_FILE" 2>/dev/null &
  echo "🚀 Abriendo navegador..."
else
  echo "📋 Abrí manualmente: file://${BYPASS_FILE}"
fi

echo ""
echo "═══════════════════════════════"
echo "  Dashboard: ${APP_URL}/ceo-dashboard"
echo "  Usuario:   scertta.principal@gmail.com"
echo "  Pass:      TU_PASSWORD"
echo "═══════════════════════════════"
HTMLEOF
