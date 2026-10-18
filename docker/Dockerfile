# syntax=docker/dockerfile:1

# ---------- Etapa 1: dependencias de producción ----------
FROM node:26-alpine AS deps
WORKDIR /build
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --ignore-scripts && npm cache clean --force

# ---------- Etapa 2: runtime distroless, sin shell ni gestor de paquetes ----------
FROM gcr.io/distroless/nodejs22-debian12:nonroot
WORKDIR /app
ENV NODE_ENV=production
COPY --from=deps --chown=65532:65532 /build/node_modules ./node_modules
COPY --chown=65532:65532 package.json ./
COPY --chown=65532:65532 src ./src
USER 65532:65532
EXPOSE 8080
# El ENTRYPOINT de distroless ya es "node"
CMD ["src/server.js"]
