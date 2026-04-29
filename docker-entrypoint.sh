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

# If something is already listening on the target port, try to terminate it
# so OpenChamber can bind the port. We look for sockets in /proc/net/{tcp,tcp6},
# map their inodes to owning PIDs, and attempt a graceful then forceful kill.
PORT="${OPENCHAMBER_PORT:-3000}"
hex=$(printf '%04x' "$PORT")
inodes=""
for netfile in /proc/net/tcp /proc/net/tcp6; do
  [ -r "$netfile" ] || continue
  for inode in $(awk -v p=":${hex}$" 'NR>1 && $2 ~ p {print $10}' "$netfile" 2>/dev/null); do
    [ -z "$inode" ] || inodes="$inodes $inode"
  done
done

pids_to_kill=""
for inode in $inodes; do
  [ -z "$inode" ] && continue
  for pid_dir in /proc/[0-9]*; do
    pid=$(basename "$pid_dir")
    fd_dir="$pid_dir/fd"
    [ -d "$fd_dir" ] || continue
    for fd in "$fd_dir"/*; do
      link=$(readlink "$fd" 2>/dev/null || true)
      [ -z "$link" ] && continue
      case "$link" in
        socket:\[$inode\]) pids_to_kill="$pids_to_kill $pid"; break 2;;
      esac
    done
  done
done

# Dedupe PIDs
pids_final=""
for pid in $pids_to_kill; do
  found=0
  for seen in $pids_final; do
    if [ "$pid" = "$seen" ]; then
      found=1
      break
    fi
  done
  if [ "$found" -eq 0 ] 2>/dev/null; then
    pids_final="$pids_final $pid"
  fi
done

if [ -n "$pids_final" ]; then
  echo "[entrypoint] found processes listening on port $PORT:$pids_final"
  for pid in $pids_final; do
    [ -z "$pid" ] && continue
    if [ "$pid" = "$$" ] || [ "$pid" = "1" ]; then
      echo "[entrypoint] skipping kill of pid $pid (entrypoint/init)"
      continue
    fi
    echo "[entrypoint] terminating pid $pid listening on port $PORT"
    kill "$pid" 2>/dev/null || true
    sleep 1
    if [ -d "/proc/$pid" ]; then
      echo "[entrypoint] pid $pid still alive; sending SIGKILL"
      kill -KILL "$pid" 2>/dev/null || true
    fi
  done

  # wait up to 5 seconds for processes to disappear
  i=0
  while [ $i -lt 5 ]; do
    still=0
    for pid in $pids_final; do
      [ -z "$pid" ] && continue
      if [ -d "/proc/$pid" ]; then still=1; break; fi
    done
    [ $still -eq 0 ] && break
    i=$((i+1))
    sleep 1
  done
fi

echo "[entrypoint] starting OpenChamber on ${OPENCHAMBER_HOST:-0.0.0.0}:${OPENCHAMBER_PORT:-3000}"
exec_cmd "$@"
