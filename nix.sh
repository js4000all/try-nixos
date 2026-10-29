#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
export NIX_WORKDIR="$PWD"
runtime="${CONTAINER_RUNTIME:-docker}"

if ! command -v "$runtime" >/dev/null 2>&1; then
  printf 'error: container runtime not found: %s\n' "$runtime" >&2
  exit 127
fi

compose=("$runtime" compose -f "$script_dir/compose.yml" run --rm)

if [[ ! -t 0 || ! -t 1 ]]; then
  compose+=(-T)
fi

if [[ "${1:-}" == exec ]]; then
  shift
  command="${1:-sh}"

  if (( $# > 0 )); then
    shift
  fi
else
  command="nix"
fi

exec "${compose[@]}" --entrypoint "$command" nix "$@"
