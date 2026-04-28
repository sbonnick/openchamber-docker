#!/usr/bin/env sh
set -eu

HOME="${HOME:-/home/openchamber}"
export HOME

OPENCODE_CONFIG_DIR="${OPENCODE_CONFIG_DIR:-${HOME}/.config/opencode}"
export OPENCODE_CONFIG_DIR

mkdir -p \
  "${HOME}/.config/openchamber" \
  "${OPENCODE_CONFIG_DIR}" \
  "${HOME}/.local/state" \
  "${HOME}/.local/share/opencode" \
  "${HOME}/.ssh" \
  "${HOME}/workspace"

RUN_AS_OPENCHAMBER=false
if [ "$(id -u)" = "0" ]; then
  chown -R openchamber:openchamber \
    "${HOME}/.config/openchamber" \
    "${OPENCODE_CONFIG_DIR}" \
    "${HOME}/.local" \
    "${HOME}/.ssh" \
    "${HOME}/workspace" 2>/dev/null || true

  if gosu openchamber sh -c 'mkdir -p "$HOME/.local/share/opencode/log" "$HOME/.local/state" "$OPENCODE_CONFIG_DIR" "$HOME/.ssh" "$HOME/workspace" && test -w "$HOME/.local/share/opencode" && test -w "$HOME/.local/state" && test -w "$OPENCODE_CONFIG_DIR" && test -w "$HOME/.ssh" && test -w "$HOME/workspace"' 2>/dev/null; then
    RUN_AS_OPENCHAMBER=true
  else
    echo "[entrypoint] warning: mounted data directories are not writable by uid 1000; running as root inside the container" >&2
  fi
fi

run_cmd() {
  if [ "${RUN_AS_OPENCHAMBER}" = "true" ]; then
    gosu openchamber "$@"
  else
    "$@"
  fi
}

exec_cmd() {
  if [ "${RUN_AS_OPENCHAMBER}" = "true" ]; then
    exec gosu openchamber "$@"
  else
    exec "$@"
  fi
}

if ! run_cmd chmod 700 "${HOME}/.ssh" 2>/dev/null; then
  echo "[entrypoint] warning: cannot chmod ${HOME}/.ssh, continuing" >&2
fi

SSH_PRIVATE_KEY_PATH="${HOME}/.ssh/id_ed25519"
SSH_PUBLIC_KEY_PATH="${SSH_PRIVATE_KEY_PATH}.pub"

if [ ! -f "${SSH_PRIVATE_KEY_PATH}" ] || [ ! -f "${SSH_PUBLIC_KEY_PATH}" ]; then
  if [ -w "${HOME}/.ssh" ]; then
    echo "[entrypoint] generating SSH key..."
    run_cmd ssh-keygen -t ed25519 -N "" -f "${SSH_PRIVATE_KEY_PATH}" >/dev/null 2>&1 || true
  else
    echo "[entrypoint] warning: ${HOME}/.ssh is not writable; skipping SSH key generation" >&2
  fi
fi

run_cmd chmod 600 "${SSH_PRIVATE_KEY_PATH}" 2>/dev/null || true
run_cmd chmod 644 "${SSH_PUBLIC_KEY_PATH}" 2>/dev/null || true

if [ -f "${SSH_PUBLIC_KEY_PATH}" ]; then
  echo "[entrypoint] SSH public key:"
  cat "${SSH_PUBLIC_KEY_PATH}"
fi

if [ "$#" -gt 0 ]; then
  exec_cmd "$@"
fi

set -- openchamber serve \
  --host "${OPENCHAMBER_HOST:-0.0.0.0}" \
  --port "${OPENCHAMBER_PORT:-3000}" \
  --foreground

if [ -n "${OPENCHAMBER_UI_PASSWORD:-}" ]; then
  set -- "$@" --ui-password "${OPENCHAMBER_UI_PASSWORD}"
fi

echo "[entrypoint] starting OpenChamber on ${OPENCHAMBER_HOST:-0.0.0.0}:${OPENCHAMBER_PORT:-3000}"
exec_cmd "$@"
