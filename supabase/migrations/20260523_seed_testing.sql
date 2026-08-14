-- ═══════════════════════════════════════════════════════════
-- Seed de testing — Datos de prueba para verificar todo el flujo
-- ═══════════════════════════════════════════════════════════

-- 1. Crear usuario CEO de prueba (si no existe)
-- Se crea desde Supabase Auth UI, acá solo el perfil
INSERT INTO public.perfiles (id, email, nombre, rol, provincia_activa_id)
SELECT 
  gen_random_uuid(), 'ceo@rutmy.com', 'Andres (CEO)', 'ceo',
  (SELECT id FROM public.provincias WHERE codigo = 'AR-B')
WHERE NOT EXISTS (SELECT 1 FROM public.perfiles WHERE email = 'ceo@rutmy.com');

-- 2. Crear flota de prueba (Modelo Mixto)
INSERT INTO public.flotas (id, nombre, perfil_id, tipo_flota, comision_flota_pct, razon_social, cuit)
SELECT
  '00000000-0000-0000-0000-000000000001',
  'Flota Demo BA',
  (SELECT id FROM public.perfiles WHERE email = 'ceo@rutmy.com'),
  'mixta', 20.00, 'Flota Demo S.A.S.', '30-12345678-9'
WHERE EXISTS (SELECT 1 FROM public.perfiles WHERE email = 'ceo@rutmy.com')
  AND NOT EXISTS (SELECT 1 FROM public.flotas WHERE id = '00000000-0000-0000-0000-000000000001');

-- 3. Insertar vehículos de prueba
INSERT INTO public.vehiculos_flota (flota_id, marca, modelo, anio, patente, color, tipo, propiedad, activo)
SELECT '00000000-0000-0000-0000-000000000001', 'Toyota', 'Corolla', 2023, 'ABC123', 'Blanco', 'auto', 'flota', true
WHERE EXISTS (SELECT 1 FROM public.flotas WHERE id = '00000000-0000-0000-0000-000000000001')
  AND NOT EXISTS (SELECT 1 FROM public.vehiculos_flota WHERE patente = 'ABC123');

INSERT INTO public.vehiculos_flota (flota_id, marca, modelo, anio, patente, color, tipo, propiedad, activo)
SELECT '00000000-0000-0000-0000-000000000001', 'Renault', 'Kangoo', 2022, 'DEF456', 'Gris', 'utilitario', 'flota', true
WHERE EXISTS (SELECT 1 FROM public.flotas WHERE id = '00000000-0000-0000-0000-000000000001')
  AND NOT EXISTS (SELECT 1 FROM public.vehiculos_flota WHERE patente = 'DEF456');

INSERT INTO public.vehiculos_flota (flota_id, marca, modelo, anio, patente, color, tipo, propiedad, activo)
SELECT '00000000-0000-0000-0000-000000000001', 'Ford', 'Ranger', 2024, 'XYZ789', 'Negro', 'camioneta', 'conductor', true
WHERE EXISTS (SELECT 1 FROM public.flotas WHERE id = '00000000-0000-0000-0000-000000000001')
  AND NOT EXISTS (SELECT 1 FROM public.vehiculos_flota WHERE patente = 'XYZ789');

-- 4. Insertar registros contables de prueba
INSERT INTO public.libro_contable (viaje_id, flota_id, fecha_contable, concepto, monto_bruto, iva_pct, iibb_pct, provincia_id)
SELECT
  NULL, '00000000-0000-0000-0000-000000000001', CURRENT_DATE,
  'Comisión viaje #TEST-001', 1000.00, 21.00, 3.50,
  (SELECT id FROM public.provincias WHERE codigo = 'AR-B')
WHERE EXISTS (SELECT 1 FROM public.flotas WHERE id = '00000000-0000-0000-0000-000000000001');

INSERT INTO public.libro_contable (viaje_id, flota_id, fecha_contable, concepto, monto_bruto, iva_pct, iibb_pct, provincia_id)
SELECT
  NULL, '00000000-0000-0000-0000-000000000001', CURRENT_DATE,
  'Gastos operativos flota #TEST-001', 500.00, 21.00, 3.50,
  (SELECT id FROM public.provincias WHERE codigo = 'AR-B')
WHERE EXISTS (SELECT 1 FROM public.flotas WHERE id = '00000000-0000-0000-0000-000000000001');

-- 5. Verificar datos insertados
SELECT '✅ Seed completado' as resultado;
SELECT COUNT(*) as flotas FROM public.flotas;
SELECT COUNT(*) as vehiculos FROM public.vehiculos_flota WHERE flota_id = '00000000-0000-0000-0000-000000000001';
SELECT concepto, monto_bruto, iva_monto, iibb_monto, neto FROM public.libro_contable ORDER BY created_at DESC LIMIT 5;
