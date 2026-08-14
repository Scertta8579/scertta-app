import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

export async function GET(request: NextRequest) {
  const { searchParams, origin } = request.nextUrl;
  const code = searchParams.get("code");
  const next = searchParams.get("next") ?? "/hub";
  const type = searchParams.get("type");

  // Si hay código, intercambiarlo por sesión (PKCE flow: recovery, magic link, etc.)
  if (code) {
    const supabase = createServerClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
      {
        cookies: {
          getAll() {
            return request.cookies.getAll();
          },
          setAll(cookiesToSet) {
            cookiesToSet.forEach(({ name, value, options }) =>
              request.cookies.set(name, value)
            );
          },
        },
      }
    );

    const { error } = await supabase.auth.exchangeCodeForSession(code);

    if (error) {
      console.error("❌ Auth callback error:", error.message);
      return NextResponse.redirect(
        `${origin}/login?error=auth_callback_failed`
      );
    }

    // Si es recovery (password reset), redirigir a cambiar contraseña
    if (type === "recovery") {
      return NextResponse.redirect(
        `${origin}/cambiar-password?recovery=1`
      );
    }

    // Otros flujos: magic link, signup, etc.
    return NextResponse.redirect(`${origin}${next}`);
  }

  // Sin código: redirigir al login
  return NextResponse.redirect(`${origin}/login`);
}
