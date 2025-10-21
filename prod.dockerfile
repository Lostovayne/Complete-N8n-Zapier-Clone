# ====================================================================================
# Etapa 1: Dependencies - Instala todas las dependencias
# ====================================================================================
FROM node:20-alpine AS deps
WORKDIR /app

# Instala dependencias necesarias para compilación nativa
RUN apk add --no-cache libc6-compat

# Copia los archivos de dependencias
COPY package.json package-lock.json* ./

# Instala las dependencias
RUN npm ci --only=production && \
    npm cache clean --force

# ====================================================================================
# Etapa 2: Builder - Compila la aplicación Next.js
# ====================================================================================
FROM node:20-alpine AS builder
WORKDIR /app

# Copia las dependencias instaladas
COPY --from=deps /app/node_modules ./node_modules

# Copia todo el código fuente
COPY . .

# Deshabilita la telemetría durante el build
ENV NEXT_TELEMETRY_DISABLED 1

# Compila la aplicación con salida standalone
RUN npm run build

# ====================================================================================
# Etapa 3: Runner - Crea la imagen final de producción
# ====================================================================================
FROM node:20-alpine AS runner
WORKDIR /app

# Establece el entorno a producción
ENV NODE_ENV=production

# Deshabilita la telemetría de Next.js
ENV NEXT_TELEMETRY_DISABLED 1

# Crea un usuario y grupo dedicado para ejecutar la aplicación
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

# Copia los artefactos de la compilación 'standalone' desde la etapa 'builder'
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

# Copia la carpeta 'public' si existe
COPY --from=builder --chown=nextjs:nodejs /app/public ./public

# Cambia al usuario no-root para mejorar la seguridad
USER nextjs

# Expone el puerto en el que se ejecutará la aplicación
EXPOSE 3000

# Define el comando para iniciar el servidor de Next.js
CMD ["node", "server.js"]
