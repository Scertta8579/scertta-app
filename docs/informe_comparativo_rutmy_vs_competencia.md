# Informe Comparativo — Rutmy/Scertta vs. Competencia (Uber/DiDi)

> Fuente: `.cursorrules` (Biblia Maestra) y arquitectura oficial Scertta/Rutmy.
> Fecha: 13 de agosto de 2026.

## ⭐ 4 Diferenciadores Clave (imposibles de copiar sin reescribir su arquitectura)

| # | Diferenciador | Rutmy / Scertta | Uber / DiDi |
|---|---------------|-----------------|-------------|
| 1 | **Código Match de 6 dígitos** | Generador alfanumérico en la app del chofer; vincula chofer↔pasajero para solicitudes directas y reservas Push. Si el chofer no acepta, cae al radar general | No existe (todo pasa por el algoritmo central) |
| 2 | **P2P Directo + Transferencia 3.0** | El pasajero paga 100% directo (Efectivo / T3.0 QR / Alias). Cero retención. Comisión cobrada aparte como canon semanal facturado | Retención de tarifa + comisión fija 25–30% |
| 3 | **PWA H3 Multiservicio** | Hexágonos H3 resolución 8 con capas independientes por servicio (Pasajeros Auto/Moto, Envíos Moto, Fletes), pincel de selección múltiple y reglas por zona/servicio/horario | Surge pricing global sin granularidad por servicio |
| 4 | **Costo $0 de infraestructura** | Mapas (MapLibre+Valhalla), ruteo, geocodificación (Nominatim) e IA (Gemma 4) 100% self-hosted | Pagan por uso a Mapbox/Google/AWS |

## Matriz de cobertura (qué cubre la Biblia Maestra vs. qué hace la competencia)

| Dimensión | Rutmy / Scertta | Uber | DiDi |
|-----------|-----------------|------|------|
| **Modelo de cobro** | P2P Directo: pasajero paga 100% al conductor; la plataforma cobra **canon de software % VARIABLE** (según promociones) sobre ingresos brutos, excluyendo propinas/peajes | Comisión fija ~25–30% con retención de tarifa | Comisión ~10–15% con retención |
| **Retención de tarifa** | ❌ Cero retención en el momento del viaje | ✅ Retiene | ✅ Retiene |
| **Facturación fiscal** | ARCA semanal automatizada (Neto + IVA + IIBB), cierre domingo 23:59, emisión lunes | N/A (retención directa) | N/A |
| **Mapas / ruteo** | **Self-hosted 100%**: MapLibre + Valhalla (7 países) + PMTiles/Martin. $0 costo, soberanía de datos | Mapbox/Google propietario (costo por uso) | Mapbox/AMap propietario |
| **Geocodificación** | Self-hosted (Photon/Nominatim), $0 | API propietaria (costo) | API propietaria (costo) |
| **Tarifas dinámicas** | **H3 multiservicio** (resolución 8, ~0.7km²): capas independientes por servicio (Pasajeros Auto/Moto, Envíos Moto, Fletes) | Surge pricing global (sin granularidad por servicio) | Surge pricing por zona |
| **Control de zonas** | Hexágonos H3 + polígonos (Mapbox Draw→MapLibre) + pincel multi-selección | Limitado | Limitado |
| **Arquitectura de negocio** | **B2B SaaS + franquicias provinciales** (llave de franquicia, Panel Hub del gerente, RLS) | Global centralizado | Global centralizado |
| **Infraestructura** | Híbrida: servidor propio (ZimaOS 1TB) + Oracle Cloud (HA). Repetidores | AWS/GCP (cloud) | Cloud |
| **IA / KYC** | Self-hosted: Gemma 4 (ZimaOS) diagnóstico + humano final; Luna (GPT-5.6) validación visual. Auditoría por paso | Cloud propietario | Cloud propietario |
| **Modelo de apps** | 3 apps Flutter (rider/driver/flota) + PWA admin. Dominios de negocio separados (pasajeros ≠ cargas ≠ flota) | 1 app monótona | 1 app |
| **Código Match** | 6 dígitos alfanumérico conductor↔pasajero (reservas/viajes directos) | N/A | N/A |
| **Privacidad/soberanía** | 100% datos en infraestructura propia | Datos en servidores de terceros | Datos en servidores de terceros |

## Ventajas competitivas de Rutmy/Scertta (cubiertas por la Biblia Maestra)

1. **Económica para el conductor**: 0% de retención + canon variable. El conductor cobra el 100% al instante y solo paga canon semanal facturado.
2. **Soberanía total**: mapas, ruteo, geocodificación, IA y datos 100% self-hosted → costo marginal $0 y control absoluto.
3. **Granularidad tarifaria sin igual**: H3 multiservicio permite reglas por celda, servicio y horario (ej. "bajar comisión de envíos a 3% en zona comercial 10–17 hs").
4. **Modelo franquicia**: escalable provincial/multinacional vía franquicias con RLS (cada gerente ve solo su provincia).
5. **Alta disponibilidad real**: ZimaOS (latencia local) + Oracle (failover), con sync mutuo.
6. **Fiscal transparente**: facturación ARCA automatizada desde el detalle de deuda verificado.

## Dónde la competencia sigue siendo referencia

| Área | Brecha a cerrar |
|------|-----------------|
| Densidad de red | Uber/DiDi tienen masa crítica de conductores/pasajeros |
| App pulida en flujos de pago | Integración nativa de wallets/cards (Rutmy prioriza P2P) |
| ETA/traffic en tiempo real | Uber usa datos de tráfico en vivo; Rutmy puede sumarlo a Valhalla |

## Conclusión

La **Biblia Maestra** (`.cursorrules`) cubre de forma **completa y coherente** las 6 dimensiones críticas (idioma/marca, identidad visual, arquitectura B2B/franquicias, infraestructura híbrida, modelo P2P Directo y especificaciones Flutter). El diferenciador estructural de Rutmy/Scertta no es "copiar a la competencia", sino **invertir el modelo económico** (P2P Directo + canon variable) y **poseer toda la pila tecnológica** (mapas, ruteo, geocodificación, IA), lo que Uber/DiDi no pueden replicar sin reescribir su arquitectura.
