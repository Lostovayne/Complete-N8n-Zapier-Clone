FROM node:20-alpine

# Establece el entorno de desarrollo
ENV NODE_ENV development
ENV NEXT_TURBOPACK_CACHE_PATH /tmp/turbopack-cache

# Define el directorio de trabajo
WORKDIR /usr/src/app

# Copia los archivos de manifiesto y los instala
# Esto aprovecha el cache de capas de Docker
COPY package*.json ./
RUN npm install

# Copia el resto del código. El volumen de Docker Compose lo mantendrá sincronizado.
COPY . .

# Ensure runtime dirs belong to the node user before dropping privileges.
RUN mkdir -p /tmp/turbopack-cache \
    && chown -R node:node /tmp/turbopack-cache /usr/src/app

# Expone el puerto de la aplicación
EXPOSE 3000

# Comando para iniciar el servidor de desarrollo
CMD ["npm", "run", "dev"]
