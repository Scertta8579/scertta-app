-- ═══════════════════════════════════════════════════════════════════════════
-- Denuncias, calificaciones y flujo de reportes
-- Task: flujo-denuncias-simulacion
-- ═══════════════════════════════════════════════════════════════════════════

-- ─── 1. Calificaciones de viaje ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.calificaciones_viaje (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  viaje_id      UUID NOT NULL REFERENCES public.viajes(id) ON DELETE CASCADE,
  calificador_id UUID NOT NULL REFERENCES public.perfiles(id),
  calificado_id UUID NOT NULL REFERENCES public.perfiles(id),
  estrellas     INTEGER NOT NULL CHECK (estrellas BETWEEN 1 AND 5),
  comentario    TEXT,
  -- Si estrellas <= 2, el usuario puede adjuntar un motivo de denuncia
  motivo_denuncia TEXT CHECK (
    motivo_denuncia IS NULL OR
    motivo_denuncia IN (
      'seguridad', 'conduccion_peligrosa', 'trato_inadecuado',
      'vehiculo_en_mal_estado', 'no_se_presento', 'cobro_indebido',
      'ruta_incorrecta', 'pasajero_agresivo', 'ensucio_vehiculo',
      'no_pago', 'cancelacion_tardia', 'discriminacion', 'otro'
    )
  ),
  crea_denuncia BOOLEAN NOT NULL DEFAULT FALSE,
  denuncia_id   UUID,  -- FK agregada tras crear denuncia
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  -- Un calificador solo puede calificar una vez por viaje
  CONSTRAINT calificaciones_unica UNIQUE (viaje_id, calificador_id)
);

COMMENT ON TABLE public.calificaciones_viaje IS 'Calificación post-viaje. Si estrellas <= 2 y crea_denuncia=true, dispara el flujo de denuncia.';

CREATE INDEX IF NOT EXISTS idx_calificaciones_viaje    ON public.calificaciones_viaje(viaje_id);
CREATE INDEX IF NOT EXISTS idx_calificaciones_calificador ON public.calificaciones_viaje(calificador_id);
CREATE INDEX IF NOT EXISTS idx_calificaciones_calificado  ON public.calificaciones_viaje(calificado_id);
CREATE INDEX IF NOT EXISTS idx_calificaciones_estrellas   ON public.calificaciones_viaje(estrellas);

-- ─── 2. Denuncias ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.denuncias (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  viaje_id        UUID NOT NULL REFERENCES public.viajes(id) ON DELETE CASCADE,
  denunciante_id  UUID NOT NULL REFERENCES public.perfiles(id),
  denunciado_id   UUID NOT NULL REFERENCES public.perfiles(id),
  tipo_denunciante TEXT NOT NULL CHECK (tipo_denunciante IN ('pasajero', 'conductor')),
  motivo          TEXT NOT NULL CHECK (
    motivo IN (
      'seguridad', 'conduccion_peligrosa', 'trato_inadecuado',
      'vehiculo_en_mal_estado', 'no_se_presento', 'cobro_indebido',
      'ruta_incorrecta', 'pasajero_agresivo', 'ensucio_vehiculo',
      'no_pago', 'cancelacion_tardia', 'discriminacion', 'otro'
    )
  ),
  descripcion     TEXT,
  evidencia_url   TEXT,  -- URL de imagen/captura en Supabase Storage
  estado          TEXT NOT NULL DEFAULT 'pendiente' CHECK (
    estado IN ('pendiente', 'en_revision', 'resuelta', 'cerrada', 'desestimada')
  ),
  severidad       TEXT NOT NULL DEFAULT 'media' CHECK (
    severidad IN ('baja', 'media', 'alta', 'critica')
  ),
  resolucion      TEXT,         -- Notas de resolución
  resuelto_por    UUID REFERENCES public.perfiles(id),
  resuelto_at     TIMESTAMPTZ,
  -- Cálculo automático de estrellas: penalización por denuncias
  penalizacion_aplicada BOOLEAN NOT NULL DEFAULT FALSE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.denuncias IS 'Denuncias entre pasajeros y conductores. Tanto el pasajero como el conductor pueden denunciar.';

CREATE INDEX IF NOT EXISTS idx_denuncias_viaje       ON public.denuncias(viaje_id);
CREATE INDEX IF NOT EXISTS idx_denuncias_denunciante  ON public.denuncias(denunciante_id);
CREATE INDEX IF NOT EXISTS idx_denuncias_denunciado   ON public.denuncias(denunciado_id);
CREATE INDEX IF NOT EXISTS idx_denuncias_estado       ON public.denuncias(estado);
CREATE INDEX IF NOT EXISTS idx_denuncias_severidad    ON public.denuncias(severidad);
CREATE INDEX IF NOT EXISTS idx_denuncias_created      ON public.denuncias(created_at DESC);

-- ─── 3. Historial de estado de denuncias (auditoría) ──────────────────────
CREATE TABLE IF NOT EXISTS public.denuncias_historial (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  denuncia_id UUID NOT NULL REFERENCES public.denuncias(id) ON DELETE CASCADE,
  estado_anterior TEXT,
  estado_nuevo    TEXT NOT NULL,
  cambiado_por    UUID REFERENCES public.perfiles(id),
  notas           TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_denuncias_historial ON public.denuncias_historial(denuncia_id, created_at DESC);

-- ─── 4. Triggers updated_at ────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_calificaciones_viaje_updated_at ON public.calificaciones_viaje;
CREATE TRIGGER trg_calificaciones_viaje_updated_at
  BEFORE UPDATE ON public.calificaciones_viaje
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS trg_denuncias_updated_at ON public.denuncias;
CREATE TRIGGER trg_denuncias_updated_at
  BEFORE UPDATE ON public.denuncias
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ─── 5. RLS ────────────────────────────────────────────────────────────────
ALTER TABLE public.calificaciones_viaje ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.denuncias ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.denuncias_historial ENABLE ROW LEVEL SECURITY;

-- Calificaciones: el calificador puede leer/escribir sus propias calificaciones
CREATE POLICY "calificaciones_own_all"
  ON public.calificaciones_viaje FOR ALL
  TO authenticated
  USING (calificador_id = auth.uid())
  WITH CHECK (calificador_id = auth.uid());

-- Calificaciones: el calificado puede leer calificaciones sobre él
CREATE POLICY "calificaciones_calificado_read"
  ON public.calificaciones_viaje FOR SELECT
  TO authenticated
  USING (calificado_id = auth.uid());

-- Calificaciones: staff puede leer todo
CREATE POLICY "calificaciones_staff_read"
  ON public.calificaciones_viaje FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.perfiles p
      WHERE p.id = auth.uid() AND p.rol IN ('ceo', 'operador')
    )
  );

-- Denuncias: el denunciante puede crear y leer
CREATE POLICY "denuncias_insert_authenticated"
  ON public.denuncias FOR INSERT
  TO authenticated
  WITH CHECK (denunciante_id = auth.uid());

-- Denuncias: ambas partes pueden leer
CREATE POLICY "denuncias_partes_read"
  ON public.denuncias FOR SELECT
  TO authenticated
  USING (denunciante_id = auth.uid() OR denunciado_id = auth.uid());

-- Denuncias: staff puede leer y actualizar todo
CREATE POLICY "denuncias_staff_all"
  ON public.denuncias FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.perfiles p
      WHERE p.id = auth.uid() AND p.rol IN ('ceo', 'operador')
    )
  );

-- Historial: staff puede leer todo
CREATE POLICY "historial_staff_read"
  ON public.denuncias_historial FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.perfiles p
      WHERE p.id = auth.uid() AND p.rol IN ('ceo', 'operador')
    )
  );

-- Historial: las partes pueden leer historial de sus denuncias
CREATE POLICY "historial_partes_read"
  ON public.denuncias_historial FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.denuncias d
      WHERE d.id = denuncias_historial.denuncia_id
      AND (d.denunciante_id = auth.uid() OR d.denunciado_id = auth.uid())
    )
  );

-- ─── 6. Realtime ───────────────────────────────────────────────────────────
ALTER PUBLICATION supabase_realtime ADD TABLE public.denuncias;
ALTER PUBLICATION supabase_realtime ADD TABLE public.calificaciones_viaje;

-- ─── 7. Función: crear denuncia desde calificación baja ───────────────────
CREATE OR REPLACE FUNCTION public.crear_denuncia_desde_calificacion(
  p_calificacion_id UUID,
  p_descripcion TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cal public.calificaciones_viaje;
  v_denuncia_id UUID;
BEGIN
  SELECT * INTO v_cal FROM public.calificaciones_viaje WHERE id = p_calificacion_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Calificación no encontrada';
  END IF;
  
  IF v_cal.estrellas > 2 THEN
    RAISE EXCEPTION 'Solo calificaciones de 1-2 estrellas pueden generar denuncia';
  END IF;
  
  IF v_cal.denuncia_id IS NOT NULL THEN
    RETURN v_cal.denuncia_id; -- Ya existe
  END IF;
  
  INSERT INTO public.denuncias (
    viaje_id, denunciante_id, denunciado_id,
    tipo_denunciante, motivo, descripcion
  ) VALUES (
    v_cal.viaje_id,
    v_cal.calificador_id,
    v_cal.calificado_id,
    CASE 
      WHEN EXISTS (SELECT 1 FROM public.perfiles WHERE id = v_cal.calificador_id AND rol = 'solicitante')
      THEN 'pasajero' ELSE 'conductor'
    END,
    COALESCE(v_cal.motivo_denuncia, 'otro'),
    COALESCE(p_descripcion, v_cal.comentario)
  )
  RETURNING id INTO v_denuncia_id;
  
  -- Vincular denuncia a calificación
  UPDATE public.calificaciones_viaje
  SET denuncia_id = v_denuncia_id, crea_denuncia = TRUE
  WHERE id = p_calificacion_id;
  
  -- Registrar en historial
  INSERT INTO public.denuncias_historial (denuncia_id, estado_nuevo, notas)
  VALUES (v_denuncia_id, 'pendiente', 'Denuncia creada automáticamente desde calificación ' || v_cal.estrellas || ' estrellas');
  
  RETURN v_denuncia_id;
END;
$$;

REVOKE ALL ON FUNCTION public.crear_denuncia_desde_calificacion(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.crear_denuncia_desde_calificacion(UUID, TEXT) TO authenticated;
