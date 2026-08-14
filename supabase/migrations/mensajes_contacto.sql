-- Migration: create mensajes_contacto table for scertta.com contact form
-- Run: supabase db push

CREATE TABLE IF NOT EXISTS public.mensajes_contacto (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nombre TEXT NOT NULL,
  email TEXT NOT NULL,
  telefono TEXT,
  motivo TEXT NOT NULL,
  mensaje TEXT NOT NULL,
  estado TEXT DEFAULT 'nuevo' CHECK (estado IN ('nuevo', 'leido', 'respondido', 'archivado')),
  categoria TEXT DEFAULT 'general' CHECK (categoria IN ('general', 'franquicia', 'reclamo', 'soporte', 'prensa', 'otro')),
  origen TEXT DEFAULT 'web_scertta',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- RLS: allow insert from anon (public form)
ALTER TABLE public.mensajes_contacto ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow anonymous inserts" ON public.mensajes_contacto
  FOR INSERT TO anon
  WITH CHECK (true);

CREATE POLICY "Allow ceo_admin to read all" ON public.mensajes_contacto
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.perfiles
      WHERE perfiles.user_id = auth.uid()
      AND perfiles.rol = 'ceo_admin'
    )
  );

-- Index for fast filtering
CREATE INDEX idx_mensajes_estado ON public.mensajes_contacto(estado);
CREATE INDEX idx_mensajes_categoria ON public.mensajes_contacto(categoria);
CREATE INDEX idx_mensajes_created ON public.mensajes_contacto(created_at DESC);
