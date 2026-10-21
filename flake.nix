{
  description = "Homelab NixOS bootstrap";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { nixpkgs, ... }: {
    nixosConfigurations.bootstrap =
      nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        modules = [
          ({ modulesPath, ... }: {
            imports = [
              "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
            ];
          })
        ];
      };
  };
}
