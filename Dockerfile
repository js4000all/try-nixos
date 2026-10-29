FROM debian:trixie-slim

ARG UID=1000
ARG GID=1000

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        nix-bin \
        ca-certificates \
        git \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid ${GID} nix \
    && useradd --uid ${UID} --gid ${GID} --create-home --shell /bin/bash nix \
    && mkdir -p /nix/store /nix/var/nix/db /nix/var/nix/profiles /nix/var/nix/gcroots \
                 /nix/var/log/nix /etc/nix /workspace \
    && printf '%s\n' \
         'experimental-features = nix-command flakes' \
         'sandbox = false' \
         'build-users-group =' \
         'substituters = https://cache.nixos.org/' \
         'trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=' \
       > /etc/nix/nix.conf \
    && chown -R ${GID}:${UID} /nix /home/nix /workspace

ENV USER=nix HOME=/home/nix NIX_REMOTE=local
USER ${GID}:${UID}
WORKDIR /workspace
