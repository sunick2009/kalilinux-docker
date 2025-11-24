#!/usr/bin/env bash
set -euo pipefail

if [ "${DOTFILES_RUNTIME_BOOTSTRAP:-0}" = "1" ]; then
  if ! /usr/local/bin/bootstrap-dotfiles.sh; then
    if [ "${BOOTSTRAP_STRICT:-1}" = "1" ]; then
      echo "[entrypoint] bootstrap failed"; exit 1
    else
      echo "[entrypoint] bootstrap failed; continuing due to BOOTSTRAP_STRICT=0"
    fi
  fi
else
  echo "[entrypoint] skipping dotfiles bootstrap (handled at build time)"
fi

# 交棒給原來的 VNC/noVNC 啟動腳本
exec /bin/bash /startup.sh "$@"