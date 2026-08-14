import type { NextConfig } from "next";
import path from "path";

const cspHeader = [
  "default-src 'self'",
  "script-src 'self' 'unsafe-inline' 'unsafe-eval'",
  "style-src 'self' 'unsafe-inline' https://rutmy.com",
  "img-src 'self' data: blob: http://192.168.0.4:3000 http://localhost:3000 https://TU_PROYECTO.supabase.co https://rutmy.com https://*.scertta.com",
  "connect-src 'self' http://192.168.0.4:3000 http://192.168.0.4:8002 http://localhost:3000 http://localhost:8002 https://*.supabase.co wss://*.supabase.co https://rutmy.com https://*.scertta.com https://fonts.openmaptiles.org",
  "font-src 'self'",
  "worker-src 'self' blob: https://rutmy.com",
  "frame-src 'self'",
  "frame-ancestors 'none'",
  "media-src 'self' blob:",
].join("; ");

const nextConfig: NextConfig = {
  /** Monorepo: dos niveles arriba de apps/scertta_admin_web hacia la raíz del repo */
  outputFileTracingRoot: path.resolve(process.cwd(), "../.."),
  transpilePackages: ["react-map-gl", "maplibre-gl", "@mapbox/mapbox-gl-draw"],
  webpack: (config) => {
    // Alias: el draw plugin interno de @mapbox/mapbox-gl-draw busca "mapbox-gl" → resolvemos a maplibre-gl
    config.resolve.alias = {
      ...config.resolve.alias,
      "mapbox-gl": "maplibre-gl",
    };
    return config;
  },
  typescript: { ignoreBuildErrors: true },
  experimental: {
    serverActions: {
      bodySizeLimit: "2mb",
    },
  },
  async headers() {
    return [
      {
        source: "/(.*)",
        headers: [
          { key: "Content-Security-Policy", value: cspHeader },
          { key: "X-Frame-Options", value: "DENY" },
          { key: "X-Content-Type-Options", value: "nosniff" },
          { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
          { key: "Permissions-Policy", value: "camera=(), microphone=(), geolocation=()" },
          { key: "Strict-Transport-Security", value: "max-age=31536000; includeSubDomains" },
        ],
      },
    ];
  },
};

export default nextConfig;
