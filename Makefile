SHELL := /bin/sh
.DEFAULT_GOAL := help
NIX := ./nix.sh
HOST ?= bootstrap
ISO_ATTR := .\#nixosConfigurations.$(HOST).config.system.build.isoImage

.PHONY: help show check iso devices flash clean
help:
	@echo 'make iso      - Build NixOS ISO and copy it to dist/'
	@echo 'make devices  - Show USB-connected disks'
	@echo 'make flash    - Interactively select USB disk and write the ISO'
	@echo 'make check    - Check flake'
	@echo 'make show     - Show flake'

show:
	$(NIX) flake show
check:
	$(NIX) flake check
iso:
	mkdir -p dist
	$(NIX) exec sh -eu -c 'output=$$(nix build --no-link --print-out-paths "$(ISO_ATTR)"); cp "$$output"/iso/*.iso /workspace/dist/'
devices:
	lsblk -dn -o PATH,SIZE,MODEL,TRAN,RM,TYPE
flash:
	./scripts/flash-iso.sh
clean:
	rm -rf dist
