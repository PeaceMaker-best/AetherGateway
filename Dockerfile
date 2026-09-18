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
# Embedded at compile time via include_str! (src/model_catalog.rs,
# src/runtime_adapter.rs); a missing directory fails `cargo build`.
COPY resources ./resources

RUN cargo build --release --locked -p model-port

FROM debian:bookworm-slim AS runtime

RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates curl \
  && rm -rf /var/lib/apt/lists/*

RUN useradd --system --home /nonexistent --shell /usr/sbin/nologin aethergateway
RUN mkdir -p /data /config \
  && chown -R aethergateway:aethergateway /data /config

COPY --from=builder /app/target/release/model-port /usr/local/bin/model-port
COPY --from=builder /app/Cargo.lock /usr/share/aethergateway/sbom/Cargo.lock

# Keep source metadata after dependency and binary layers so a new commit label
# does not invalidate the slow apt or Rust build cache.
ARG AETHERGATEWAY_SOURCE_REVISION
ARG AETHERGATEWAY_SOURCE_STATE
ARG AETHERGATEWAY_VERSION
ARG AETHERGATEWAY_BUILD_DATE
LABEL org.opencontainers.image.title="AetherGateway" \
      org.opencontainers.image.description="Self-hosted multi-protocol model gateway" \
      org.opencontainers.image.source="https://github.com/PeaceMaker-best/AetherGateway" \
      org.opencontainers.image.revision="$AETHERGATEWAY_SOURCE_REVISION" \
      org.opencontainers.image.version="$AETHERGATEWAY_VERSION" \
      org.opencontainers.image.created="$AETHERGATEWAY_BUILD_DATE" \
      org.opencontainers.image.licenses="MIT" \
      io.aethergateway.source-state="$AETHERGATEWAY_SOURCE_STATE"

USER aethergateway

ENV AETHERGATEWAY_BIND=0.0.0.0:38082
ENV AETHERGATEWAY_STATE_DIR=/data
ENV AETHERGATEWAY_CONFIG=/config/config.toml
ENV RUST_LOG=model_port=info,tower_http=info

EXPOSE 38082
VOLUME ["/data"]
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -fsS http://127.0.0.1:38082/livez >/dev/null || exit 1

ENTRYPOINT ["/usr/local/bin/model-port"]
