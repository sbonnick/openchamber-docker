#!/usr/bin/env sh
set -eu

HOME="/home/openchamber"
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

  if gosu openchamber sh -c 'mkdir -p "$HOME/.config/openchamber/run" "$OPENCODE_CONFIG_DIR" "$HOME/.local/share/opencode/log" "$HOME/.local/state" "$HOME/.ssh" "$HOME/workspace" && test -w "$HOME/.config/openchamber" && test -w "$OPENCODE_CONFIG_DIR" && test -w "$HOME/.local/share/opencode" && test -w "$HOME/.local/state" && test -w "$HOME/.ssh" && test -w "$HOME/workspace"' 2>/dev/null; then
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

SSH_DIR="${HOME}/.ssh"
SSH_PRIVATE_KEY_PATH="${SSH_DIR}/id_ed25519"
SSH_PUBLIC_KEY_PATH="${SSH_PRIVATE_KEY_PATH}.pub"

mkdir -p "${SSH_DIR}"
if ! run_cmd chmod 700 "${SSH_DIR}" 2>/dev/null; then
  echo "[entrypoint] warning: cannot chmod ${SSH_DIR}, continuing with existing permissions"
fi

if [ ! -f "${SSH_PRIVATE_KEY_PATH}" ] || [ ! -f "${SSH_PUBLIC_KEY_PATH}" ]; then
  if [ ! -w "${SSH_DIR}" ]; then
    echo "[entrypoint] warning: ssh key missing and ${SSH_DIR} is not writable, continuing without SSH key" >&2
  else
    echo "[entrypoint] generating SSH key..."
    if ! run_cmd ssh-keygen -t ed25519 -N "" -f "${SSH_PRIVATE_KEY_PATH}" >/dev/null 2>&1; then
      echo "[entrypoint] warning: failed to generate SSH key, continuing without SSH key" >&2
    fi
  fi
fi

if ! run_cmd chmod 600 "${SSH_PRIVATE_KEY_PATH}" 2>/dev/null; then
  echo "[entrypoint] warning: cannot chmod ${SSH_PRIVATE_KEY_PATH}, continuing"
fi

if ! run_cmd chmod 644 "${SSH_PUBLIC_KEY_PATH}" 2>/dev/null; then
  echo "[entrypoint] warning: cannot chmod ${SSH_PUBLIC_KEY_PATH}, continuing"
fi

if [ -f "${SSH_PUBLIC_KEY_PATH}" ]; then
  echo "[entrypoint] SSH public key:"
  cat "${SSH_PUBLIC_KEY_PATH}"
fi

# Handle UI password environment variable
if [ -n "${UI_PASSWORD:-}" ]; then
  echo "[entrypoint] UI password set, enabling authentication"
fi

if [ "${OH_MY_OPENCODE:-false}" = "true" ]; then
  OMO_CONFIG_FILE="${OPENCODE_CONFIG_DIR}/oh-my-opencode.json"

  if [ ! -f "${OMO_CONFIG_FILE}" ]; then
    echo "[entrypoint] npm installing oh-my-opencode..."
    npm install -g oh-my-opencode

    OMO_INSTALL_ARGS="--no-tui --claude=no --openai=no --gemini=no --copilot=no --opencode-zen=no --zai-coding-plan=no --kimi-for-coding=no --skip-auth"

    echo "[entrypoint] oh-my-opencode installing..."
    oh-my-opencode install ${OMO_INSTALL_ARGS}
  fi
fi

# Docker containers need to listen on all interfaces for port mapping to work.
OPENCHAMBER_HOST="${OPENCHAMBER_HOST:-0.0.0.0}"
export OPENCHAMBER_HOST

echo "[entrypoint] starting..."

if [ "$#" -gt 0 ]; then
  exec_cmd "$@"
fi

set -- bun packages/web/bin/cli.js
if [ -n "${UI_PASSWORD:-}" ]; then
  set -- "$@" --ui-password "$UI_PASSWORD"
fi
run_cmd "$@"

exec_cmd bun packages/web/bin/cli.js logs
