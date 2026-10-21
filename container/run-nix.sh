#!/usr/bin/env bash
set -euo pipefail

cleanup() {
  if [[ -e /workspace/flake.lock ]]; then
    chown "$HOST_UID:$HOST_GID" /workspace/flake.lock
  fi
}

trap cleanup EXIT

nix "$@"
