#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib.sh"
cd "$ROOT_DIR"

load_env

# The root Compose file constructs this URL when operators configure the
# component POSTGRES_* values instead of a complete URL. Mirror that expansion
# for static validation only; host start scripts still require an endpoint that
# is reachable from the host.
if [[ -z "${AETHERGATEWAY_DATABASE_URL:-}" && -n "${AETHERGATEWAY_POSTGRES_PASSWORD:-}" ]]; then
  export AETHERGATEWAY_DATABASE_URL="postgres://${AETHERGATEWAY_POSTGRES_USER:-aethergateway}:${AETHERGATEWAY_POSTGRES_PASSWORD}@postgres:5432/${AETHERGATEWAY_POSTGRES_DB:-aethergateway}"
fi

if [[ "${AETHERGATEWAY_FORCE_BUILD:-0}" != "1" ]] && release_is_fresh; then
  "$RELEASE_BIN" config validate
  exit 0
fi

setup_cc_fallback
cargo run --locked --bin model-port -- config validate
