# Multi-stage: a imagem final não carrega o toolchain de build nem as
# devDependencies. Em ARM com 2 vCPU, imagem menor também sobe mais rápido.
FROM node:22-alpine AS build
WORKDIR /app
RUN corepack enable
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile
COPY tsconfig.json nest-cli.json ./
COPY src ./src
RUN pnpm build && pnpm prune --prod

FROM node:22-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production
# Não roda como root: o contêiner divide o host com driva e love-secret.
USER node
COPY --from=build --chown=node:node /app/node_modules ./node_modules
COPY --from=build --chown=node:node /app/dist ./dist
COPY --from=build --chown=node:node /app/package.json ./package.json
EXPOSE 3333
CMD ["node", "dist/main"]
