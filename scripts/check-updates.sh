#!/usr/bin/env bash
set -euo pipefail

fetch_latest_tag() {
  local repo="$1"
  curl -sL "https://api.github.com/repos/${repo}/releases/latest" \
    | python3 -c "import sys,json; print(json.load(sys.stdin)['tag_name'].lstrip('v'))"
}

# --- Config ---
OPENCHAMBER_REPO="openchamber/openchamber"
OPENCODE_REPO="anomalyco/opencode"
TTYD_REPO="tsl0922/ttyd"
COMPOSE_BUILD="docker-compose.build.yml"

# --- Fetch latest ---
echo "Fetching latest releases..."
LATEST_OPENCHAMBER=$(fetch_latest_tag "$OPENCHAMBER_REPO")
LATEST_OPENCODE=$(fetch_latest_tag "$OPENCODE_REPO")
LATEST_TTYD=$(fetch_latest_tag "$TTYD_REPO")
echo "  OpenChamber latest: v${LATEST_OPENCHAMBER}"
echo "  OpenCode latest:    v${LATEST_OPENCODE}"
echo "  ttyd latest:        v${LATEST_TTYD}"

# --- Read current ---
CUR_OC_COMPOSE=$(sed -n 's/^        OPENCHAMBER_VERSION: "${OPENCHAMBER_VERSION:-\(.*\)}"/\1/p' "$COMPOSE_BUILD")
CUR_OK_COMPOSE=$(sed -n 's/^        OPENCODE_VERSION: "${OPENCODE_VERSION:-\(.*\)}"/\1/p' "$COMPOSE_BUILD")
CUR_TT_COMPOSE=$(sed -n 's/^        TTYD_VERSION: "${TTYD_VERSION:-\(.*\)}"/\1/p' "$COMPOSE_BUILD")

echo ""
echo "Current versions:"
echo "  docker-compose.build: OpenChamber=${CUR_OC_COMPOSE}  OpenCode=${CUR_OK_COMPOSE}  ttyd=${CUR_TT_COMPOSE}"

UPDATED=false

maybe_update() {
  local label="$1" cur="$2" latest="$3" file="$4" sed_expr="$5"
  if [ "$cur" != "$latest" ]; then
    echo ""
    echo "  Updating ${label} in ${file}: ${cur} -> ${latest}"
    sed -i "$sed_expr" "$file"
    UPDATED=true
  else
    echo "  ${label} in ${file} is current (${cur})."
  fi
}

echo ""

maybe_update "OpenChamber" "$CUR_OC_COMPOSE" "$LATEST_OPENCHAMBER" "$COMPOSE_BUILD" \
  "s/OPENCHAMBER_VERSION: \"\${OPENCHAMBER_VERSION:-${CUR_OC_COMPOSE}}\"/OPENCHAMBER_VERSION: \"\${OPENCHAMBER_VERSION:-${LATEST_OPENCHAMBER}}\"/"

maybe_update "OpenCode" "$CUR_OK_COMPOSE" "$LATEST_OPENCODE" "$COMPOSE_BUILD" \
  "s/OPENCODE_VERSION: \"\${OPENCODE_VERSION:-${CUR_OK_COMPOSE}}\"/OPENCODE_VERSION: \"\${OPENCODE_VERSION:-${LATEST_OPENCODE}}\"/"

maybe_update "ttyd" "$CUR_TT_COMPOSE" "$LATEST_TTYD" "$COMPOSE_BUILD" \
  "s/TTYD_VERSION: \"\${TTYD_VERSION:-${CUR_TT_COMPOSE}}\"/TTYD_VERSION: \"\${TTYD_VERSION:-${LATEST_TTYD}}\"/"

echo ""
if [ "$UPDATED" = true ]; then
  echo "Updates applied. Review and commit with:"
  echo "  git add ${COMPOSE_BUILD} && git commit"
else
  echo "All versions are up to date."
fi