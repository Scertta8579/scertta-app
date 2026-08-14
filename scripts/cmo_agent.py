#!/usr/bin/env python3
"""
Agente CMO Autónomo — Rutmy
============================
Ejecutado como cronjob de Hermes (diario).
1. Obtiene métricas de Supabase
2. Analiza KPIs, detecta anomalías/oportunidades
3. Genera sugerencias con número único (CMO-YYYY-NNNN)
4. Las inserta en sugerencias_cmo → notifica al CEO

Uso:
  python cmo_agent.py --dry-run          # Solo análisis, no inserta
  python cmo_agent.py                    # Ejecución completa
"""

import os
import sys
import json
import argparse
from datetime import datetime, timedelta
from typing import Optional

import requests
from supabase import create_client, Client


# ============================================
# CONFIGURACIÓN
# ============================================

SUPABASE_URL = os.environ.get("SUPABASE_URL", "")
SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")

# Umbrales para detección de anomalías/oportunidades
UMBRALES = {
    "crecimiento_semanal_min": 5.0,       # % mínimo de crecimiento esperado
    "crecimiento_alerta": -2.0,           # decrecimiento >2% → alerta
    "churn_alerta": 15.0,                 # churn >15% → alerta
    "presupuesto_alerta_pct": 85.0,       # gasto >85% del presupuesto → alerta
    "presupuesto_critico_pct": 95.0,      # gasto >95% → crítico
    "promos_sin_metricas_dias": 7,        # promos sin métricas por >7 días → revisar
    "campanas_inactivas_dias": 14,        # campañas en borrador >14 días → reactivar o archivar
    "ratio_conductores_solicitantes_min": 0.15,  # al menos 15 conductores por cada 100 solicitantes
}


# ============================================
# CLIENTE SUPABASE
# ============================================

def get_supabase() -> Client:
    """Obtener cliente de Supabase con service_role."""
    if not SUPABASE_URL or not SUPABASE_KEY:
        print("❌ Error: SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY deben estar definidos")
        sys.exit(1)
    return create_client(SUPABASE_URL, SUPABASE_KEY)


# ============================================
# OBTENCIÓN DE MÉTRICAS
# ============================================

def obtener_metricas(supabase: Client) -> dict:
    """Obtener todas las métricas relevantes para el CMO."""
    hoy = datetime.now()
    hace_30_dias = (hoy - timedelta(days=30)).isoformat()
    hace_7_dias = (hoy - timedelta(days=7)).isoformat()

    resultado = {}

    # 1. Vista metricas_marketing
    try:
        resp = supabase.table("metricas_marketing").select("*").single().execute()
        resultado["metricas"] = resp.data
    except Exception as e:
        resultado["metricas"] = {"error": str(e)}

    # 2. Viajes últimos 30 días
    try:
        resp = supabase.table("viajes").select("id", count="exact").gte("created_at", hace_30_dias).execute()
        resultado["viajes_30d"] = resp.count
    except Exception:
        resultado["viajes_30d"] = 0

    # 3. Viajes últimos 7 días (para tendencia)
    try:
        resp = supabase.table("viajes").select("id", count="exact").gte("created_at", hace_7_dias).execute()
        resultado["viajes_7d"] = resp.count
    except Exception:
        resultado["viajes_7d"] = 0

    # 4. Nuevos usuarios 7d
    try:
        resp = supabase.table("perfiles").select("id, rol", count="exact").gte("created_at", hace_7_dias).execute()
        nuevos = resp.data or []
        resultado["nuevos_solicitantes_7d"] = sum(1 for p in nuevos if p.get("rol") == "solicitante")
        resultado["nuevos_conductores_7d"] = sum(1 for p in nuevos if p.get("rol") == "conductor")
    except Exception:
        resultado["nuevos_solicitantes_7d"] = 0
        resultado["nuevos_conductores_7d"] = 0

    # 5. Promociones activas
    try:
        resp = supabase.table("promociones_geograficas").select("*").eq("activa", True).execute()
        resultado["promociones_activas"] = resp.data or []
    except Exception:
        resultado["promociones_activas"] = []

    # 6. Campañas
    try:
        resp = supabase.table("campanas_marketing").select("*").execute()
        campanas = resp.data or []
        resultado["campanas_activas"] = [c for c in campanas if c.get("estado") == "activa"]
        resultado["campanas_borrador"] = [c for c in campanas if c.get("estado") == "borrador"]
    except Exception:
        resultado["campanas_activas"] = []
        resultado["campanas_borrador"] = []

    # 7. Presupuesto actual
    try:
        resp = supabase.table("presupuesto_marketing").select("*").eq("mes", hoy.month).eq("anio", hoy.year).single().execute()
        resultado["presupuesto"] = resp.data
    except Exception:
        resultado["presupuesto"] = None

    # 8. Sugerencias pendientes
    try:
        resp = supabase.table("sugerencias_cmo").select("*").eq("estado", "pendiente").order("prioridad").execute()
        resultado["sugerencias_pendientes"] = resp.data or []
    except Exception:
        resultado["sugerencias_pendientes"] = []

    # 9. Métricas de promociones
    try:
        resp = supabase.table("metricas_promociones").select("*").gte("fecha", hace_30_dias).execute()
        resultado["metricas_promociones"] = resp.data or []
    except Exception:
        resultado["metricas_promociones"] = []

    return resultado


# ============================================
# ANÁLISIS Y GENERACIÓN DE SUGERENCIAS
# ============================================

def analizar_y_generar(metricas: dict) -> list[dict]:
    """Analiza métricas y genera sugerencias accionables."""
    sugerencias = []

    m = metricas.get("metricas", {})
    presup = metricas.get("presupuesto")
    promos = metricas.get("promociones_activas", [])
    campanas_activas = metricas.get("campanas_activas", [])
    campanas_borrador = metricas.get("campanas_borrador", [])
    pendientes = metricas.get("sugerencias_pendientes", [])
    viajes_30d = metricas.get("viajes_30d", 0)

    # ─── 1. Alerta de presupuesto ───
    if presup:
        asignado = float(presup.get("presupuesto_asignado", 0))
        gastado = float(presup.get("gasto_actual", 0))
        if asignado > 0:
            pct = (gastado / asignado) * 100
            if pct >= UMBRALES["presupuesto_critico_pct"]:
                sugerencias.append({
                    "titulo": "⚠️ Presupuesto de marketing en nivel CRÍTICO",
                    "descripcion": (
                        f"El presupuesto del mes está al {pct:.1f}% "
                        f"(${gastado:,.0f} de ${asignado:,.0f}). "
                        "Se recomienda pausar nuevas iniciativas y reasignar fondos "
                        "de campañas de bajo rendimiento. Solicitar ampliación a finanzas."
                    ),
                    "tipo": "estrategia",
                    "prioridad": 1,
                    "costo_estimado": 0,
                    "roi_proyectado": 0,
                })
            elif pct >= UMBRALES["presupuesto_alerta_pct"]:
                sugerencias.append({
                    "titulo": "Presupuesto de marketing alcanzó nivel de alerta",
                    "descripcion": (
                        f"Gasto actual: {pct:.1f}% (${gastado:,.0f} de ${asignado:,.0f}). "
                        "Se recomienda revisar la efectividad de campañas activas "
                        "y priorizar las de mayor ROI."
                    ),
                    "tipo": "estrategia",
                    "prioridad": 2,
                    "costo_estimado": 0,
                    "roi_proyectado": 0,
                })

    # ─── 2. Pocos conductores vs solicitantes ───
    total_sol = m.get("total_solicitantes", 0) if isinstance(m, dict) else 0
    total_con = m.get("total_conductores", 0) if isinstance(m, dict) else 0
    if total_sol > 0 and total_con > 0:
        ratio = total_con / total_sol
        if ratio < UMBRALES["ratio_conductores_solicitantes_min"]:
            deficit = int(total_sol * UMBRALES["ratio_conductores_solicitantes_min"] - total_con)
            sugerencias.append({
                "titulo": f"🚨 Déficit de conductores: faltan ~{deficit}",
                "descripcion": (
                    f"Ratio actual: {ratio:.2%} conductores/solicitantes "
                    f"(mínimo recomendado: {UMBRALES['ratio_conductores_solicitantes_min']:.0%}). "
                    f"Hay {total_sol} solicitantes y solo {total_con} conductores. "
                    "Se recomienda campaña de captación de conductores con incentivo "
                    "económico (bono de bienvenida)."
                ),
                "tipo": "campana",
                "prioridad": 1,
                "costo_estimado": deficit * 5000,  # ~$5000 por conductor captado
                "roi_proyectado": 300,  # cada conductor genera ~3x en viajes
            })

    # ─── 3. Campañas en borrador hace mucho ───
    for c in campanas_borrador:
        creada = c.get("created_at", "")
        if creada:
            dias = (datetime.now() - datetime.fromisoformat(creada.replace("Z", "+00:00"))).days
            if dias > UMBRALES["campanas_inactivas_dias"]:
                sugerencias.append({
                    "titulo": f"📋 Campaña '{c.get('nombre')}' lleva {dias} días en borrador",
                    "descripcion": (
                        f"La campaña '{c.get('nombre')}' ({c.get('tipo')}) "
                        f"fue creada hace {dias} días y sigue en borrador. "
                        "Se recomienda activarla, ajustarla o archivarla."
                    ),
                    "tipo": "campana",
                    "prioridad": 4,
                    "costo_estimado": 0,
                    "roi_proyectado": 0,
                })

    # ─── 4. Sin campañas activas ───
    if not campanas_activas:
        sugerencias.append({
            "titulo": "📢 No hay campañas de marketing activas",
            "descripcion": (
                "Actualmente no hay campañas en ejecución. Se recomienda activar "
                "al menos una campaña de adquisición o retención. Sugerencias:\n"
                "• Campaña de referidos: 'Traé un amigo, ganá $X'\n"
                "• Push notification a usuarios inactivos\n"
                "• Promoción geográfica en zona de alta demanda"
            ),
            "tipo": "campana",
            "prioridad": 2,
            "costo_estimado": 15000,
            "roi_proyectado": 200,
        })

    # ─── 5. Pocos viajes → campaña de activación ───
    if viajes_30d < 50:  # umbral bajo para arranque
        sugerencias.append({
            "titulo": "🎯 Baja actividad: campaña de activación recomendada",
            "descripcion": (
                f"Solo se registraron {viajes_30d} viajes en los últimos 30 días. "
                "Estrategia sugerida:\n"
                "• Primer viaje con 50% de descuento\n"
                "• Radio de 3km alrededor de zonas comerciales\n"
                "• Duración: 2 semanas, horario pico 17-20h"
            ),
            "tipo": "promocion",
            "prioridad": 1,
            "costo_estimado": 25000,
            "roi_proyectado": 150,
            "metadata": {
                "descuento": 50,
                "radio_km": 3,
                "duracion_dias": 14,
                "horario": "17:00-20:00",
            },
        })

    # ─── 6. Sin promociones activas ───
    if not promos:
        sugerencias.append({
            "titulo": "💡 Activar promociones geográficas en zonas estratégicas",
            "descripcion": (
                "No hay promociones geográficas activas. Se recomienda crear "
                "una promoción en zonas de alta densidad (centros comerciales, "
                "universidades, estaciones de tren) para incentivar viajes cortos."
            ),
            "tipo": "promocion",
            "prioridad": 3,
            "costo_estimado": 10000,
            "roi_proyectado": 250,
        })

    # ─── 7. Demasiadas sugerencias pendientes ───
    if len(pendientes) > 5:
        sugerencias.append({
            "titulo": f"📬 Hay {len(pendientes)} sugerencias esperando revisión del CEO",
            "descripcion": (
                f"Acumuladas {len(pendientes)} sugerencias sin resolver. "
                "Se recomienda revisar y priorizar para no frenar iniciativas."
            ),
            "tipo": "estrategia",
            "prioridad": 3,
            "costo_estimado": 0,
            "roi_proyectado": 0,
        })

    return sugerencias


# ============================================
# INSERCIÓN EN SUPABASE
# ============================================

def insertar_sugerencias(supabase: Client, sugerencias: list[dict]) -> list[str]:
    """Inserta sugerencias en la tabla y retorna los números generados."""
    numeros = []
    for sug in sugerencias:
        try:
            # Generar número único
            anio = datetime.now().year
            resp = supabase.table("sugerencias_cmo").select("numero_unico") \
                .ilike("numero_unico", f"CMO-{anio}-%") \
                .order("numero_unico", ascending=False).limit(1).execute()
            
            last = resp.data[0]["numero_unico"] if resp.data else None
            next_num = int(last.split("-")[2]) + 1 if last else 1
            numero = f"CMO-{anio}-{str(next_num).zfill(4)}"
            
            payload = {
                "numero_unico": numero,
                "titulo": sug["titulo"],
                "descripcion": sug["descripcion"],
                "tipo": sug["tipo"],
                "estado": "pendiente",
                "prioridad": sug.get("prioridad", 3),
                "origen": "agente",
                "costo_estimado": sug.get("costo_estimado", 0),
                "roi_proyectado": sug.get("roi_proyectado", 0),
                "impacto_estimado": sug.get("impacto_estimado", ""),
                "metadata": sug.get("metadata", {}),
            }
            
            resp = supabase.table("sugerencias_cmo").insert(payload).execute()
            numeros.append(numero)
            print(f"  ✅ {numero}: {sug['titulo'][:80]}")
        except Exception as e:
            print(f"  ❌ Error insertando sugerencia '{sug['titulo'][:60]}': {e}")
    
    return numeros


# ============================================
# MAIN
# ============================================

def main():
    parser = argparse.ArgumentParser(description="Agente CMO Autónomo - Rutmy")
    parser.add_argument("--dry-run", action="store_true", help="Solo analizar, no insertar")
    args = parser.parse_args()

    print("=" * 60)
    print("🧠 AGENTE CMO — Rutmy")
    print(f"   Ejecución: {datetime.now().strftime('%Y-%m-%d %H:%M')}")
    print(f"   Modo: {'ANÁLISIS (dry-run)' if args.dry_run else 'COMPLETO'}")
    print("=" * 60)

    # 1. Conectar
    print("\n📡 Conectando a Supabase...")
    supabase = get_supabase()
    print("   ✅ Conectado")

    # 2. Obtener métricas
    print("\n📊 Obteniendo métricas...")
    metricas = obtener_metricas(supabase)
    
    m = metricas.get("metricas", {})
    print(f"   Solicitantes: {m.get('total_solicitantes', '?')} | Conductores: {m.get('total_conductores', '?')}")
    print(f"   Viajes 30d: {metricas.get('viajes_30d', '?')} | Viajes 7d: {metricas.get('viajes_7d', '?')}")
    print(f"   Nuevos 7d: {metricas.get('nuevos_solicitantes_7d', '?')} sol. / {metricas.get('nuevos_conductores_7d', '?')} cond.")
    print(f"   Promos activas: {len(metricas.get('promociones_activas', []))}")
    print(f"   Campañas activas: {len(metricas.get('campanas_activas', []))} | Borrador: {len(metricas.get('campanas_borrador', []))}")

    presup = metricas.get("presupuesto")
    if presup:
        asignado = float(presup.get("presupuesto_asignado", 0))
        gastado = float(presup.get("gasto_actual", 0))
        pct = (gastado / asignado * 100) if asignado > 0 else 0
        print(f"   Presupuesto: ${gastado:,.0f} / ${asignado:,.0f} ({pct:.1f}%)")

    # 3. Analizar y generar sugerencias
    print("\n🔍 Analizando y generando sugerencias...")
    sugerencias = analizar_y_generar(metricas)
    
    if not sugerencias:
        print("   ✅ Todo en orden. No se requieren acciones.")
        return

    print(f"   📋 {len(sugerencias)} sugerencia(s) generada(s):\n")
    for i, s in enumerate(sugerencias, 1):
        print(f"   [{s['prioridad']}] {s['titulo']}")
        print(f"       Tipo: {s['tipo']} | Costo est: ${s.get('costo_estimado', 0):,.0f} | ROI proy: {s.get('roi_proyectado', 0)}%")
        print()

    # 4. Insertar (si no es dry-run)
    if args.dry_run:
        print("🏁 Dry-run completado. No se insertaron sugerencias.")
    else:
        print("💾 Insertando sugerencias en Supabase...")
        numeros = insertar_sugerencias(supabase, sugerencias)
        print(f"\n✅ {len(numeros)} sugerencias insertadas: {', '.join(numeros)}")
        print("🔔 El CEO recibirá notificaciones de aprobación.")

    print("\n" + "=" * 60)
    print("🏁 Agente CMO finalizado")
    print("=" * 60)


if __name__ == "__main__":
    main()
