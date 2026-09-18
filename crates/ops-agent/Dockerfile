# syntax=docker/dockerfile:1

ARG RUST_VERSION=1.96.0
ARG AETHERGATEWAY_VERSION=0.1.3
ARG AETHERGATEWAY_SOURCE_REVISION=unknown
ARG AETHERGATEWAY_SOURCE_STATE=unknown
ARG AETHERGATEWAY_BUILD_DATE=unknown
FROM rust:${RUST_VERSION}-bookworm AS builder

ARG AETHERGATEWAY_SOURCE_REVISION
ARG AETHERGATEWAY_SOURCE_STATE
ENV AETHERGATEWAY_BUILD_REVISION=${AETHERGATEWAY_SOURCE_REVISION}
ENV AETHERGATEWAY_BUILD_SOURCE_STATE=${AETHERGATEWAY_SOURCE_STATE}

WORKDIR /app
COPY Cargo.toml Cargo.lock ./
COPY src ./src
COPY migrations ./migrations
COPY crates ./crates

RUN cargo build --release --locked -p aethergateway-ops-agent

FROM debian:bookworm-slim AS runtime

RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates curl \
  && rm -rf /var/lib/apt/lists/*

RUN useradd --system --home /nonexistent --shell /usr/sbin/nologin aethergateway-ops \
  && mkdir -p /var/lib/aethergateway-ops \
  && chown -R aethergateway-ops:aethergateway-ops /var/lib/aethergateway-ops

COPY --from=builder /app/target/release/aethergateway-ops-agent /usr/local/bin/aethergateway-ops-agent
COPY --from=builder /app/Cargo.lock /usr/share/aethergateway/sbom/Cargo.lock

ARG AETHERGATEWAY_SOURCE_REVISION
ARG AETHERGATEWAY_SOURCE_STATE
ARG AETHERGATEWAY_VERSION
ARG AETHERGATEWAY_BUILD_DATE
LABEL org.opencontainers.image.title="AetherGateway Operations Agent" \
      org.opencontainers.image.description="Deterministic read-only operations agent for AetherGateway" \
      org.opencontainers.image.source="https://github.com/PeaceMaker-best/AetherGateway" \
      org.opencontainers.image.revision="$AETHERGATEWAY_SOURCE_REVISION" \
      org.opencontainers.image.version="$AETHERGATEWAY_VERSION" \
      org.opencontainers.image.created="$AETHERGATEWAY_BUILD_DATE" \
      org.opencontainers.image.licenses="MIT" \
      io.aethergateway.source-state="$AETHERGATEWAY_SOURCE_STATE"

USER aethergateway-ops

ENV AETHERGATEWAY_OPS_BIND=0.0.0.0:38083
ENV AETHERGATEWAY_OPS_BASE_URL=http://aethergateway:38082
ENV AETHERGATEWAY_OPS_MODE=disabled
ENV AETHERGATEWAY_OPS_SPOOL_PATH=/var/lib/aethergateway-ops/spool.sqlite
ENV RUST_LOG=aethergateway_ops_agent=info

EXPOSE 38083
VOLUME ["/var/lib/aethergateway-ops"]
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD curl -fsS http://127.0.0.1:38083/readyz >/dev/null || exit 1

ENTRYPOINT ["/usr/local/bin/aethergateway-ops-agent"]
