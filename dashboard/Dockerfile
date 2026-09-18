# syntax=docker/dockerfile:1

ARG AETHERGATEWAY_VERSION=0.1.3
ARG AETHERGATEWAY_SOURCE_REVISION=unknown
ARG AETHERGATEWAY_SOURCE_STATE=unknown
ARG AETHERGATEWAY_BUILD_DATE=unknown
FROM node:24-bookworm-slim AS builder

WORKDIR /app
COPY dashboard/package.json dashboard/package-lock.json ./
RUN npm ci --no-audit --no-fund

COPY dashboard ./
ARG VITE_API_BASE_URL=
ENV VITE_API_BASE_URL=${VITE_API_BASE_URL}
RUN npm run build

FROM nginx:1.30.4-alpine AS runtime

ARG AETHERGATEWAY_VERSION
ARG AETHERGATEWAY_SOURCE_REVISION
ARG AETHERGATEWAY_SOURCE_STATE
ARG AETHERGATEWAY_BUILD_DATE
LABEL org.opencontainers.image.title="AetherGateway Dashboard" \
      org.opencontainers.image.description="Same-origin administration dashboard for AetherGateway" \
      org.opencontainers.image.source="https://github.com/PeaceMaker-best/AetherGateway" \
      org.opencontainers.image.revision="$AETHERGATEWAY_SOURCE_REVISION" \
      org.opencontainers.image.version="$AETHERGATEWAY_VERSION" \
      org.opencontainers.image.created="$AETHERGATEWAY_BUILD_DATE" \
      org.opencontainers.image.licenses="MIT" \
      io.aethergateway.source-state="$AETHERGATEWAY_SOURCE_STATE"

COPY deploy/docker/dashboard.nginx-main.conf /etc/nginx/nginx.conf
COPY deploy/docker/dashboard.nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /app/dist /usr/share/nginx/html
COPY --from=builder /app/package.json /app/package-lock.json /usr/share/aethergateway/sbom/

USER nginx

EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8080/ >/dev/null || exit 1
