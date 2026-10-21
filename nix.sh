
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

case "${1:-}" in
  iso)
    mkdir -p dist

    docker compose run --rm \
      -e HOST_UID="$(id -u)" \
      -e HOST_GID="$(id -g)" \
      nix sh -eu -c '
        output=$(nix build \
          --no-link \
          --print-out-paths \
          ".#nixosConfigurations.bootstrap.config.system.build.isoImage")

        cp "$output"/iso/*.iso /workspace/dist/

        chown "$HOST_UID:$HOST_GID" \
          /workspace/dist/*.iso
      '
    ;;

  *)
    docker compose run --rm nix nix "$@"
    ;;
esac

sudo chown "$(id -u):$(id -g)" flake.lock
