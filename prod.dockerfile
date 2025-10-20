# ====================================================================================
# Etapa 2: Runner - Crea la imagen final de producción
# ====================================================================================
FROM node:20-alpine AS runner

WORKDIR /app

# Establece el entorno a producción
ENV NODE_ENV=production
# Deshabilita la telemetría de Next.js
ENV NEXT_TELEMETRY_DISABLED 1

# Crea un usuario y grupo dedicado para ejecutar la aplicación
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs


# Cambia al usuario no-root para mejorar la seguridad
USER nextjs

# Copia los artefactos de la compilación 'standalone' desde la etapa 'builder'
# Esto incluye el servidor mínimo y solo los node_modules necesarios
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

# Copia la carpeta 'public' si existe
COPY --from=builder --chown=nextjs:nodejs /app/public ./public

# Expone el puerto en el que se ejecutará la aplicación
EXPOSE 3000

# Define el comando para iniciar el servidor de Next.js
# El archivo server.js es generado por la salida 'standalone'
CMD ["node", "server.js"]
