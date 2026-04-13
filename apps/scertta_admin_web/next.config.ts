import type { NextConfig } from "next";
import path from "path";

const nextConfig: NextConfig = {
  /** Monorepo: dos niveles arriba de apps/scertta_admin_web hacia la raíz del repo */
  outputFileTracingRoot: path.resolve(process.cwd(), "../.."),
  transpilePackages: ["react-map-gl", "mapbox-gl", "@mapbox/mapbox-gl-draw"],
  experimental: {
    serverActions: {
      bodySizeLimit: "2mb",
    },
  },
};

export default nextConfig;
