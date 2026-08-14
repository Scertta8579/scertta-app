# FASE 4 y 5 — Estructura de Ejecución Automatizada

**Inicio:** 23 junio 2026 · 14:45  
**Estrategia:** Modular, no destructiva, acumulativa  
**Estado:** 🟢 EN EJECUCIÓN

---

## 📂 Archivos creados

```
scripts/
├── bypass-login.sh              ← Bypass login 1-clic para Andres
└── stress-test/
    ├── fase4_stress_test.py     ← Simulador de carga masiva
    └── fase5_verify_rls.py      ← Verificador de RLS + constraints

deploy/
└── ecosystem.config.json        ← PM2 deploy config (rutmy-admin + valhalla + martin)

reports/
├── fase4_stress_report.txt      ← Reporte técnico (se genera al finalizar)
└── fase4_stress_raw.json        ← Datos crudos para análisis
```

---

## FASE 4 — Stress Test en Ejecución

### Carga lanzada:
| Actor | Cantidad | Operación | Tabla/API |
|---|---|---|---|
| 🚛 Camiones | 50 | Ofertas en tiempo real | `b2b_ofertas` |
| 🚗 Pasajeros | 200 | Solicitudes de viaje | `viajes` |
| 🏭 Empresas | 10×20 | Consultas ruteo | Valhalla `:8002/route` |
| 📊 Tracking | 50 | Registro consumo API | `b2b_consumo_api` |

### Métricas capturadas:
- RAM (pico, promedio)
- CPU (pico, promedio)
- Latencia P50/P95 para cada tipo de operación
- Errores y tasa de éxito
- Estabilidad ZimaOS

---

## FASE 5 — Verificación Completada ✅

### RLS: 176 políticas activas en 93 tablas
```
✅ Core tables (10/10): RLS + políticas verificadas
✅ Constraints (3/3): frecuencia semanal, flujo_tipo, FK cierres
✅ Integridad: 0 registros huérfanos en b2b_consumo_api y b2b_ofertas
✅ Notificaciones: 9 en bandeja (sistema funcional)
```

### Bypass Login
```bash
bash /DATA/AppData/scertta_workspace/scertta-app/scripts/bypass-login.sh
```
- Autentica como `scertta.principal@gmail.com` vía Supabase Auth API
- Genera página HTML que setea session en localStorage
- Redirige automáticamente a `/ceo-dashboard`
- 12 pestañas listas para recorrer visualmente

---

## ⏳ Próximo: Reporte de Stress Test

El simulador está corriendo. En ~2 minutos se generará:
- `reports/fase4_stress_report.txt` — legible para Andres
- `reports/fase4_stress_raw.json` — datos para análisis

Se notificará automáticamente al finalizar.
