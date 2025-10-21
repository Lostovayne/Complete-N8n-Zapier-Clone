# clone-n8n — Plataforma clon de n8n (Next.js 16 + Bun) — Documentación empresarial

Versión: 1.0.0
Última actualización: 2025-10-21

Este repositorio contiene una implementación base y lista para producción de un clon de `n8n` construido con `Next.js 16` (API y app routing modernos) y optimizado para usar `bun` como runtime / gestor de paquetes. Incluye configuraciones para construir imágenes Docker, desplegar en plataformas como Railway y DigitalOcean (Registry + Droplet / App Platform) y pipelines de CI/CD con `GitHub Actions` que crean y publican imágenes tanto en `DigitalOcean Container Registry` como en `GitHub Container Registry (GHCR)`.

Este README está orientado a equipos de ingeniería empresarial: describe arquitectura, flujos CI/CD, guías de despliegue, variables críticamente necesarias, ejemplos de uso y prácticas recomendadas de seguridad y observabilidad.

---

Tabla de contenidos

- [Visión general y objetivos](#visión-general-y-objetivos)
- [Arquitectura y componentes](#arquitectura-y-componentes)
- [Diagrama CI/CD y flujo de acciones](#diagrama-cicd-y-flujo-de-acciones)
- [Quickstart (desarrollo local con Bun)](#quickstart-desarrollo-local-con-bun)
- [Build y Docker (local y CI)](#build-y-docker-local-y-ci)
- [Despliegue: DigitalOcean y Railway](#despliegue-digitalocean-y-railway)
- [Variables de entorno y secretos necesarios](#variables-de-entorno-y-secretos-necesarios)
- [Observabilidad y métricas](#observabilidad-y-métricas)
- [Seguridad y buenas prácticas](#seguridad-y-buenas-prácticas)
- [Mantenimiento, contribuciones y SLA](#mantenimiento-contribuciones-y-sla)
- [Resolución de problemas comunes](#resolución-de-problemas-comunes)
- [Licencia y créditos](#licencia-y-créditos)

---

Visión general y objetivos

- Proveer una base completa, reproducible y apta para producción para un clon de `n8n` con:
  - `Next.js 16` (app router, soporte para server components y edge runtimes)
  - `bun` como runtime alternativo y gestor de paquetes (instalación rápida, arranque y bundle nativo cuando aplique)
  - Pipelines CI/CD que construyen imágenes multi-arch y las publican en registries privados/órganicos
  - Integración con `DigitalOcean Registry` y `GHCR` (útil para Railway o despliegues privados)
  - Dockerfiles separados para `dev` y `prod`
  - Estrategia opinionada para entornos: `local`, `staging` y `production`

Uso principal: Orquestación de flujos (workflows) similar a `n8n`, extensible y preparado para integración continua, despliegue automático y escalado por contenedores.

---

Arquitectura y componentes

Componentes principales:

- `app/` — Código de aplicación con rutas de `Next.js` y componentes (UI, API endpoints).
- `prod.dockerfile` / `dev.dockerfile` — Dockerfiles optimizados para producción y desarrollo.
- `.github/workflows/deploy.yml` — Workflow de GitHub Actions que construye y publica imágenes.
- `docker-compose.yml` — Opciones para levantar servicios localmente (dev/prod).
- CI/CD variables: secretos para `DIGITALOCEAN_ACCESS_TOKEN`, `GITHUB_TOKEN` (automático) y opcionales para Railway.

Patrón de ejecución:

- Local dev: `bun` para instalación, `bun dev` / `next dev` con turbopack.
- Build: `next build` con `--turbopack` o configuración de `bun` en container.
- Release: pipeline que crea imagen con `docker buildx` y la etiqueta para `DO` y `GHCR`.

Arquitectura de despliegue (roles):

- Imágenes producidas en CI —> Registries (DO & GHCR)
- DO Registry: imagen privada para uso corporativo y despliegue a DigitalOcean App Platform / Droplets.
- GHCR: imagen pública/privada consumible por Railway (o por otros servicios que requieren credenciales GHCR).

---

Diagrama CI/CD y flujo de acciones

Resumen del pipeline `GitHub Actions`:

1. Trigger: `push` / `pull_request` en `main`.
2. Checkout del repo.
3. Setup `docker buildx`.
4. Login a `DigitalOcean` (usa `doctl` y `DIGITALOCEAN_ACCESS_TOKEN`).
5. Login a `GHCR` (usa `docker/login-action` con `GITHUB_TOKEN`).
6. Build de la imagen (single build + múltiples tags).
7. Push a `DigitalOcean Registry` y `GHCR` (solo en `push` a `main`).
8. Garbage collection opcional en DigitalOcean.
9. Notificación / outputs con las URLs de las imágenes.

Diagrama (alto nivel, CI/CD):

```/dev/null/ci-cd-mermaid.mmd#L1-120
%% Mermaid diagram - CI/CD (renderable where Mermaid supported)
%% Repositorio -> Actions -> Build -> Registries -> Deployment Targets
flowchart TD
  A[Repo: main] -->|push/pr| B[GitHub Actions: Build & Push]
  B --> C{Steps}
  C --> C1[Checkout]
  C --> C2[Setup buildx]
  C --> C3[Login DO (doctl)]
  C --> C4[Login GHCR]
  C --> C5[Build multi-tag image]
  C --> C6[Push DO Registry]
  C --> C7[Push GHCR]
  C --> C8[Cleanup DO garbage]
  C8 --> D[Outputs: DO & GHCR URLs]
  D --> E[Deployment targets]
  E --> E1[DigitalOcean App / Droplet / K8s]
  E --> E2[Railway (pull GHCR)]
  E --> E3[CI/CD notifications / Slack / PagerDuty]
```

Nota: El archivo de workflow real se encuentra en `.github/workflows/deploy.yml` y realiza exactamente estos pasos: construcción con `buildx`, login a DO usando `doctl`, login a GHCR y push condicional en `main`.

---

Quickstart — desarrollo local con `bun`

Requisitos recomendados en el equipo de desarrollo:

- `bun` >= 1.x (para gestor de paquetes y runtime opcional)
- Node >= 20 (si se prefiere `node` runtime)
- Docker (para pruebas de contenedor)
- `doctl` si interactúas con DigitalOcean localmente

Instalación (bun):

```/dev/null/quickstart-bun.sh#L1-12
# Instalar bun (si no está instalado)
curl -fsSL https://bun.sh/install | bash

# Instalar dependencias usando bun
bun install

# Levantar app en modo desarrollo
# (Next 16 puede ejecutarse con bun si se configura, de lo contrario usa node)
bun run dev
# o con npm/yarn fallback
# npm run dev
```

Consejos:

- `bun` mejora tiempos de instalación y arranque. Si usas features nativas de `node` incompatible, cae a `node` en los scripts.
- Para asegurar paridad con CI, valida builds en un contenedor que use `bun` o `node` según la estrategia que elija tu equipo.

---

Build y Docker (local & CI)

Comandos locales (sin CI):

```/dev/null/docker-commands.sh#L1-20
# Build local (producción)
docker build -f prod.dockerfile -t mycompany/clone-n8n:latest .

# Ejecutar contenedor
docker run -p 3000:3000 --env-file .env.production mycompany/clone-n8n:latest

# Para desarrollo con docker-compose
docker-compose up dev
```

Recomendaciones para Dockerfile:

- Base imagen multi-stage (builder: node/bun image; runtime: minimal `node:alpine` o `bun` runtime).
- Instalar solo dependencias de producción en la etapa final.
- Exponer puerto 3000 y definir `HEALTHCHECK`.
- Incluir variable `NODE_ENV=production` o `BUN_INSTALL` segun corresponda.

Ejemplo de etiquetas en CI (lo que hace el workflow):

- `registry.digitalocean.com/<namespace>/<image>:latest`
- `ghcr.io/<owner>/<repo>:latest`

El workflow actual: ver `.github/workflows/deploy.yml` — crea la imagen una única vez y aplica dos tags para publicar en ambos registries.

---

Despliegue: DigitalOcean y Railway

DigitalOcean (Registry + App Platform / Droplet / K8s):

- Crear Registry:

```/dev/null/doctl-commands.sh#L1-12
doctl auth init --access-token $DIGITALOCEAN_ACCESS_TOKEN
doctl registry create <registry-name>
doctl registry login
# push desde CI o local
docker push registry.digitalocean.com/<registry-name>/<image>:latest
```

- En App Platform o en un Cluster/Kubernetes, apuntar al registry y configurar las variables de entorno y secrets.

Railway (usar GHCR):

- Railway puede consumir una imagen alojada en `ghcr.io`. En la UI de Railway, selecciona "Deploy from image" y proporciona:
  - Image: `ghcr.io/<owner>/<repo>:latest`
  - Si la imagen es privada, configurar `username` = `<owner>` y `password` = GitHub Personal Access Token o `GITHUB_TOKEN` con los permisos adecuados.
- Puedes configurar auto-deploy en Railway cuando la nueva etiqueta `latest` aparezca en GHCR.

Notas:

- El workflow actual empuja a ambos registries, pero solo ejecuta push cuando el evento es `push` en `refs/heads/main`.
- Para despliegue automático a staging/prod, puedes usar tags o ramas diferentes y condicionar los `if:` en el workflow.

---

Variables de entorno y secretos necesarios

GitHub Secrets (requeridos por el workflow):

- `DIGITALOCEAN_ACCESS_TOKEN` — token con scope para Registry y garbage-collection.
- `GITHUB_TOKEN` — provisto por GitHub Actions; usado para login en GHCR (en el workflow ya se usa).
  Opcionales/para Railway:
- `RAILWAY_TOKEN` / `RAILWAY_PROJECT_ID` — si automatizas despliegues vía CLI/API.
- `DO_REGISTRY_NAME` — nombre del registry en DO (se usa en el workflow).

Variables de entorno de la app (ejemplos):

- `NEXT_PUBLIC_API_BASE_URL` — URL pública del API.
- `DATABASE_URL` — conexión a base de datos (encriptada/secret).
- `REDIS_URL` — para caching/state de workflows.
- `JWT_SECRET` — firma de tokens.
- `SENTRY_DSN` — opcional: observabilidad.
- `NODE_ENV` / `BUN_ENV`

Asegúrate de guardar secrets en los mecanismos de vault/secrets management de la plataforma (GitHub Secrets, DO Project Secrets, Railway Environment variables).

---

Observabilidad y métricas

Recomendado:

- Integrar `Sentry`/`DataDog`/`Prometheus` para errores y métricas.
- Agregar `liveness` y `readiness` endpoints en la app. Definir `HEALTHCHECK` en `Dockerfile`.
- Logs estructurados (JSON) para facilitar ingestion por ELK/Datadog/Logflare.
- Monitoreo de cola de workflows y retries.

Ejemplo de `HEALTHCHECK` en Dockerfile (sugerencia):

```/dev/null/healthcheck-example.sh#L1-8
HEALTHCHECK --interval=30s --timeout=5s --retries=3 CMD curl -f http://localhost:3000/api/health || exit 1
```

---

Seguridad y buenas prácticas

- Nunca comitees secretos. Verifica `.gitignore` y usa `git-secrets` o similares.
- Limita scopes de tokens:
  - `DIGITALOCEAN_ACCESS_TOKEN` con permisos mínimos para registry.
  - Prefiere tokens con expiración rotativa y almacén de secretos.
- Habilita escaneo de dependencias en CI (`dependabot` ya existe en repo).
- Habilita protección de ramas (`main`) y políticas de revisión.
- Política de seguridad: mantener imágenes base actualizadas con rebuilds regulares.
- Firmado y escaneo de imágenes: considera `cosign` o `notary` para imágenes de producción.

---

Mantenimiento, contribuciones y SLA

Contribuciones:

- Sigue el flujo de PRs: rama feature -> PR -> 1-2 revisores, pruebas passing en CI.
- Commit messages: Conventional Commits (recomendado).

Release & Changelog:

- Mantener `CHANGELOG.md` con un changelog semántico.
- Tags semánticos: `vMAJOR.MINOR.PATCH` y pipelines que publiquen según tags.

SLA y runbook:

- Definir responsables de on-call y playbooks para restauración rápida (DB rollback, re-baseline images).

---

Resolución de problemas comunes

- CI falla logueo DO: valida `DIGITALOCEAN_ACCESS_TOKEN` en Secrets y que no haya restricciones IP.
- Imagen muy grande: inspecciona `docker history` y reduce capas; usa `node:slim` o `distroless`.
- Timouts en buildx: aumentar `--build-arg` o dividir builds por plataforma.
- Railway no puede acceder a GHCR: si la imagen es privada, añadir credenciales en Railway variables.

Comandos diagnósticos:

```/dev/null/diagnostics.sh#L1-20
# Ver imágenes locales
docker images

# Ver logs de GitHub Actions (desde UI)

# Validar login DO localmente
doctl registry login
```

---

Archivos importantes (referencias)

- `prod.dockerfile`, `dev.dockerfile` — Dockerfiles para producción y desarrollo.
- `.github/workflows/deploy.yml` — Pipeline de CI/CD que genera y publica imágenes.
- `docker-compose.yml` — Configs para `dev` y `prod`.
- `package.json` — scripts y dependencias (Next 16, React 19, biomejs lint).

---

Ejemplos rápidos (resumen de scripts)

Instalación + dev con bun:

```/dev/null/scripts.sh#L1-12
bun install
bun run dev
# o
npm install
npm run dev
```

Build local:

```/dev/null/build.sh#L1-8
npm run build
npm start
# o en docker
docker build -f prod.dockerfile -t clone-n8n:latest .
docker run -p 3000:3000 --env-file .env.production clone-n8n:latest
```

---

Contribuciones y soporte

- Issues: abrir en el repositorio con la etiqueta adecuada.
- PRs: rama con prefijo `feature/` o `fix/`, incluir descripciones y screenshots.
- Para soporte empresarial, definir canal SLA (Slack/PagerDuty) en la documentación interna.

---

Licencia y créditos

- Licencia: MIT (o la que su organización defina). Asegúrate de adjuntar `LICENSE` si se requiere.
- Créditos: Proyecto inspirado y estructurado para ser compatible con ideas de `n8n`, `Next.js`, `bun`, y buenas prácticas de CI/CD corporativas.

---

Apéndice: Recursos y enlaces útiles

- Next.js docs: https://nextjs.org/docs
- Bun docs: https://bun.sh/docs
- Docker buildx: https://docs.docker.com/buildx/working-with-buildx/
- DigitalOcean Registry & doctl: https://docs.digitalocean.com
- GitHub Actions: https://docs.github.com/actions

---

Contacto

- Equipo de plataforma: plataforma-team@example.com
- Para despliegues y credenciales: infra-team@example.com
