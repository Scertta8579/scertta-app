# 📊 Diagramas de Flujo - Sistema VIP y Gestión

## 🎯 1. Flujo de Selección de Plan VIP

```
┌─────────────────────────────────────────────────────────────┐
│                    DRIVER HOME SCREEN                        │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              MAPA A PANTALLA COMPLETA                │   │
│  │                                                       │   │
│  │  [☰ Menu]                        [Juan Pérez]       │   │
│  │                                                       │   │
│  │                                                       │   │
│  │                                                       │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │     [💎 MI PLAN DE TRABAJO]                         │   │ ← CLICK AQUÍ
│  └─────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────┐   │
│  │     [🔌 CONECTARSE]                                 │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│              PLAN SELECTION SCREEN                           │
│                                                              │
│  ← Volver              Plan de Trabajo                      │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  👤 Juan Pérez                                       │   │
│  │  juan@ejemplo.com                                    │   │
│  │  📋 Plan Actual: Plan Comunidad                     │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
│  Elige tu plan de trabajo                                   │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  PLAN COMUNIDAD                              [✓]    │   │
│  │  Ideal para comenzar en la plataforma               │   │
│  │                                                       │   │
│  │  Costo semanal: Gratis                              │   │
│  │  Comisión: 5%                                       │   │
│  │                                                       │   │
│  │  ✓ Acceso completo                                  │   │
│  │  ✓ Soporte comunidad                                │   │
│  │  ✓ Sin costos fijos                                 │   │
│  │                                                       │   │
│  │  [Plan Actual]                                      │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  PLAN VIP                                    [VIP]  │   │
│  │  Para conductores profesionales                      │   │
│  │                                                       │   │
│  │  Costo semanal: $25.000                             │   │
│  │  Comisión: 0% ✨                                    │   │
│  │                                                       │   │
│  │  ✓ 0% de comisión                                   │   │
│  │  ✓ Soporte prioritario 24/7                         │   │
│  │  ✓ Acceso a zonas premium                           │   │
│  │  ✓ Dashboard avanzado                               │   │
│  │  ✓ Pagos semanales                                  │   │
│  │  ✓ Seguro premium                                   │   │
│  │                                                       │   │
│  │  [Seleccionar Plan]  ← CLICK                        │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
│  💡 Comparación Rápida                                      │
│  Ejemplo: Ganas $200.000/semana                             │
│  Plan Comunidad: Pagas $10.000 → Te quedan $190.000        │
│  Plan VIP: Pagas $25.000 → Te quedan $175.000              │
│  💡 VIP es rentable si ganas más de $500.000/semana         │
└─────────────────────────────────────────────────────────────┘
                            ↓
                   [PLAN ACTUALIZADO]
                            ↓
                  Vuelve a Driver Home
```

---

## 💰 2. Flujo de Gestión Financiera (CEO)

```
┌─────────────────────────────────────────────────────────────┐
│                     CEO HOME SCREEN                          │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              MAPA A PANTALLA COMPLETA                │   │
│  │                                                       │   │
│  │  ┌─────────────────────────────────────────────┐   │   │
│  │  │  AUTORIZACIONES PENDIENTES           [▼]    │   │   │
│  │  │  ┌─────────┐ ┌─────────┐ ┌─────────┐       │   │   │
│  │  │  │ Equipo  │ │Conducto-│ │ Socios  │       │   │   │
│  │  │  │    3    │ │  res 5  │ │    2    │       │   │   │
│  │  │  └─────────┘ └─────────┘ └─────────┘       │   │   │
│  │  └─────────────────────────────────────────────┘   │   │
│  │                                                       │   │
│  │                                      [CEO - Admin]   │   │
│  │                                                       │   │
│  │                                                       │   │
│  │                                                       │   │
│  │                                                       │   │
│  │                                                       │   │
│  │                                  [🔥]                │   │
│  │                                  [💵] ← CLICK AQUÍ  │   │
│  │                          [📍 Marcar Zonas]          │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│           GESTIÓN FINANCIERA SCREEN                          │
│                                                              │
│  ← Volver    Gestión Financiera           [🔄] [+]         │
│              Control de costos operativos                    │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │         RESUMEN FINANCIERO                           │   │
│  │                                                       │   │
│  │   💵 Costo Actual        │    📈 Proyectado         │   │
│  │      $53.000             │       $64.500            │   │
│  │                                                       │   │
│  │   ⬆️ Diferencia: +$11.500 (ROJO - ALERTA)           │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
│  TABLA DE COSTOS (scrolleable ↔️ ↕️)                        │
│  ┌────────────────────────────────────────────────────┐    │
│  │ Servicio    │ Actual  │ Proyec. │ Dif.   │ Estado │    │
│  ├────────────────────────────────────────────────────┤    │
│  │ Resend      │ $5.000  │ $8.000  │ +$3k   │ 🟢 [✏️][🗑️] │
│  │ Mapbox      │ $12.000 │ $15.000 │ +$3k   │ 🟢 [✏️][🗑️] │
│  │ Amazon SES  │ $3.000  │ $4.500  │ +$1.5k │ 🟢 [✏️][🗑️] │
│  │ Supabase    │ $25.000 │ $25.000 │ $0     │ 🟢 [✏️][🗑️] │
│  │ Twilio SMS  │ $8.000  │ $12.000 │ +$4k   │ 🟠 [✏️][🗑️] │
│  └────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                            ↓
                  [CLICK EN LÁPIZ ✏️]
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                   EDITAR COSTO                               │
│                                                              │
│  Servicio:        [Resend (Emails)          ]              │
│  Costo Actual:    [$ 6000                   ] ← EDITAR     │
│  Proyectado:      [$ 8000                   ]              │
│  Estado:          [Activo ▼                 ]              │
│  Notas:           [Email transaccional      ]              │
│                   [y marketing              ]              │
│                                                              │
│                    [Cancelar]  [Guardar]                    │
└─────────────────────────────────────────────────────────────┘
                            ↓
                      [GUARDADO]
                            ↓
                  Vuelve a tabla actualizada
```

---

## 🏆 3. Flujo de Logros y Comunidad

```
┌─────────────────────────────────────────────────────────────┐
│                   DRIVER/RIDER HOME                          │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              MAPA A PANTALLA COMPLETA                │   │
│  │                                                       │   │
│  │  [☰ Menu] ← CLICK AQUÍ                              │   │
│  │                                                       │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                    DRAWER - PERFIL                           │
│                                                              │
│  ┌──────┐                                                   │
│  │  JC  │  Juan Carlos Pérez                                │
│  └──────┘  juan@ejemplo.com                                 │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  🏆 LOGROS                                           │   │
│  │                                                       │   │
│  │  📅 Llevas 6 meses en la comunidad Scertta          │   │
│  │  Desde 8 de Septiembre de 2025                      │   │
│  │                                                       │   │
│  │  ┌─────────────┐  ┌─────────────┐                  │   │
│  │  │ 🚕 Viajes   │  │ ⭐ Calif.   │                  │   │
│  │  │     45      │  │    4.8      │                  │   │
│  │  └─────────────┘  └─────────────┘                  │   │
│  │                                                       │   │
│  │  ┌─────────────────────────────────────────────┐   │   │
│  │  │  🎖️ Nivel: INTERMEDIO                       │   │   │
│  │  └─────────────────────────────────────────────┘   │   │
│  │                                                       │   │
│  │  Insignias:                                          │   │
│  │  [Primera semana] [Conductor confiable]             │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  💎 Mi Plan de Trabajo                       →      │   │
│  │  Gestiona tu suscripción                            │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  📄 Mis Documentos                           →      │   │
│  │  DNI, Licencia, Antecedentes                        │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  🚗 Cerrar Sesión                                   │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## 🤖 4. Flujo de Validación de Documentos con IA

```
┌─────────────────────────────────────────────────────────────┐
│                 CONDUCTOR CARGA DNI                          │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│              IA EXTRAE DATOS (OCR)                           │
│                                                              │
│  Datos Extraídos:                                           │
│  - Nombre: "JUAN CARLOS"                                    │
│  - Apellido: "PEREZ GOMEZ"                                  │
│  - DNI: "12345678"                                          │
│  - Calidad Imagen: 95%                                      │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│           COMPARACIÓN CON FORMULARIO                         │
│                                                              │
│  Datos Formulario:                                          │
│  - Nombre: "Juan Carlos Pérez Gómez"                        │
│  - DNI: "12345678"                                          │
│                                                              │
│  Normalización:                                             │
│  - "juan carlos perez gomez" == "juan carlos perez gomez" ✅│
│  - "12345678" == "12345678" ✅                              │
│  - Calidad >= 70% ✅                                        │
└─────────────────────────────────────────────────────────────┘
                            ↓
                    ¿Coincide 100%?
                    /              \
                  SÍ               NO
                  ↓                ↓
    ┌──────────────────┐    ┌──────────────────┐
    │ VERIFICADO ✅    │    │ PENDIENTE ⏳     │
    │                  │    │                  │
    │ Estado: Auto     │    │ Estado: Manual   │
    │ Conductor puede  │    │ Requiere revisión│
    │ trabajar         │    │ de administrador │
    └──────────────────┘    └──────────────────┘
                                    ↓
                    ┌──────────────────────────┐
                    │ ADMINISTRADOR REVISA     │
                    │                          │
                    │ [Ver Documento]          │
                    │ [Campo Observaciones]    │
                    │                          │
                    │ Observaciones:           │
                    │ "Foto borrosa,           │
                    │  solicitar nueva"        │
                    │                          │
                    │ [Rechazar] [Aprobar]     │
                    └──────────────────────────┘
                            ↓
                    Conductor notificado
```

---

## 💵 5. Dashboard Financiero - Vista CEO

```
┌─────────────────────────────────────────────────────────────┐
│  ← Gestión Financiera                        [🔄] [+]       │
│    Control de costos operativos                             │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────┐   │
│  │         💵 Costo Actual    │    📈 Proyectado       │   │
│  │            $53.000          │       $64.500         │   │
│  │                                                       │   │
│  │         ⬆️ Diferencia: +$11.500 (ALERTA)            │   │
│  └─────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  TABLA DE COSTOS (Scroll horizontal →)                      │
│                                                              │
│  ┌────────┬─────────┬──────────┬─────────┬────────┬─────┐ │
│  │Servicio│ Actual  │Proyectado│Diferenc.│ Estado │Acc. │ │
│  ├────────┼─────────┼──────────┼─────────┼────────┼─────┤ │
│  │Resend  │ $5.000  │ $8.000   │ +$3.000 │🟢Activo│✏️🗑️│ │
│  │        │         │          │         │        │     │ │
│  │Mapbox  │ $12.000 │ $15.000  │ +$3.000 │🟢Activo│✏️🗑️│ │
│  │        │         │          │         │        │     │ │
│  │Amazon  │ $3.000  │ $4.500   │ +$1.500 │🟢Activo│✏️🗑️│ │
│  │SES     │         │          │         │        │     │ │
│  │        │         │          │         │        │     │ │
│  │Supabase│ $25.000 │ $25.000  │   $0    │🟢Activo│✏️🗑️│ │
│  │Pro     │         │          │         │        │     │ │
│  │        │         │          │         │        │     │ │
│  │Twilio  │ $8.000  │ $12.000  │ +$4.000 │🟠Pausad│✏️🗑️│ │
│  │SMS     │         │          │         │        │     │ │
│  └────────┴─────────┴──────────┴─────────┴────────┴─────┘ │
│                                                              │
│  (Scroll vertical para ver más servicios ↓)                 │
└─────────────────────────────────────────────────────────────┘

ACCIONES DISPONIBLES:

[+] Agregar Nuevo Costo
    ↓
┌─────────────────────────────────────┐
│  Nuevo Costo Operativo              │
│                                     │
│  Servicio:     [Google Cloud    ]  │
│  Costo Actual: [$ 10000         ]  │
│  Proyectado:   [$ 12000         ]  │
│  Estado:       [Activo ▼        ]  │
│  Notas:        [Hosting y CDN   ]  │
│                                     │
│       [Cancelar]  [Guardar]        │
└─────────────────────────────────────┘

[✏️] Editar Costo Existente
    ↓
┌─────────────────────────────────────┐
│  Editar Costo                       │
│                                     │
│  Servicio:     [Mapbox (Mapas)  ]  │
│  Costo Actual: [$ 18000 ← EDITAR]  │
│  Proyectado:   [$ 20000         ]  │
│  Estado:       [Activo ▼        ]  │
│  Notas:        [Aumento marzo   ]  │
│                [2026            ]  │
│                                     │
│       [Cancelar]  [Guardar]        │
└─────────────────────────────────────┘

[🗑️] Eliminar Costo
    ↓
┌─────────────────────────────────────┐
│  Eliminar Costo                     │
│                                     │
│  ¿Estás seguro de eliminar          │
│  "Twilio SMS"?                      │
│                                     │
│       [Cancelar]  [Eliminar]       │
└─────────────────────────────────────┘
```

---

## 📊 6. Arquitectura del Sistema

```
┌─────────────────────────────────────────────────────────────┐
│                      FLUTTER APP                             │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  SCREENS                    MODELS                          │
│  ├─ plan_selection          ├─ plan_conductor               │
│  ├─ gestion_financiera      ├─ costo_operativo             │
│  ├─ verification            ├─ documento_validacion         │
│  ├─ driver_home             └─ logro_usuario                │
│  ├─ rider_home                                              │
│  └─ ceo_home                                                │
│                                                              │
│  WIDGETS                    SERVICES                        │
│  ├─ seccion_logros          └─ validacion_documentos        │
│  ├─ documento_revision                                      │
│  └─ autorizaciones_panel                                    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
                            ↕️
                    [SUPABASE API]
                            ↕️
┌─────────────────────────────────────────────────────────────┐
│                     SUPABASE                                 │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  TABLES                     VIEWS                           │
│  ├─ perfiles                ├─ resumen_costos               │
│  ├─ costos_operativos       └─ estadisticas_conductores     │
│  └─ documentos_validacion                                   │
│                                                              │
│  FUNCTIONS                  RLS POLICIES                    │
│  └─ calcular_comision       ├─ CEO: Full access costos     │
│                             ├─ Conductor: Own docs only     │
│                             └─ Admin: All docs              │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔐 7. Seguridad y Permisos

```
┌─────────────────────────────────────────────────────────────┐
│                    MATRIZ DE PERMISOS                        │
├─────────────┬───────────┬───────────┬───────────┬──────────┤
│   Recurso   │    CEO    │  Operador │ Conductor │Solicitant│
├─────────────┼───────────┼───────────┼───────────┼──────────┤
│ Costos      │ CRUD      │ -         │ -         │ -        │
│ Operativos  │           │           │           │          │
├─────────────┼───────────┼───────────┼───────────┼──────────┤
│ Documentos  │ Ver/Edit  │ Ver/Edit  │ Ver/Insert│ -        │
│ Validación  │ Todos     │ Todos     │ Propios   │          │
├─────────────┼───────────┼───────────┼───────────┼──────────┤
│ Plan        │ -         │ -         │ Ver/Edit  │ -        │
│ Conductor   │           │           │ Propio    │          │
├─────────────┼───────────┼───────────┼───────────┼──────────┤
│ Logros      │ Ver Todos │ Ver Todos │ Ver Propio│Ver Propio│
│             │           │           │           │          │
└─────────────┴───────────┴───────────┴───────────┴──────────┘

LEYENDA:
- CRUD: Create, Read, Update, Delete
- Ver: Solo lectura
- Edit: Modificar
- Insert: Crear nuevo
- Propio: Solo sus propios datos
- Todos: Todos los registros
- (-): Sin acceso
```

---

## 📱 8. Optimización Móvil - Gestos Táctiles

```
┌─────────────────────────────────────────────────────────────┐
│                  GESTOS SOPORTADOS                           │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  DRIVER/RIDER HOME:                                         │
│  ┌──────────────────────────────────────────────────┐      │
│  │  Swipe → desde borde izquierdo                   │      │
│  │  Abre Drawer con perfil y logros                 │      │
│  └──────────────────────────────────────────────────┘      │
│                                                              │
│  GESTIÓN FINANCIERA:                                        │
│  ┌──────────────────────────────────────────────────┐      │
│  │  Scroll → horizontal en tabla                    │      │
│  │  Ver todas las columnas                          │      │
│  │                                                    │      │
│  │  Scroll ↓ vertical en tabla                      │      │
│  │  Ver todos los servicios                         │      │
│  │                                                    │      │
│  │  Tap en [✏️] → Editar costo                      │      │
│  │  Tap en [🗑️] → Eliminar costo                   │      │
│  └──────────────────────────────────────────────────┘      │
│                                                              │
│  PLAN SELECTION:                                            │
│  ┌──────────────────────────────────────────────────┐      │
│  │  Tap en tarjeta completa → Seleccionar plan     │      │
│  │  Scroll ↓ para ver todos los beneficios         │      │
│  └──────────────────────────────────────────────────┘      │
│                                                              │
│  DIÁLOGOS:                                                  │
│  ┌──────────────────────────────────────────────────┐      │
│  │  Tap fuera del diálogo → Cerrar                 │      │
│  │  Teclado numérico → Aparece automáticamente     │      │
│  └──────────────────────────────────────────────────┘      │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 🎯 9. Casos de Uso Reales

### Caso 1: Conductor Evalúa Rentabilidad del Plan VIP

**Contexto**: Juan es conductor y gana \$800.000 por semana

**Cálculo**:

| Plan | Costo Semanal | Comisión | Total Pagado | Ganancia Neta |
|------|---------------|----------|--------------|---------------|
| Comunidad | \$0 | 5% = \$40.000 | \$40.000 | \$760.000 |
| VIP | \$25.000 | 0% = \$0 | \$25.000 | \$775.000 |

**Decisión**: ✅ Plan VIP le ahorra \$15.000 por semana

**Acción en la App**:
1. Driver Home → MI PLAN DE TRABAJO
2. Ve la comparación
3. Selecciona VIP
4. ✅ Ahorra \$60.000 por mes

### Caso 2: CEO Detecta Aumento de Costos

**Contexto**: CEO recibe email de Mapbox: "Aumento de precios 25%"

**Acción desde el Celular** (en la calle):
1. Abre Scertta
2. CEO Home → Botón verde ($)
3. Ve tabla de costos
4. Mapbox actual: \$12.000
5. Click en lápiz ✏️
6. Cambia proyectado: \$15.000 → \$18.000
7. Agrega nota: "Aumento 25% marzo 2026"
8. Guarda
9. ✅ Resumen actualizado: Diferencia +\$14.500
10. ✅ Alerta visual (rojo)
11. Toma decisión: "Evaluar alternativas a Mapbox"

**Tiempo total**: 45 segundos ⚡

### Caso 3: Conductor Celebra Logro

**Contexto**: María completa su viaje número 50

**Sistema Automático**:
1. Viaje finalizado
2. `viajes_completados` incrementa: 49 → 50
3. ✅ Nivel sube: "Intermedio" → "Avanzado"
4. ✅ Nueva insignia: "Medio Centenar"
5. Notificación push: "🎉 ¡Felicitaciones! Alcanzaste el nivel Avanzado"

**María abre la app**:
1. Driver Home → Menú (☰)
2. Ve Logros actualizados
3. ✅ Nivel: Avanzado (color verde)
4. ✅ Nueva insignia visible
5. ✅ "Llevas 8 meses en la comunidad Scertta"
6. 😊 Se siente motivada y valorada

---

## 📈 10. Métricas de Éxito

### KPIs del Sistema VIP

1. **Tasa de Conversión a VIP**:
   - Meta: 20% de conductores activos
   - Seguimiento: `SELECT COUNT(*) FROM perfiles WHERE plan_conductor = 'vip'`

2. **Retención de Conductores**:
   - Meta: 80% de conductores activos después de 3 meses
   - Seguimiento: Tabla `perfiles.fecha_ingreso`

3. **Tiempo de Validación de Documentos**:
   - Meta: < 5 minutos para 90% de documentos
   - Validación automática: < 1 minuto
   - Validación manual: < 10 minutos

4. **Uso del Dashboard Financiero**:
   - Meta: CEO actualiza costos semanalmente
   - Seguimiento: `costos_operativos.fecha_actualizacion`

### Queries de Análisis

```sql
-- Distribución de planes
SELECT 
  plan_conductor,
  COUNT(*) as cantidad,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as porcentaje
FROM perfiles
WHERE rol = 'conductor'
GROUP BY plan_conductor;

-- Conductores por nivel
SELECT 
  nivel_conductor,
  COUNT(*) as cantidad
FROM estadisticas_conductores
GROUP BY nivel_conductor
ORDER BY 
  CASE nivel_conductor
    WHEN 'Leyenda' THEN 1
    WHEN 'Maestro' THEN 2
    WHEN 'Experto' THEN 3
    WHEN 'Avanzado' THEN 4
    WHEN 'Intermedio' THEN 5
    WHEN 'Novato' THEN 6
  END;

-- Documentos por estado
SELECT 
  estado_validacion,
  COUNT(*) as cantidad,
  AVG(coincidencia) as coincidencia_promedio
FROM documentos_validacion
GROUP BY estado_validacion;

-- Evolución de costos
SELECT 
  servicio,
  costo_actual,
  costo_proyectado,
  costo_proyectado - costo_actual as aumento,
  ROUND((costo_proyectado - costo_actual) * 100.0 / costo_actual, 2) as porcentaje_aumento
FROM costos_operativos
WHERE estado = 'activo'
ORDER BY porcentaje_aumento DESC;
```

---

## ✅ Checklist de Verificación Final

### Funcionalidades Implementadas

- [x] Modelo de suscripción con 2 planes (Comunidad y VIP)
- [x] Pantalla de selección de plan para conductores
- [x] Cálculo automático de comisiones según plan
- [x] Dashboard financiero tipo Excel para CEO
- [x] CRUD completo de costos operativos
- [x] Resumen financiero con alertas visuales
- [x] Validación automática de documentos con IA
- [x] Comparación de datos formulario vs documento
- [x] Campo de observaciones para administrador
- [x] Sistema de logros con tiempo en comunidad
- [x] Niveles de conductor (Novato a Leyenda)
- [x] Insignias y estadísticas
- [x] Diseño 100% responsivo para móvil
- [x] Optimizado para uso con una mano
- [x] Botones grandes y táctiles
- [x] Feedback visual inmediato
- [x] Migración SQL completa
- [x] Políticas RLS configuradas
- [x] Vistas y funciones SQL
- [x] Mock data para desarrollo

### Testing

- [x] Flujo de selección de plan probado
- [x] Dashboard financiero accesible desde CEO Home
- [x] Edición de costos funciona en móvil
- [x] Logros visibles en Drawer
- [x] Validación de documentos simulada
- [x] Navegación entre pantallas sin crashes

### Documentación

- [x] `SISTEMA_VIP_Y_GESTION_COMPLETO.md` - Guía completa
- [x] `INSTRUCCIONES_MIGRACION.md` - Pasos de migración
- [x] `DIAGRAMAS_FLUJO.md` - Diagramas visuales
- [x] Comentarios en código SQL
- [x] Comentarios en modelos Dart

---

**🎉 ¡Sistema completo y listo para usar!** 🎉

**El CEO puede gestionar toda la operación desde su celular mientras camina por la calle.** 📱✨
