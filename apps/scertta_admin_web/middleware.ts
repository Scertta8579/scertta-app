import { createServerClient } from '@supabase/ssr'
import { NextResponse, type NextRequest } from 'next/server'

export async function middleware(request: NextRequest) {
  let supabaseResponse = NextResponse.next({
    request,
  })

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
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

  const path = request.nextUrl.pathname

  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
  console.log('🛡️ MIDDLEWARE - Verificando acceso')
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
  console.log(`📍 Ruta solicitada: ${path}`)
  console.log(`👤 Usuario: ${user?.email ?? 'No autenticado'}`)

  // Rutas públicas (no requieren autenticación)
  const rutasPublicas = ['/login', '/registro', '/solicitante/registro']
  
  if (rutasPublicas.includes(path)) {
    console.log('✅ Ruta pública - Acceso permitido')
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n')
    return supabaseResponse
  }

  // Si no hay usuario, redirigir a login
  if (!user) {
    console.log('❌ No autenticado - Redirigiendo a /login')
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n')
    
    const redirectUrl = request.nextUrl.clone()
    redirectUrl.pathname = '/login'
    return NextResponse.redirect(redirectUrl)
  }

  // Obtener rol del usuario desde tabla perfiles
  console.log('🔍 Consultando rol del usuario...')
  
  let rolUsuario: string | null = null
  
  try {
    const { data: perfil, error } = await supabase
      .from('perfiles')
      .select('rol')
      .eq('id', user.id)
      .maybeSingle()

    if (error) {
      console.log(`⚠️ Error al consultar perfil: ${error.message}`)
    } else if (perfil) {
      rolUsuario = perfil.rol
      console.log(`✅ Rol encontrado: ${rolUsuario}`)
    } else {
      console.log('⚠️ No se encontró perfil para el usuario')
    }
  } catch (e) {
    console.log(`⚠️ Error al obtener rol: ${e}`)
  }

  // Definir permisos por ruta
  const permisosPorRuta: Record<string, string[]> = {
    '/ceo-dashboard': ['ceo'],
    '/back-office': ['ceo', 'operador', 'admin'],
    '/marketing': ['ceo', 'marketing'],
    '/libro-numeros': ['ceo', 'contable'],
    '/solicitante': ['solicitante', 'ceo'],
    '/socio-conductor': ['conductor', 'ceo'],
  }

  // Verificar permisos para rutas protegidas
  for (const [ruta, rolesPermitidos] of Object.entries(permisosPorRuta)) {
    if (path.startsWith(ruta)) {
      console.log(`🔒 Ruta protegida: ${ruta}`)
      console.log(`   Roles permitidos: ${rolesPermitidos.join(', ')}`)
      console.log(`   Rol del usuario: ${rolUsuario ?? 'Sin rol'}`)

      if (!rolUsuario || !rolesPermitidos.includes(rolUsuario)) {
        console.log('❌ ACCESO DENEGADO - Rol no autorizado')
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n')
        
        const redirectUrl = request.nextUrl.clone()
        redirectUrl.pathname = '/acceso-denegado'
        return NextResponse.redirect(redirectUrl)
      }

      console.log('✅ ACCESO PERMITIDO - Rol autorizado')
      console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n')
      return supabaseResponse
    }
  }

  // Ruta no protegida específicamente, permitir acceso
  console.log('✅ Ruta no restringida - Acceso permitido')
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n')
  
  return supabaseResponse
}

export const config = {
  matcher: [
    /*
     * Match all request paths except for the ones starting with:
     * - _next/static (static files)
     * - _next/image (image optimization files)
     * - favicon.ico (favicon file)
     * - public folder
     */
    '/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)',
  ],
}
