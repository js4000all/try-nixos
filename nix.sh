
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
      --entrypoint sh \
      nix -eu -c '
        output=$(nix build \
          --no-link \
          --print-out-paths \
          ".#nixosConfigurations.bootstrap.config.system.build.isoImage")

        cp "$output"/iso/*.iso /workspace/dist/

        chown "$HOST_UID:$HOST_GID" \
          /workspace/dist/*.iso
      '
    ;;

  exec)
    shift

    if [ "$#" -eq 0 ]; then
      exec docker compose run --rm \
        --entrypoint sh \
        nix
    fi

    exec docker compose run --rm \
      --entrypoint "$1" \
      nix "${@:2}"
    ;;

  *)
    exec docker compose run --rm nix nix "$@"
    ;;
esac
