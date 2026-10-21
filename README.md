# try-nixos
NixOSのセットアップをしてみる


## Getting started

```bash
./nix.sh --verison
```

`flake.nix`を作成後、
```bash
./nix.sh flake lock
./nix.sh eval .#nixosConfigurations.bootstrap.config.system.build.isoImage.drvPath
./nix.sh iso
```

dist配下にISOイメージが作成されるので、USBメモリ等に書き込む。
```bash
```
