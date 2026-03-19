// Configuración de Supabase para Scertta
// INSTRUCCIONES:
// 1. Copia este archivo como 'supabase_config.dart'
// 2. Reemplaza 'TU_ANON_KEY_AQUI' con tu ANON_KEY real
// 3. Obtén tu ANON_KEY desde: Supabase Dashboard → Settings → API → anon public

class SupabaseConfig {
  // URL del proyecto Supabase
  static const String supabaseUrl = 'https://cmuhwyxmluhnlzcasceq.supabase.co';
  
  // ANON KEY - Obtener desde: Supabase Dashboard → Settings → API → anon public
  static const String anonKey = 'TU_ANON_KEY_AQUI';
  
  // Edge Function URL
  static const String edgeFunctionBienvenida = 
      'https://cmuhwyxmluhnlzcasceq.supabase.co/functions/v1/enviar-bienvenida';
}
