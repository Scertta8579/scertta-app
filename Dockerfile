# ── Next.js Production Dockerfile ──
# Build: docker build -t scertta-nextjs .
# Run: docker run -p 3006:3006 --env-file .env.production scertta-nextjs

FROM node:22-alpine AS base
RUN corepack enable && corepack prepare pnpm@latest --activate
WORKDIR /app

# ── Dependencies ──
FROM base AS deps
COPY package.json pnpm-workspace.yaml pnpm-lock.yaml ./
COPY apps/scertta_admin_web/package.json apps/scertta_admin_web/
RUN pnpm install --frozen-lockfile --prod false

# ── Builder ──
FROM base AS builder
COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/apps/scertta_admin_web/node_modules ./apps/scertta_admin_web/node_modules
COPY . .
ENV NEXT_PUBLIC_SUPABASE_URL=https://TU_PROYECTO.supabase.co
ENV NEXT_PUBLIC_SUPABASE_ANON_KEY=sb_publishable_TU_CLAVE_PUBLICA
ENV SUPABASE_SERVICE_ROLE_KEY=sb_secret_TU_CLAVE_SECRETA
RUN pnpm run build

# ── Runner ──
FROM base AS runner
ENV NODE_ENV=production
ENV PORT=3006

COPY --from=builder /app/apps/scertta_admin_web/.next ./apps/scertta_admin_web/.next
COPY --from=builder /app/apps/scertta_admin_web/package.json ./apps/scertta_admin_web/
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/apps/scertta_admin_web/node_modules ./apps/scertta_admin_web/node_modules
COPY --from=builder /app/package.json /app/pnpm-workspace.yaml ./

EXPOSE 3006
CMD ["sh", "-c", "cd apps/scertta_admin_web && npx next start -p 3006"]
