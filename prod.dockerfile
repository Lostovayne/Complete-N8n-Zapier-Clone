# ====================================================================================
# Etapa 1: Dependencies - Instala todas las dependencias
# ====================================================================================
FROM oven/bun:alpine AS deps
WORKDIR /app

# Copia los archivos de dependencias
COPY package.json bun.lock ./

# Instala TODAS las dependencias (necesarias para el build)
RUN bun install --frozen-lockfile

# ====================================================================================
# Etapa 2: Builder - Compila la aplicación Next.js
# ====================================================================================
FROM oven/bun:alpine AS builder
WORKDIR /app

# Copia las dependencias instaladas
COPY --from=deps /app/node_modules ./node_modules

# Copia todo el código fuente
COPY . .

# Deshabilita la telemetría durante el build
ENV NEXT_TELEMETRY_DISABLED=1

# Genera el cliente Prisma
RUN bunx prisma generate

# Compila la aplicación con salida standalone
RUN bun run build

# ====================================================================================
# Etapa 3: Runner - Crea la imagen final de producción
# ====================================================================================
FROM node:20-alpine AS runner
WORKDIR /app

# Establece el entorno a producción
ENV NODE_ENV=production

# Deshabilita la telemetría de Next.js
ENV NEXT_TELEMETRY_DISABLED=1

# Crea un usuario y grupo dedicado para ejecutar la aplicación
RUN addgroup --system --gid 1001 nodejs && \
  adduser --system --uid 1001 nextjs

# Copia los artefactos de la compilación 'standalone' desde la etapa 'builder'
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

# Copia la carpeta 'public' si existe
COPY --from=builder --chown=nextjs:nodejs /app/public ./public

# --- Copiar el cliente Prisma generado y la carpeta prisma si se requiere en runtime ---
# Esto asegura que lib/generated (client + binarios) esté presente en la imagen final.
COPY --from=builder --chown=nextjs:nodejs /app/lib/generated ./lib/generated
COPY --from=builder --chown=nextjs:nodejs /app/prisma ./prisma

# Cambia al usuario no-root para mejorar la seguridad
USER nextjs

# Expone el puerto en el que se ejecutará la aplicación
EXPOSE 3000

# Define el comando para iniciar el servidor de Next.js
CMD ["node", "server.js"]
