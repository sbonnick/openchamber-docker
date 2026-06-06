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
CI_FILE=".github/workflows/publish-image.yml"
DOCKERFILE="Dockerfile"
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
CUR_OC_DOCKER=$(sed -n 's/^ARG OPENCHAMBER_VERSION=//p' "$DOCKERFILE")
CUR_OK_DOCKER=$(sed -n 's/^ARG OPENCODE_VERSION=//p' "$DOCKERFILE")
CUR_TT_DOCKER=$(sed -n 's/^ARG TTYD_VERSION=//p' "$DOCKERFILE")
CUR_OC_CI=$(sed -n 's/^  OPENCHAMBER_VERSION: "\(.*\)"/\1/p' "$CI_FILE")
CUR_OK_CI=$(sed -n 's/^  OPENCODE_VERSION: "\(.*\)"/\1/p' "$CI_FILE")
CUR_TT_CI=$(sed -n 's/^  TTYD_VERSION: "\(.*\)"/\1/p' "$CI_FILE")
CUR_TT_COMPOSE=$(sed -n 's/^        TTYD_VERSION: "${TTYD_VERSION:-\(.*\)}"/\1/p' "$COMPOSE_BUILD")

echo ""
echo "Current versions:"
echo "  Dockerfile:           OpenChamber=${CUR_OC_DOCKER}  OpenCode=${CUR_OK_DOCKER}  ttyd=${CUR_TT_DOCKER}"
echo "  CI workflow:          OpenChamber=${CUR_OC_CI}  OpenCode=${CUR_OK_CI}  ttyd=${CUR_TT_CI}"
echo "  docker-compose.build: ttyd=${CUR_TT_COMPOSE}"

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

maybe_update "OpenChamber" "$CUR_OC_DOCKER" "$LATEST_OPENCHAMBER" "$DOCKERFILE" \
  "s/^ARG OPENCHAMBER_VERSION=${CUR_OC_DOCKER}/ARG OPENCHAMBER_VERSION=${LATEST_OPENCHAMBER}/"

maybe_update "OpenCode" "$CUR_OK_DOCKER" "$LATEST_OPENCODE" "$DOCKERFILE" \
  "s/^ARG OPENCODE_VERSION=${CUR_OK_DOCKER}/ARG OPENCODE_VERSION=${LATEST_OPENCODE}/"

maybe_update "ttyd" "$CUR_TT_DOCKER" "$LATEST_TTYD" "$DOCKERFILE" \
  "s/^ARG TTYD_VERSION=${CUR_TT_DOCKER}/ARG TTYD_VERSION=${LATEST_TTYD}/"

maybe_update "OpenChamber" "$CUR_OC_CI" "$LATEST_OPENCHAMBER" "$CI_FILE" \
  "s/OPENCHAMBER_VERSION: \"${CUR_OC_CI}\"/OPENCHAMBER_VERSION: \"${LATEST_OPENCHAMBER}\"/"

maybe_update "OpenCode" "$CUR_OK_CI" "$LATEST_OPENCODE" "$CI_FILE" \
  "s/OPENCODE_VERSION: \"${CUR_OK_CI}\"/OPENCODE_VERSION: \"${LATEST_OPENCODE}\"/"

maybe_update "ttyd" "$CUR_TT_CI" "$LATEST_TTYD" "$CI_FILE" \
  "s/TTYD_VERSION: \"${CUR_TT_CI}\"/TTYD_VERSION: \"${LATEST_TTYD}\"/"

maybe_update "ttyd" "$CUR_TT_COMPOSE" "$LATEST_TTYD" "$COMPOSE_BUILD" \
  "s/TTYD_VERSION: \"\${TTYD_VERSION:-${CUR_TT_COMPOSE}}\"/TTYD_VERSION: \"\${TTYD_VERSION:-${LATEST_TTYD}}\"/"

echo ""
if [ "$UPDATED" = true ]; then
  echo "Updates applied. Review and commit with:"
  echo "  git add ${DOCKERFILE} ${CI_FILE} ${COMPOSE_BUILD} && git commit"
else
  echo "All versions are up to date."
fi
