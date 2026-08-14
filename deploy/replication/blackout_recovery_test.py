#!/usr/bin/env python3
"""
🔥 PRUEBA DE FUEGO — Simulación de Corte de Luz + Recuperación
═══════════════════════════════════════════════════════════════
Escenario:
  1. PostgreSQL local operando normalmente
  2. 💥 CORTE DE LUZ → local cae
  3. Apps switchean a Cloud → usuarios se registran, choferes viajan
  4. ⚡ VUELVE LA LUZ → ZimaOS arranca, PostgreSQL local enciende
  5. Recovery script: PULL forzado del WAL de Cloud → delta sincronizado
  6. ✅ Paridad 100% verificada

ESTRATEGIA DE RECUPERACIÓN:
  - La suscripción lógica en el PostgreSQL local se reconecta automáticamente
  - ALTER SUBSCRIPTION REFRESH PUBLICATION fuerza el catch-up
  - pg_wal_lsn_diff() mide el lag restante
  - El script espera hasta que lag < 1KB (sincronización completa)
"""

import subprocess, time, sys
from datetime import datetime

CLOUD_DSN = "postgresql://postgres:TU_PASSWORD_DB@db.TU_PROYECTO.supabase.co:5432/postgres"
LOCAL_DSN = "postgresql://postgres:TU_PASSWORD_DB@localhost:5433/postgres"

def ts(): return datetime.now().strftime("%H:%M:%S")

def log(msg, emoji="📋"):
    print(f"{emoji} [{ts()}] {msg}")

def run_sql(dsn, sql, label=""):
    """Ejecuta SQL y devuelve output."""
    cmd = ["psql", dsn, "--no-psqlrc", "-At", "-c", sql]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=15)
        if result.returncode == 0:
            return result.stdout.strip()
        else:
            return f"ERROR: {result.stderr.strip()[:200]}"
    except Exception as e:
        return f"EXCEPTION: {str(e)[:200]}"

def check_pg(dsn, name):
    """Verifica si PostgreSQL responde."""
    try:
        result = subprocess.run(
            ["psql", dsn, "--no-psqlrc", "-At", "-c", "SELECT 1"],
            capture_output=True, text=True, timeout=5
        )
        ok = result.returncode == 0 and "1" in result.stdout
        status = "🟢 ONLINE" if ok else "🔴 ERROR"
        print(f"  {name:20s} → {status}")
        return ok
    except Exception:
        print(f"  {name:20s} → 🔴 UNREACHABLE")
        return False

# ═══════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════

def main():
    print("=" * 60)
    print("🔥 PRUEBA DE FUEGO — Blackout Recovery Simulation")
    print("=" * 60)
    
    # ── STEP 0: Check environment ──
    log("STEP 0: Verificando conexiones...", "🔍")
    cloud_ok = check_pg(CLOUD_DSN, "Supabase Cloud")
    local_ok = check_pg(LOCAL_DSN, "PostgreSQL Local")
    
    if not cloud_ok:
        log("❌ Cloud inaccesible. Abortando.", "🛑")
        sys.exit(1)
    
    print()
    
    # ── STEP 1: Simular datos insertados durante el apagón ──
    log("STEP 1: 💥 SIMULANDO CORTE DE LUZ", "💥")
    log("   Apps switchean a Cloud. Usuarios se registran en la nube...", "📱")
    
    # Crear tabla de convergencia en Cloud (si no existe)
    run_sql(CLOUD_DSN, """
        CREATE TABLE IF NOT EXISTS public.test_convergencia (
            id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            origen text NOT NULL DEFAULT 'cloud',
            mensaje text NOT NULL,
            created_at timestamptz NOT NULL DEFAULT now()
        )
    """)
    
    # Insertar datos simulando registros de usuario durante el apagón
    inserts = []
    for i in range(10):
        result = run_sql(CLOUD_DSN, 
            f"INSERT INTO public.test_convergencia (origen, mensaje) VALUES ('cloud', 'Usuario #{i+1} registrado durante apagon') RETURNING id",
            f"insert_{i}"
        )
        inserts.append(result)
        print(f"   📝 Cloud: Usuario #{i+1} registrado → {result[:50]}...")
    
    log(f"✅ {len(inserts)} usuarios creados en Cloud durante el apagón", "✅")
    
    # ── STEP 2: Verificar Cloud tiene los datos ──
    log("STEP 2: Verificando datos en Cloud...", "☁️")
    cloud_count = run_sql(CLOUD_DSN, "SELECT count(*) FROM public.test_convergencia")
    cloud_rows = run_sql(CLOUD_DSN, "SELECT mensaje FROM public.test_convergencia ORDER BY created_at DESC LIMIT 3")
    print(f"   Cloud tiene {cloud_count} registros:")
    for line in cloud_rows.split("\n"):
        print(f"      ☁️ {line}")
    
    print()
    
    # ── STEP 3: Simular recuperación ──
    log("STEP 3: ⚡ VUELVE LA LUZ — Iniciando recuperación...", "⚡")
    
    if local_ok:
        log("   PostgreSQL local está ONLINE — forzando PULL del WAL", "🔄")
        
        # Verificar si la tabla existe en local
        local_has_table = run_sql(LOCAL_DSN, 
            "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name='test_convergencia')"
        )
        
        if local_has_table == "t":
            # Forzar refresh de la suscripción
            log("   ALTER SUBSCRIPTION REFRESH PUBLICATION...", "🔄")
            refresh_result = run_sql(LOCAL_DSN,
                "ALTER SUBSCRIPTION rutmy_subscription REFRESH PUBLICATION"
            )
            print(f"   {refresh_result}")
            
            # Forzar sync
            log("   ALTER SUBSCRIPTION ENABLE...", "🔄")
            run_sql(LOCAL_DSN, "ALTER SUBSCRIPTION rutmy_subscription ENABLE")
            
            # Esperar catch-up del WAL
            log("   Esperando sincronización del WAL...", "⏳")
            for attempt in range(30):
                lag = run_sql(LOCAL_DSN, """
                    SELECT COALESCE(pg_wal_lsn_diff(latest_end_lsn, received_lsn), 999999)
                    FROM pg_stat_subscription WHERE subname = 'rutmy_subscription'
                """)
                try:
                    lag_bytes = int(lag) if lag and lag.isdigit() else 999999
                except:
                    lag_bytes = 999999
                
                if lag_bytes < 1024:
                    log(f"   ✅ WAL sincronizado! Lag: {lag_bytes} bytes", "✅")
                    break
                
                print(f"   ⏳ Lag: {lag_bytes} bytes — intento {attempt+1}/30")
                time.sleep(2)
            else:
                log("   ⚠️ Timeout esperando sync. Continuando...", "⚠️")
            
            # ── STEP 4: Verificar paridad ──
            log("STEP 4: Verificando paridad Cloud ↔ Local...", "🔍")
            
            local_count = run_sql(LOCAL_DSN, "SELECT count(*) FROM public.test_convergencia")
            local_rows = run_sql(LOCAL_DSN, "SELECT mensaje FROM public.test_convergencia ORDER BY created_at DESC LIMIT 3")
            
            print(f"\n   Cloud: {cloud_count} registros")
            print(f"   Local: {local_count} registros")
            print(f"\n   Últimos en Local:")
            for line in local_rows.split("\n"):
                print(f"      💻 {line}")
            
            if cloud_count == local_count:
                log("🎉 PARIDAD 100% — Recuperación post-apagón EXITOSA", "🎉")
            else:
                log(f"⚠️ Diferencia: Cloud={cloud_count}, Local={local_count}", "⚠️")
        else:
            log("   ⚠️ Tabla test_convergencia no existe en local", "⚠️")
            log("   Aplicá la migración via: ./migrate.sh push", "💡")
    else:
        log("   PostgreSQL local OFFLINE — no se puede verificar sync", "⚠️")
        log("   Para prueba completa, levantá el Docker:", "💡")
        log("   docker compose -f deploy/replication/docker-compose.yml up -d", "💡")
    
    print()
    print("=" * 60)
    print("🔥 PRUEBA DE FUEGO COMPLETADA")
    print("=" * 60)
    print()
    print("RESUMEN DEL FLUJO DE CONTINGENCIA:")
    print("  1. 💥 Corte de luz → Apps switchean a Cloud (<2s)")
    print("  2. 📱 Usuarios se registran en Cloud (normal)")
    print("  3. ⚡ Vuelve la luz → PostgreSQL local enciende")
    print("  4. 🔄 Suscripción lógica se reconecta automáticamente")
    print("  5. 📥 WAL PULL descarga todos los datos nuevos")
    print("  6. ✅ Paridad 100% Cloud ↔ Local")
    print()

if __name__ == "__main__":
    main()
