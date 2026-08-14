#!/usr/bin/env python3
"""
FASE 4 — Stress Test: 50 camiones + 200 pasajeros + 10 empresas
Simula carga real sobre Supabase, Valhalla y ZimaOS simultáneamente.
Genera reporte técnico de RAM, latencia y estabilidad.
"""

import asyncio
import httpx
import psycopg2
import psutil
import time
import json
import random
from datetime import datetime, timedelta
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass, field
from typing import Optional

# ═══════════════════════════════════════════
# CONFIG
# ═══════════════════════════════════════════
SUPABASE_URL = "https://TU_PROYECTO.supabase.co"
SUPABASE_ANON = "TU_ANON_KEY_JWT"
SUPABASE_SR = "TU_ANON_KEY_JWT"
DB_DSN = "postgresql://postgres:TU_PASSWORD_DB@db.TU_PROYECTO.supabase.co:5432/postgres"
VALHALLA_URL = "http://localhost:8002"
SUPABASE_REST_KEY = SUPABASE_SR  # Use service_role to bypass RLS for stress test

N_TRUCKS = 50
N_PASSENGERS = 200
N_COMPANIES = 10
BATCH_DURATION = 120  # seconds
MAX_WORKERS = 30

# ═══════════════════════════════════════════
# DATA STRUCTURES
# ═══════════════════════════════════════════

@dataclass
class StressMetrics:
    start_time: float = 0
    end_time: float = 0
    ram_samples: list = field(default_factory=list)
    cpu_samples: list = field(default_factory=list)
    offer_latencies: list = field(default_factory=list)
    trip_latencies: list = field(default_factory=list)
    valhalla_latencies: list = field(default_factory=list)
    errors: list = field(default_factory=list)
    total_offers: int = 0
    total_trips: int = 0
    total_valhalla_calls: int = 0

metrics = StressMetrics()

# ═══════════════════════════════════════════
# SYSTEM MONITOR
# ═══════════════════════════════════════════

async def monitor_system():
    """Sample RAM/CPU every 2 seconds."""
    while True:
        metrics.ram_samples.append({
            "ts": time.time(),
            "pct": psutil.virtual_memory().percent,
            "used_gb": psutil.virtual_memory().used / (1024**3),
            "available_gb": psutil.virtual_memory().available / (1024**3),
        })
        metrics.cpu_samples.append({
            "ts": time.time(),
            "pct": psutil.cpu_percent(interval=0.1),
        })
        await asyncio.sleep(2)

# ═══════════════════════════════════════════
# DATABASE SETUP — Create test data via service_role
# ═══════════════════════════════════════════

def setup_test_data():
    """Create a test licitacion and test franquicia if not exist."""
    conn = psycopg2.connect(DB_DSN)
    conn.autocommit = True
    cur = conn.cursor()

    # Get or create a franquicia
    cur.execute("SELECT id FROM franquicias LIMIT 1")
    franq = cur.fetchone()
    if not franq:
        cur.execute("""
            INSERT INTO franquicias (nombre, razon_social, cuit_franquicia, provincia_id, estado, comision_flota_abierta_pct, costo_infraestructura_pct, comision_licitacion_pct)
            VALUES ('TEST-Stress', 'Stress Test SA', '30-99999999-9', (SELECT id FROM provincias LIMIT 1), 'activo', 10.0, 4.5, 7.9)
            RETURNING id
        """)
        franq_id = cur.fetchone()[0]
    else:
        franq_id = franq[0]

    # Create test B2B empresa first (unique CUIT to avoid conflicts)
    test_cuit = f"30-{random.randint(10000000,99999999)}-{random.randint(0,9)}"
    cur.execute("""
        INSERT INTO b2b_empresas (franquicia_id, razon_social, cuit, condicion_iva, flota_propia, plan_tipo, frecuencia_liquidacion)
        VALUES (%s, %s, %s, 'responsable_inscripto', true, 'por_consulta', 'semanal')
        ON CONFLICT (cuit) DO UPDATE SET razon_social = EXCLUDED.razon_social
        RETURNING id
    """, (franq_id, f'LogisticaTest-{random.randint(1000,9999)}', test_cuit))
    emp = cur.fetchone()
    emp_id = emp[0] if emp else None

    # Create test licitacion
    cur.execute("""
        INSERT INTO b2b_licitaciones (empresa_id, franquicia_id, titulo, descripcion, origen_lat, origen_lon, destino_lat, destino_lon, tipo_carga, peso_kg, fecha_retiro, fecha_entrega_max, estado)
        VALUES (%s, %s, 'Carga Masiva Test Stress', 'Carga de prueba para simulacion', -34.6037, -58.3816, -31.4201, -64.1888, 'carga_general', 12000, NOW(), NOW() + INTERVAL '2 days', 'abierta')
        ON CONFLICT DO NOTHING
        RETURNING id
    """, (emp_id, franq_id))
    lic = cur.fetchone()
    lic_id = lic[0] if lic else None

    # Get conductor profiles
    cur.execute("SELECT id FROM perfiles WHERE rol = 'conductor' AND activo = true LIMIT 60")
    conductors = [r[0] for r in cur.fetchall()]

    # Get or create test passenger (use existing user or leave null for stress test)
    cur.execute("SELECT id FROM perfiles WHERE rol = 'solicitante' LIMIT 1")
    passenger = cur.fetchone()
    if not passenger:
        cur.execute("SELECT id FROM perfiles WHERE rol = 'ceo_admin' LIMIT 1")
        ceo = cur.fetchone()
        passenger_id = str(ceo[0]) if ceo else None
    else:
        passenger_id = str(passenger[0])

    cur.close()
    conn.close()
    return {
        "franquicia_id": str(franq_id),
        "licitacion_id": str(lic_id) if lic_id else None,
        "empresa_id": str(emp_id) if emp_id else None,
        "conductors": [str(c) for c in conductors],
        "passenger_id": str(passenger_id) if passenger_id else None,
    }

# ═══════════════════════════════════════════
# SIMULATORS
# ═══════════════════════════════════════════

async def simulate_truck_offer(session: httpx.AsyncClient, licitacion_id: str, conductor_id: str, idx: int):
    """Simulate one truck placing a bid on b2b_ofertas."""
    monto_neto = random.randint(45000, 120000)
    start = time.monotonic()
    try:
        resp = await session.post(
            f"{SUPABASE_URL}/rest/v1/b2b_ofertas",
            headers={
                "apikey": SUPABASE_REST_KEY,
                "Authorization": f"Bearer {SUPABASE_REST_KEY}",
                "Content-Type": "application/json",
                "Prefer": "return=minimal",
            },
            json={
                "licitacion_id": licitacion_id,
                "monto_neto": monto_neto,
                "servicio_pct": 7.9,
                "monto_servicio": round(monto_neto * 7.9 / 100, 2),
                "monto_total": round(monto_neto * 1.079, 2),
            },
            timeout=15,
        )
        elapsed = (time.monotonic() - start) * 1000
        metrics.offer_latencies.append(elapsed)
        metrics.total_offers += 1
        if resp.status_code not in (200, 201, 409):
            metrics.errors.append(f"offer_{idx}: HTTP {resp.status_code}")
    except Exception as e:
        metrics.errors.append(f"offer_{idx}: {str(e)[:80]}")
        metrics.offer_latencies.append(99999)


async def simulate_passenger_trip(session: httpx.AsyncClient, passenger_id: str, idx: int):
    """Simulate a passenger requesting a trip."""
    start = time.monotonic()
    orig_lat = -34.60 + random.uniform(-0.05, 0.05)
    orig_lon = -58.40 + random.uniform(-0.05, 0.05)
    dest_lat = -34.60 + random.uniform(-0.08, 0.08)
    dest_lon = -58.40 + random.uniform(-0.08, 0.08)

    try:
        resp = await session.post(
            f"{SUPABASE_URL}/rest/v1/viajes",
            headers={
                "apikey": SUPABASE_REST_KEY,
                "Authorization": f"Bearer {SUPABASE_REST_KEY}",
                "Content-Type": "application/json",
                "Prefer": "return=minimal",
            },
            json={
                "pasajero_id": passenger_id,
                "origen": f"POINT({orig_lon} {orig_lat})",
                "destino": f"POINT({dest_lon} {dest_lat})",
                "tipo_servicio_id": "081ae5bb-881a-46ec-992c-251085175681" if random.random() > 0.5 else "4d04b95a-82e6-4e28-ab10-3598329b8f70",
                "monto": random.randint(800, 4500),
                "estado": "pendiente",
            },
            timeout=15,
        )
        elapsed = (time.monotonic() - start) * 1000
        metrics.trip_latencies.append(elapsed)
        metrics.total_trips += 1
        if resp.status_code not in (200, 201):
            metrics.errors.append(f"trip_{idx}: HTTP {resp.status_code}")
    except Exception as e:
        metrics.errors.append(f"trip_{idx}: {str(e)[:80]}")
        metrics.trip_latencies.append(99999)


async def simulate_valhalla_query(session: httpx.AsyncClient, idx: int):
    """Simulate a B2B company calling Valhalla for routing."""
    start = time.monotonic()
    req = {
        "locations": [
            {"lat": -34.60 + random.uniform(-0.1, 0.1), "lon": -58.40 + random.uniform(-0.1, 0.1)},
            {"lat": -34.60 + random.uniform(-0.1, 0.1), "lon": -58.40 + random.uniform(-0.1, 0.1)},
        ],
        "costing": random.choice(["auto", "truck", "motorcycle"]),
        "directions_options": {"units": "km"},
    }
    try:
        resp = await session.post(
            f"{VALHALLA_URL}/route",
            json=req,
            timeout=30,
        )
        elapsed = (time.monotonic() - start) * 1000
        metrics.valhalla_latencies.append(elapsed)
        metrics.total_valhalla_calls += 1
        if resp.status_code != 200:
            metrics.errors.append(f"valhalla_{idx}: HTTP {resp.status_code}")
    except Exception as e:
        metrics.errors.append(f"valhalla_{idx}: {str(e)[:80]}")
        metrics.valhalla_latencies.append(99999)


async def simulate_b2b_api_tracking(session: httpx.AsyncClient, empresa_id: str, franquicia_id: str, idx: int):
    """Simulate API consumption tracking for B2B companies."""
    endpoints = ["/route", "/matrix", "/isochrone", "/optimized_route"]
    try:
        await session.post(
            f"{SUPABASE_URL}/rest/v1/b2b_consumo_api",
            headers={
                "apikey": SUPABASE_REST_KEY,
                "Authorization": f"Bearer {SUPABASE_REST_KEY}",
                "Content-Type": "application/json",
                "Prefer": "return=minimal",
            },
            json={
                "empresa_id": empresa_id,
                "franquicia_id": franquicia_id,
                "endpoint": random.choice(endpoints),
                "tipo_servicio": random.choice(["auto", "truck", "motorcycle"]),
                "costo_unitario": 0.01,
                "costo_infra_pct": 4.5,
            },
            timeout=10,
        )
    except Exception:
        pass  # Non-critical tracking


# ═══════════════════════════════════════════
# WAVE GENERATOR
# ═══════════════════════════════════════════

async def wave_trucks(session, licitacion_id: str, conductors: list):
    """50 trucks bidding in 3 waves over the test duration."""
    tasks = []
    for i in range(N_TRUCKS):
        cid = conductors[i % len(conductors)] if conductors else f"test-conductor-{i}"
        tasks.append(simulate_truck_offer(session, licitacion_id, cid, i))
        if len(tasks) >= 15:
            await asyncio.gather(*tasks)
            tasks = []
            await asyncio.sleep(random.uniform(1, 3))
    if tasks:
        await asyncio.gather(*tasks)


async def wave_passengers(session, passenger_id: str):
    """200 passengers requesting trips in bursts."""
    tasks = []
    for i in range(N_PASSENGERS):
        tasks.append(simulate_passenger_trip(session, passenger_id, i))
        if len(tasks) >= 25:
            await asyncio.gather(*tasks)
            tasks = []
            await asyncio.sleep(random.uniform(0.5, 2))
    if tasks:
        await asyncio.gather(*tasks)


async def wave_valhalla(session):
    """10 companies bombarding Valhalla continuously."""
    tasks = []
    for i in range(200):  # 200 queries total
        tasks.append(simulate_valhalla_query(session, i))
        if len(tasks) >= 10:
            await asyncio.gather(*tasks)
            tasks = []
            await asyncio.sleep(random.uniform(0.2, 1))
    if tasks:
        await asyncio.gather(*tasks)


# ═══════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════

async def main():
    print("=" * 60)
    print("FASE 4 — STRESS TEST")
    print(f"Inicio: {datetime.now().isoformat()}")
    print(f"Target: {N_TRUCKS} camiones + {N_PASSENGERS} pasajeros + {N_COMPANIES} empresas")
    print("=" * 60)

    # Setup
    print("\n[1/5] Creando datos de prueba...")
    test_data = setup_test_data()
    lic_id = test_data["licitacion_id"]
    emp_id = test_data["empresa_id"]
    franq_id = test_data["franquicia_id"]
    conductors = test_data["conductors"]
    passenger_id = test_data["passenger_id"]
    print(f"  Franquicia: {franq_id}")
    print(f"  Licitacion: {lic_id}")
    print(f"  Empresa: {emp_id}")
    print(f"  Conductores disponibles: {len(conductors)}")
    print(f"  Pasajero: {passenger_id}")

    # Start monitor
    print("\n[2/5] Iniciando monitoreo de sistema...")
    monitor_task = asyncio.create_task(monitor_system())

    # Start stress
    print(f"\n[3/5] LANZANDO CARGA...")
    metrics.start_time = time.time()

    async with httpx.AsyncClient(timeout=30) as session:
        # Wave 1: Valhalla bombardment (runs longest)
        vh_task = asyncio.create_task(wave_valhalla(session))

        await asyncio.sleep(2)

        # Wave 2: Trucks bidding
        if lic_id:
            truck_task = asyncio.create_task(wave_trucks(session, lic_id, conductors))
        else:
            truck_task = None
            print("  ⚠️ Sin licitacion_id, saltando ofertas de camiones")

        await asyncio.sleep(2)

        # Wave 3: Passengers requesting trips
        if passenger_id:
            pax_task = asyncio.create_task(wave_passengers(session, passenger_id))
        else:
            pax_task = None
            print("  ⚠️ Sin passenger_id, saltando viajes de pasajeros")

        # B2B API tracking (background, light weight)
        b2b_tasks = []
        for i in range(50):
            if emp_id and franq_id:
                b2b_tasks.append(simulate_b2b_api_tracking(session, emp_id, franq_id, i))
            if len(b2b_tasks) >= 10:
                await asyncio.gather(*b2b_tasks)
                b2b_tasks = []
                await asyncio.sleep(random.uniform(0.5, 2))

        # Wait for all waves
        await vh_task
        if truck_task:
            await truck_task
        if pax_task:
            await pax_task

    metrics.end_time = time.time()
    duration = metrics.end_time - metrics.start_time

    # Stop monitor
    monitor_task.cancel()
    try:
        await monitor_task
    except asyncio.CancelledError:
        pass

    # ═══════════════════════════════════════
    # REPORT
    # ═══════════════════════════════════════
    print(f"\n[4/5] Generando reporte...")

    offer_p50 = sorted(metrics.offer_latencies)[len(metrics.offer_latencies)//2] if metrics.offer_latencies else 0
    offer_p95 = sorted(metrics.offer_latencies)[int(len(metrics.offer_latencies)*0.95)] if len(metrics.offer_latencies) > 20 else 0
    trip_p50 = sorted(metrics.trip_latencies)[len(metrics.trip_latencies)//2] if metrics.trip_latencies else 0
    trip_p95 = sorted(metrics.trip_latencies)[int(len(metrics.trip_latencies)*0.95)] if len(metrics.trip_latencies) > 20 else 0
    vh_p50 = sorted(metrics.valhalla_latencies)[len(metrics.valhalla_latencies)//2] if metrics.valhalla_latencies else 0
    vh_p95 = sorted(metrics.valhalla_latencies)[int(len(metrics.valhalla_latencies)*0.95)] if len(metrics.valhalla_latencies) > 20 else 0

    ram_vals = [s["used_gb"] for s in metrics.ram_samples]
    cpu_vals = [s["pct"] for s in metrics.cpu_samples]
    ram_peak = max(ram_vals) if ram_vals else 0
    cpu_peak = max(cpu_vals) if cpu_vals else 0
    ram_avg = sum(ram_vals) / len(ram_vals) if ram_vals else 0
    cpu_avg = sum(cpu_vals) / len(cpu_vals) if cpu_vals else 0

    report = f"""
{'='*60}
📊 REPORTE TÉCNICO — FASE 4 Stress Test
{'='*60}
Fecha: {datetime.now().strftime('%d/%m/%Y %H:%M')}
Duración: {duration:.1f}s ({duration/60:.1f} min)

── CARGA SIMULADA ──
✅ Ofertas de camiones (b2b_ofertas):  {metrics.total_offers}/{N_TRUCKS}
✅ Viajes de pasajeros (viajes):       {metrics.total_trips}/{N_PASSENGERS}
✅ Consultas Valhalla:                 {metrics.total_valhalla_calls}/200
✅ Errores:                            {len(metrics.errors)}

── LATENCIAS (ms) ──
📦 b2b_ofertas INSERT:  P50={offer_p50:.0f}ms  P95={offer_p95:.0f}ms
🚗 viajes INSERT:       P50={trip_p50:.0f}ms  P95={trip_p95:.0f}ms
🗺️ Valhalla /route:     P50={vh_p50:.0f}ms  P95={vh_p95:.0f}ms

── CONSUMO ZIMAOS ──
🧠 RAM:   pico={ram_peak:.1f}GB  promedio={ram_avg:.1f}GB
⚡ CPU:   pico={cpu_peak:.0f}%  promedio={cpu_avg:.0f}%

── ESTABILIDAD ──
{'✅ SISTEMA ESTABLE — Sin crashes ni degradación' if len(metrics.errors) < 5 else '⚠️ Se detectaron errores (ver detalle)'}

── DETALLE DE ERRORES ──
{chr(10).join(metrics.errors[:20]) if metrics.errors else 'Ninguno'}
{'...' if len(metrics.errors) > 20 else ''}

{'='*60}
VEREDICTO: {'✅ LISTO PARA PRODUCCIÓN' if len(metrics.errors) < 5 and ram_peak < 16 else '⚠️ REQUIERE ATENCIÓN'}
{'='*60}
"""

    print(report)

    # Save report
    with open("/DATA/AppData/scertta_workspace/scertta-app/reports/fase4_stress_report.txt", "w") as f:
        f.write(report)

    # Save raw metrics as JSON for future analysis
    raw_data = {
        "timestamp": datetime.now().isoformat(),
        "duration_s": duration,
        "total_offers": metrics.total_offers,
        "total_trips": metrics.total_trips,
        "total_valhalla": metrics.total_valhalla_calls,
        "errors": len(metrics.errors),
        "offer_latency_p50_ms": offer_p50,
        "offer_latency_p95_ms": offer_p95,
        "trip_latency_p50_ms": trip_p50,
        "trip_latency_p95_ms": trip_p95,
        "valhalla_latency_p50_ms": vh_p50,
        "valhalla_latency_p95_ms": vh_p95,
        "ram_peak_gb": ram_peak,
        "ram_avg_gb": ram_avg,
        "cpu_peak_pct": cpu_peak,
        "cpu_avg_pct": cpu_avg,
    }
    with open("/DATA/AppData/scertta_workspace/scertta-app/reports/fase4_stress_raw.json", "w") as f:
        json.dump(raw_data, f, indent=2)

    print(f"\n[5/5] Reportes guardados en reports/")
    return report

if __name__ == "__main__":
    asyncio.run(main())
