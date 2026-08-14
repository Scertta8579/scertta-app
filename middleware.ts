import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";
import { esRutaProtegida, rutaPorRol } from "@/lib/auth";

type CookieToSet = {
  name: string;
  value: string;
  options?: Parameters<NextResponse["cookies"]["set"]>[2];
};

export async function middleware(request: NextRequest) {
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  if (!supabaseUrl || !supabaseAnonKey) {
    return NextResponse.next();
  }

  const { pathname, search } = request.nextUrl;

  if (pathname.startsWith("/solicitante/registro")) {
    return NextResponse.next();
  }

  const response = NextResponse.next({
    request: { headers: request.headers },
  });

  const cookiesToSet: CookieToSet[] = [];

  const supabase = createServerClient(supabaseUrl, supabaseAnonKey, {
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(cookies) {
        cookies.forEach(({ name, value, options }) => {
          cookiesToSet.push({ name, value, options });
          response.cookies.set(name, value, options);
        });
      },
    },
  });

  const {
    data: { user },
  } = await supabase.auth.getUser();

  const applyCookies = (res: NextResponse) => {
    cookiesToSet.forEach(({ name, value, options }) => {
      res.cookies.set(name, value, options);
    });
    return res;
  };

  const redirectToLogin = () => {
    const loginUrl = new URL("/login", request.url);
    if (pathname !== "/" && pathname !== "/login") {
      loginUrl.searchParams.set("redirectTo", `${pathname}${search}`);
    }
    return applyCookies(NextResponse.redirect(loginUrl));
  };

  if (!user) {
    if (pathname === "/" || esRutaProtegida(pathname)) return redirectToLogin();
    return response;
  }

  const { data: perfil } = await supabase
    .from("perfiles")
    .select("rol")
    .eq("id", user.id)
    .maybeSingle();

  const destino = rutaPorRol(perfil?.rol);

  if (pathname === "/" || pathname === "/login") {
    return applyCookies(NextResponse.redirect(new URL(destino, request.url)));
  }

  if (esRutaProtegida(pathname) && !pathname.startsWith(destino)) {
    return applyCookies(NextResponse.redirect(new URL(destino, request.url)));
  }

  return response;
}

export const config = {
  matcher: [
    "/",
    "/login",
    "/solicitante/:path*",
    "/socio-conductor/:path*",
    "/back-office/:path*",
    "/ceo-dashboard/:path*",
    "/marketing/:path*",
    "/finanzas/:path*",
    "/gerencia/:path*",
    "/flota/:path*",
    "/rrhh/:path*",
    "/soporte/:path*",
    "/hub/:path*",
    "/admin/:path*",
    "/legales/:path*",
    "/api/:path*",
  ],
};

