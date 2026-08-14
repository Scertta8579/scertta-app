#!/usr/bin/env python3
"""
🚀 SUPER STRESS TEST X5 — Scertta/Rutmy
═══════════════════════════════════════════════════════════
Carga: 5× el test anterior → 1250 actores simultáneos
  • 250 camiones ofertando en b2b_ofertas
  • 500 pasajeros solicitando viajes
  • 50 empresas bombardeando Valhalla (500 consultas)
  • 50 usuarios registrándose en test_convergencia (simula apagón)

Ejecución: python3 x5_super_stress.py
Métricas: RAM, CPU, latencias P50/P95/P99, errores
═══════════════════════════════════════════════════════════
"""

import asyncio, httpx, psutil, time, json, random
from datetime import datetime
from dataclasses import dataclass, field

# ═══ CONFIG ═══
SUPABASE_URL = "https://TU_PROYECTO.supabase.co"
SR_KEY = "TU_ANON_KEY_JWT"
VALHALLA_URL = "http://localhost:8002"
ANON_KEY = "TU_ANON_KEY_JWT"

N_TRUCKS = 250
N_PASSENGERS = 500
N_VALHALLA = 500
N_REGISTRATIONS = 50
MAX_CONCURRENT = 50

TIPO_SERVICIO_IDS = ["081ae5bb-881a-46ec-992c-251085175681", "4d04b95a-82e6-4e28-ab10-3598329b8f70"]
PASSENGER_ID = "1b8960c3-fc45-40be-b9ca-19c6401c2008"

@dataclass
class Metrics:
    ram_samples: list = field(default_factory=list)
    cpu_samples: list = field(default_factory=list)
    offer_latencies: list = field(default_factory=list)
    trip_latencies: list = field(default_factory=list)
    valhalla_latencies: list = field(default_factory=list)
    errors: list = field(default_factory=list)
    total_offers: int = 0
    total_trips: int = 0
    total_valhalla: int = 0
    total_registrations: int = 0

m = Metrics()

async def monitor():
    while True:
        m.ram_samples.append({"ts": time.time(), "used_gb": psutil.virtual_memory().used/(1024**3), "pct": psutil.virtual_memory().percent})
        m.cpu_samples.append({"ts": time.time(), "pct": psutil.cpu_percent(interval=0.1)})
        await asyncio.sleep(1)

async def truck_offer(session, idx):
    t0 = time.monotonic()
    try:
        resp = await session.post(f"{SUPABASE_URL}/rest/v1/b2b_ofertas", headers={
            "apikey": SR_KEY, "Authorization": f"Bearer {SR_KEY}",
            "Content-Type": "application/json", "Prefer": "return=minimal"
        }, json={
            "monto_neto": random.randint(45000,120000), "servicio_pct": 7.9,
            "monto_servicio": round(random.randint(45000,120000)*7.9/100,2),
            "monto_total": round(random.randint(45000,120000)*1.079,2)
        }, timeout=10)
        m.offer_latencies.append((time.monotonic()-t0)*1000)
        m.total_offers += 1
        if resp.status_code not in (200,201): m.errors.append(f"offer_{idx}:{resp.status_code}")
    except Exception as e: m.errors.append(f"offer_{idx}:{str(e)[:60]}")

async def passenger_trip(session, idx):
    t0 = time.monotonic()
    lat, lon = -34.60+random.uniform(-.05,.05), -58.40+random.uniform(-.05,.05)
    dlat, dlon = -34.60+random.uniform(-.08,.08), -58.40+random.uniform(-.08,.08)
    try:
        resp = await session.post(f"{SUPABASE_URL}/rest/v1/viajes", headers={
            "apikey": SR_KEY, "Authorization": f"Bearer {SR_KEY}",
            "Content-Type": "application/json", "Prefer": "return=minimal"
        }, json={
            "pasajero_id": PASSENGER_ID,
            "origen": f"POINT({lon} {lat})", "destino": f"POINT({dlon} {dlat})",
            "tipo_servicio_id": random.choice(TIPO_SERVICIO_IDS),
            "monto": random.randint(800,4500), "estado": "pendiente"
        }, timeout=10)
        m.trip_latencies.append((time.monotonic()-t0)*1000)
        m.total_trips += 1
        if resp.status_code not in (200,201): m.errors.append(f"trip_{idx}:{resp.status_code}")
    except Exception as e: m.errors.append(f"trip_{idx}:{str(e)[:60]}")

async def valhalla_query(session, idx):
    t0 = time.monotonic()
    try:
        resp = await session.post(f"{VALHALLA_URL}/route", json={
            "locations": [
                {"lat": -34.60+random.uniform(-.1,.1), "lon": -58.40+random.uniform(-.1,.1)},
                {"lat": -34.60+random.uniform(-.1,.1), "lon": -58.40+random.uniform(-.1,.1)}
            ], "costing": random.choice(["auto","truck","motorcycle"]),
            "directions_options": {"units":"km"}
        }, timeout=20)
        m.valhalla_latencies.append((time.monotonic()-t0)*1000)
        m.total_valhalla += 1
        if resp.status_code != 200: m.errors.append(f"valhalla_{idx}:{resp.status_code}")
    except Exception as e: m.errors.append(f"valhalla_{idx}:{str(e)[:60]}")

async def register_user(session, idx):
    try:
        resp = await session.post(f"{SUPABASE_URL}/rest/v1/test_convergencia", headers={
            "apikey": ANON_KEY, "Authorization": f"Bearer {ANON_KEY}",
            "Content-Type": "application/json", "Prefer": "return=minimal"
        }, json={
            "origen": "cloud", "mensaje": f"Usuario X5 #{idx} registrado durante tormenta de carga"
        }, timeout=10)
        m.total_registrations += 1
        if resp.status_code not in (200,201): m.errors.append(f"reg_{idx}:{resp.status_code}")
    except Exception as e: m.errors.append(f"reg_{idx}:{str(e)[:60]}")

async def run_wave(session, tasks, batch_size):
    for i in range(0, len(tasks), batch_size):
        batch = tasks[i:i+batch_size]
        await asyncio.gather(*batch)
        await asyncio.sleep(random.uniform(0.1, 0.5))

async def main():
    print("="*60)
    print(f"🚀 SUPER STRESS TEST X5 — {datetime.now().strftime('%H:%M:%S')}")
    print(f"   {N_TRUCKS} camiones + {N_PASSENGERS} pasajeros + {N_VALHALLA} valhalla + {N_REGISTRATIONS} registros")
    print("="*60)

    monitor_task = asyncio.create_task(monitor())
    t0 = time.time()

    async with httpx.AsyncClient(timeout=30, limits=httpx.Limits(max_connections=MAX_CONCURRENT)) as session:
        # Lanzar todas las oleadas en paralelo
        waves = []
        waves.append(run_wave(session, [truck_offer(session, i) for i in range(N_TRUCKS)], 20))
        waves.append(run_wave(session, [passenger_trip(session, i) for i in range(N_PASSENGERS)], 30))
        waves.append(run_wave(session, [valhalla_query(session, i) for i in range(N_VALHALLA)], 15))
        waves.append(run_wave(session, [register_user(session, i) for i in range(N_REGISTRATIONS)], 10))
        await asyncio.gather(*waves)

    duration = time.time() - t0
    monitor_task.cancel()
    try: await monitor_task
    except asyncio.CancelledError: pass

    # ── REPORT ──
    def pct(l, p): return sorted(l)[int(len(l)*p/100)] if l else 0

    print(f"\n{'='*60}")
    print(f"📊 REPORTE SUPER STRESS X5")
    print(f"{'='*60}")
    print(f"✅ Ofertas:     {m.total_offers}/{N_TRUCKS}")
    print(f"✅ Viajes:      {m.total_trips}/{N_PASSENGERS}")
    print(f"✅ Valhalla:    {m.total_valhalla}/{N_VALHALLA}")
    print(f"✅ Registros:   {m.total_registrations}/{N_REGISTRATIONS}")
    print(f"❌ Errores:     {len(m.errors)}")
    print(f"⏱️  Duración:    {duration:.1f}s")
    print(f"\n── LATENCIAS ──")
    print(f"📦 b2b_ofertas:  P50={pct(m.offer_latencies,50):.0f}ms P95={pct(m.offer_latencies,95):.0f}ms P99={pct(m.offer_latencies,99):.0f}ms")
    print(f"🚗 viajes:       P50={pct(m.trip_latencies,50):.0f}ms P95={pct(m.trip_latencies,95):.0f}ms P99={pct(m.trip_latencies,99):.0f}ms")
    print(f"🗺️  Valhalla:     P50={pct(m.valhalla_latencies,50):.0f}ms P95={pct(m.valhalla_latencies,95):.0f}ms P99={pct(m.valhalla_latencies,99):.0f}ms")
    ram_vals = [s["used_gb"] for s in m.ram_samples]
    cpu_vals = [s["pct"] for s in m.cpu_samples]
    print(f"\n── ZIMAOS ──")
    print(f"🧠 RAM: pico={max(ram_vals):.1f}GB avg={sum(ram_vals)/len(ram_vals):.1f}GB" if ram_vals else "🧠 RAM: N/A")
    print(f"⚡ CPU: pico={max(cpu_vals):.0f}% avg={sum(cpu_vals)/len(cpu_vals):.0f}%" if cpu_vals else "⚡ CPU: N/A")
    print(f"\n── ERRORES (primeros 10) ──")
    for e in m.errors[:10]: print(f"  • {e}")
    if len(m.errors) > 10: print(f"  ... y {len(m.errors)-10} más")
    
    # Save
    report = {"timestamp": datetime.now().isoformat(), "duration_s": duration,
        "offers": m.total_offers, "trips": m.total_trips, "valhalla": m.total_valhalla,
        "registrations": m.total_registrations, "errors": len(m.errors),
        "offer_p50": pct(m.offer_latencies,50), "offer_p95": pct(m.offer_latencies,95),
        "trip_p50": pct(m.trip_latencies,50), "trip_p95": pct(m.trip_latencies,95),
        "valhalla_p50": pct(m.valhalla_latencies,50), "valhalla_p95": pct(m.valhalla_latencies,95),
        "ram_peak": max(ram_vals) if ram_vals else 0, "cpu_peak": max(cpu_vals) if cpu_vals else 0}
    with open("/DATA/AppData/scertta_workspace/scertta-app/reports/x5_super_stress.json","w") as f:
        json.dump(report, f, indent=2)
    print(f"\n📁 Reporte: reports/x5_super_stress.json")
    print(f"{'='*60}")

if __name__ == "__main__":
    asyncio.run(main())
