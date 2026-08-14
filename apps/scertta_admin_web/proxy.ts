import { createServerClient } from '@supabase/ssr'
import { NextResponse, type NextRequest } from 'next/server'

export async function proxy(request: NextRequest) {
  const path = request.nextUrl.pathname

  // ═══════════════════════════════════════════════════════════
  // OPTIMIZACIÓN CRÍTICA: Rutas públicas y health checks NO
  // deben hacer roundtrip a Supabase. El auth.getUser() es
  // costoso (~100-5000ms) y bloquea el event loop de Next.js.
  // Si Supabase está lento, Caddy recibe timeout → 503 en TODA
  // la plataforma (incluyendo rutas que ni necesitan auth).
  // ═══════════════════════════════════════════════════════════
  if (esRutaPublica(path)) {
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
    console.log('🛡️ PROXY — Rutmy / Scertta')
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
    console.log(`📍 Ruta: ${path}`)
    console.log('👤 Usuario: (pública — sin auth)')
    console.log('✅ Ruta pública')
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n')
    return NextResponse.next({ request })
  }

  // ─── Solo rutas protegidas: inicializar Supabase y verificar auth ───
  let supabaseResponse = NextResponse.next({ request })

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookieOptions: {
        path: '/',
        sameSite: 'lax',
        secure: request.nextUrl.protocol === 'https:',
      },
      cookies: {
        getAll() {
          return request.cookies.getAll()
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value, options }) =>
            request.cookies.set(name, value)
          )
          supabaseResponse = NextResponse.next({
            request,
          })
          cookiesToSet.forEach(({ name, value, options }) =>
            supabaseResponse.cookies.set(name, value, options)
          )
        },
      },
    }
  )

  const {
    data: { user },
  } = await supabase.auth.getUser()

  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
  console.log('🛡️ PROXY — Rutmy / Scertta')
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
  console.log(`📍 Ruta: ${path}`)
  console.log(`👤 Usuario: ${user?.email ?? 'No autenticado'}`)

  if (!user) {
    console.log('❌ No autenticado → /login')
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n')

    const redirectUrl = new URL('/login', request.url)
    const returnPath = path + (request.nextUrl.search || '')
    if (path !== '/login') {
      redirectUrl.searchParams.set('redirectTo', returnPath)
    }
    return NextResponse.redirect(redirectUrl)
  }

  // Obtener rol + provincia activa + flag password
  console.log('🔍 Consultando perfil...')

  let rolUsuario: string | null = null
  let provinciaActivaId: string | null = null
  let debeCambiarPassword = false

  try {
    const { data: perfil, error } = await supabase
      .from('perfiles')
      .select('rol, provincia_activa_id, debe_cambiar_password')
      .eq('id', user.id)
      .maybeSingle()

    if (error) {
      console.log(`⚠️ Error perfil: ${error.message}`)
    } else if (perfil) {
      rolUsuario = perfil.rol
      provinciaActivaId = perfil.provincia_activa_id
      debeCambiarPassword = perfil.debe_cambiar_password || false
      console.log(`✅ Rol: ${rolUsuario} | Provincia: ${provinciaActivaId ?? 'ninguna'} | DebeCambiar: ${debeCambiarPassword}`)
    } else {
      console.log('⚠️ Perfil no encontrado')
    }
  } catch (e) {
    console.log(`⚠️ Error: ${e}`)
  }

  // ─── Forzar cambio de contraseña ───
  if (debeCambiarPassword && path !== '/cambiar-password' && path !== '/login') {
    console.log('🔐 Debe cambiar contraseña → /cambiar-password')
    return NextResponse.redirect(new URL('/cambiar-password', request.url))
  }

  // ─── Chequeo de rutas protegidas ───
  const accesoResult = verificarAcceso(path, rolUsuario, esAdminRuta(path))

  if (accesoResult === 'denegado') {
    console.log('❌ ACCESO DENEGADO')
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n')
    const redirectUrl = request.nextUrl.clone()
    redirectUrl.pathname = '/acceso-denegado'
    return NextResponse.redirect(redirectUrl)
  }

  // ─── ceo_admin: acceso total ───
  if (rolUsuario === 'ceo_admin') {
    console.log('👑 ceo_admin — acceso total (todas las franquicias)')
    supabaseResponse.headers.set('x-rol', rolUsuario)
    supabaseResponse.headers.set('x-provincia-activa-id', '*')
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n')
    return supabaseResponse
  }

  // ─── gerente_franquicia: bloquear si rescindido ───
  if (rolUsuario === 'gerente_franquicia') {
    const { data: perfilCheck } = await supabase
      .from('perfiles')
      .select('activo, franquicia_id, franquicias!inner(estado)')
      .eq('id', user.id)
      .maybeSingle()

    if (perfilCheck) {
      const franquiciaEstado = (perfilCheck as any).franquicias?.estado
      const perfilActivo = (perfilCheck as any).activo

      if (!perfilActivo || franquiciaEstado === 'rescindido') {
        console.log('🚫 Franquicia rescindida o perfil inactivo → /login')
        await supabase.auth.signOut()
        return NextResponse.redirect(new URL('/login?error=acceso_bloqueado', request.url))
      }
    }

    // Auto-asignar provincia si no tiene
    if (!provinciaActivaId) {
      try {
        const { data: ba } = await supabase
          .from('provincias')
          .select('id')
          .eq('codigo', 'AR-B')
          .maybeSingle()
        if (ba) {
          await supabase
            .from('perfiles')
            .update({ provincia_activa_id: ba.id })
            .eq('id', user.id)
          provinciaActivaId = ba.id
          console.log('📍 Auto-asignada provincia: Buenos Aires')
        }
      } catch (_) {}
    }

    supabaseResponse.headers.set('x-rol', rolUsuario)
    supabaseResponse.headers.set('x-provincia-activa-id', provinciaActivaId ?? '')

    console.log('🏢 gerente_franquicia — acceso a su franquicia')
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n')
    return supabaseResponse
  }

  // ─── Otros roles: permisos por ruta ───
  const permisosPorRuta: Record<string, string[]> = {
    '/hub':             ['ceo_admin', 'gerente_franquicia', 'operador', 'marketing', 'finanzas', 'soporte', 'seguridad'],
    '/ceo-dashboard':   ['ceo_admin', 'gerente_franquicia'],
    '/finanzas':        ['ceo_admin', 'gerente_franquicia', 'finanzas'],
    '/soporte':         ['ceo_admin', 'gerente_franquicia', 'operador', 'soporte', 'seguridad'],
    '/marketing':       ['ceo_admin', 'gerente_franquicia', 'marketing'],
    '/legales':         ['ceo_admin', 'gerente_franquicia', 'seguridad'],
    '/rrhh':            ['ceo_admin', 'gerente_franquicia', 'operador'],
    '/solicitante':     ['ceo_admin', 'gerente_franquicia', 'solicitante'],
    '/socio-conductor': ['ceo_admin', 'gerente_franquicia', 'conductor'],
    '/flota':           ['ceo_admin', 'gerente_franquicia', 'operador', 'conductor'],
  }

  for (const [ruta, rolesPermitidos] of Object.entries(permisosPorRuta)) {
    if (path.startsWith(ruta)) {
      console.log(`🔒 Ruta protegida: ${ruta} → roles: ${rolesPermitidos.join(', ')}`)

      if (!rolUsuario || !rolesPermitidos.includes(rolUsuario)) {
        console.log('❌ ACCESO DENEGADO')
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n')
        const redirectUrl = request.nextUrl.clone()
        redirectUrl.pathname = '/acceso-denegado'
        return NextResponse.redirect(redirectUrl)
      }

      // ─── Regla de llave provincial: /hub solo para @rutmy.com ───
      if (ruta === '/hub') {
        const email = user.email ?? ''
        if (!email.endsWith('@rutmy.com')) {
          console.log(`❌ HUB DENEGADO — email ${email} no es @rutmy.com`)
          console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n')
          const redirectUrl = request.nextUrl.clone()
          redirectUrl.pathname = '/acceso-denegado'
          return NextResponse.redirect(redirectUrl)
        }
        console.log(`✅ HUB permitido — llave provincial: ${email}`)
      }

      supabaseResponse.headers.set('x-rol', rolUsuario)
      supabaseResponse.headers.set('x-provincia-activa-id', provinciaActivaId ?? '')

      console.log(`✅ Acceso permitido | Provincia: ${provinciaActivaId ?? 'sin asignar'}`)
      console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n')
      return supabaseResponse
    }
  }

  supabaseResponse.headers.set('x-rol', rolUsuario ?? '')
  supabaseResponse.headers.set('x-provincia-activa-id', provinciaActivaId ?? '')

  console.log('✅ Ruta libre')
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n')
  return supabaseResponse
}

// ═════════════════════════════════════════════════════════
// Helpers
// ═════════════════════════════════════════════════════════

/** Determina si una ruta es pública y no requiere autenticación. */
function esRutaPublica(path: string): boolean {
  // Rutas públicas exactas
  const exactas = ['/login', '/cambiar-password', '/solicitante/registro', '/test-analisis']
  if (exactas.includes(path)) return true

  // Prefijos públicos (pero NO /api/admin ni /api/gerencia)
  const prefijos = ['/auth']
  if (prefijos.some(p => path.startsWith(p))) return true

  // /api/* es público EXCEPTO /api/admin/* y /api/gerencia/*
  if (path.startsWith('/api')) {
    if (path.startsWith('/api/admin') || path.startsWith('/api/gerencia')) {
      return false // Requieren autenticación
    }
    return true
  }

  // Simulador y PWA: públicos en desarrollo
  if (path.startsWith('/simulador') || path.startsWith('/pwa')) {
    console.log('🧪 Ruta de simulación/PWA — acceso público en desarrollo')
    return true
  }

  return false
}

/** Determina si una ruta es del área de admin (ceo_admin). */
function esAdminRuta(path: string): boolean {
  return path.startsWith('/admin') || path.startsWith('/api/admin')
}

/**
 * Verifica el acceso a una ruta según el rol.
 * Retorna 'permitido', 'denegado', o 'publico'.
 * Las rutas de admin (/admin/*, /api/admin/*) son exclusivas de ceo_admin.
 * Las rutas de gerencia (/gerencia, /api/gerencia/*) requieren gerente_franquicia o ceo_admin.
 */
function verificarAcceso(path: string, rol: string | null, esAdmin: boolean): 'permitido' | 'denegado' {
  // ceo_admin tiene acceso a todo
  if (rol === 'ceo_admin') return 'permitido'

  // Rutas exclusivas de ceo_admin
  if (esAdmin) {
    return rol === 'ceo_admin' ? 'permitido' : 'denegado'
  }

  // Rutas de gerencia: gerente_franquicia o ceo_admin
  const esRutaGerencia = path.startsWith('/gerencia') || path.startsWith('/api/gerencia')
  if (esRutaGerencia) {
    if (rol === 'gerente_franquicia') return 'permitido'
    // ceo_admin ya fue manejado arriba
    return 'denegado'
  }

  return 'permitido'
}

// ═════════════════════════════════════════════════════════
// Config
// ═════════════════════════════════════════════════════════
export const config = {
  matcher: [
    '/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)',
  ],
}
