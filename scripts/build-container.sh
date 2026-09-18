#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib.sh"

allow_dirty=0
with_ops_agent=0
for option in "$@"; do
  case "$option" in
    --allow-dirty) allow_dirty=1 ;;
    --with-ops-agent) with_ops_agent=1 ;;
    --help|-h)
      cat <<'USAGE'
Usage: scripts/build-container.sh [--allow-dirty] [--with-ops-agent]

Build the gateway and dashboard images with source provenance labels.
  --with-ops-agent  Also build the optional operations agent image.
  --allow-dirty     Allow uncommitted changes for local testing only.
USAGE
      exit 0
      ;;
    *) die "unknown option: $option; use --help" ;;
  esac
done

source_revision="$(git -C "$ROOT_DIR" rev-parse HEAD)"
source_state="clean"
build_date="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
if [[ -n "$(git -C "$ROOT_DIR" status --porcelain=v1)" ]]; then
  source_state="dirty"
  if [[ "$allow_dirty" != "1" ]]; then
    die "refusing to build a release image from a dirty worktree; commit the reviewed changes or use --allow-dirty for local testing"
  fi
fi

build_context="$ROOT_DIR"
snapshot_dir=""
cleanup() {
  if [[ -n "$snapshot_dir" ]]; then
    rm -rf "$snapshot_dir"
  fi
}
trap cleanup EXIT
if [[ "$source_state" == "clean" ]]; then
  # Pin every image to the same immutable source even if the worktree changes
  # during a long build. Dirty local tests deliberately use the working tree.
  snapshot_dir="$(mktemp -d "${TMPDIR:-/tmp}/aethergateway-build.XXXXXX")"
  git -C "$ROOT_DIR" archive "$source_revision" | tar -x -C "$snapshot_dir"
  build_context="$snapshot_dir"
fi
aethergateway_version="$(
  sed -n 's/^version = "\([^"]*\)"/\1/p' "$build_context/Cargo.toml" | head -n 1
)"
if [[ -z "$aethergateway_version" ]]; then
  die "could not read package version from Cargo.toml"
fi
log "building AetherGateway images version=$aethergateway_version revision=$source_revision source_state=$source_state"
common_args=(
  --build-arg "AETHERGATEWAY_VERSION=$aethergateway_version"
  --build-arg "AETHERGATEWAY_SOURCE_REVISION=$source_revision"
  --build-arg "AETHERGATEWAY_SOURCE_STATE=$source_state"
  --build-arg "AETHERGATEWAY_BUILD_DATE=$build_date"
)

docker build \
  "${common_args[@]}" \
  --file "$build_context/Dockerfile" \
  --tag aethergateway:local \
  "$build_context"
docker build \
  "${common_args[@]}" \
  --file "$build_context/dashboard/Dockerfile" \
  --tag aethergateway-dashboard:local \
  "$build_context"
images=(aethergateway:local aethergateway-dashboard:local)
if [[ "$with_ops_agent" == "1" ]]; then
  docker build \
    "${common_args[@]}" \
    --file "$build_context/crates/ops-agent/Dockerfile" \
    --tag aethergateway-ops-agent:local \
    "$build_context"
  images+=(aethergateway-ops-agent:local)
fi

for image in "${images[@]}"; do
  image_id="$(docker image inspect "$image" --format '{{.Id}}')"
  image_revision="$(docker image inspect "$image" --format '{{index .Config.Labels "org.opencontainers.image.revision"}}')"
  image_state="$(docker image inspect "$image" --format '{{index .Config.Labels "io.aethergateway.source-state"}}')"
  image_version="$(docker image inspect "$image" --format '{{index .Config.Labels "org.opencontainers.image.version"}}')"

  if [[ "$image_revision" != "$source_revision" || "$image_state" != "$source_state" || "$image_version" != "$aethergateway_version" ]]; then
    die "$image provenance labels do not match the requested source state"
  fi
  log "built $image id=$image_id version=$image_version revision=$image_revision source_state=$image_state"
done

log "start these source-built images with: AETHERGATEWAY_LOCAL_BUILD=1 scripts/compose-up.sh"
if [[ "$with_ops_agent" == "1" ]]; then
  log "enable the agent with: COMPOSE_PROFILES=ops-agent AETHERGATEWAY_LOCAL_BUILD=1 scripts/compose-up.sh"
fi
