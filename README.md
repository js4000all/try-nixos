# try-nixos
NixOSのセットアップをしてみる


## bootstrapメディアの作成

```bash
./nix.sh --verison
```

`flake.nix`を作成後、
```bash
./nix.sh flake lock
./nix.sh eval .#nixosConfigurations.bootstrap.config.system.build.isoImage.drvPath
./nix.sh iso
```
キャッシュ状態などで変わるが、手元では10〜15分ほど掛かった。

dist配下にISOイメージが作成されるので、USBメモリ等に書き込む。
```bash
ll dist/

total 1.4G
-r--r--r-- 1 user user 1.4G Oct 21 11:23 nixos-minimal-26.05.20261020.cd4ea8d-x86_64-linux.iso

file dist/*.iso
```

書込み先ディスクを確認。
```bash
lsblk -o name,path,size,model,tran,rm,type,mountpoint

NAME   PATH       SIZE MODEL                TRAN RM TYPE MOUNTPOINT
sda    /dev/sda   1.8T ...                  ata   0 disk 
├─sda1 /dev/sda1  1.8T                            0 part /
├─sda2 /dev/sda2    1K                            0 part 
└─sda5 /dev/sda5  976M                            0 part [SWAP]
sdb    /dev/sdb  29.3G USB_Flash_Disk       usb   1 disk 
└─sdb1 /dev/sdb1 29.3G                            1 part 
```

ここではマウントされてないが、マウントされていればアンマウントする。
```bash
sudo umount /dev/sdb1
```

書き込む。
```bash
sudo dd \
  if="$(find dist -maxdepth 1 -name '*.iso' -print -quit)" \
  of=/dev/sdb \
  bs=4M \
  status=progress \
  conv=fsync
```
手元では２分ほど掛かった。

## 対象PCの起動

対象PCにLANケーブルを接続し、bootstrapメディアを装着して起動する。
必要なら、ブートメニューで起動メディアを選択する。
これでbootstrap用のNixOSが起動し、DHCPでIPアドレスを取得した状態になる。

以降は管理PC側で作業する。
管理PCから、mDNSで対象PCに接続する。
```bash
ssh root@nixos-bootstrap.local
```

見つからない場合、Avahi関連パッケージが入っているか確認する。
```bash
sudo apt update
sudo apt install avahi-daemon avahi-utils libnss-mdns
```
また、対象PC側のAvahiがご検出し、mDNS公開名を変更している可能性もある。
以下で接続できる可能性がある他、再起動すれば`nixos-bootstrap.local`でルックアップできる可能性も高い。
```bash
ssh root@nixos-bootstrap-2.local
```

# Nix ISO build and USB writing

The `/nix` directory is kept in a Docker named volume; only the built ISO is copied to `dist/`.

```sh
make iso
make devices
make flash
```

`make flash` requires a local interactive terminal, exactly one `dist/*.iso`, `lsblk`, `sudo`, and `dd`. It lists only USB-connected whole disks **at or below 32 GiB** (configurable using `MAX_DEVICE_GIB`), including USB disks with `RM=0` (some USB sticks report this). Select a **number** from the list; no device is auto-selected.

The script checks the selected disk type, USB connection, capacity, mount points, and stacked block devices. If a partition is mounted, unmount it manually and retry. The script does not unmount anything. It requests sudo authorization, then requires the literal final confirmation `WRITE /dev/sdX` with the actual selected path. The entire chosen disk, including its partition table, will be overwritten irreversibly. Double-check the model and size; USB-connected external SSD/HDD may also be shown. The checks cannot fully prevent a device from being swapped between selection and writing.

If the `dist` directory contains zero or more than one `.iso` files, the command exits without writing. Move obsolete ISOs out of `dist` rather than guessing which to use.

The USB-writing script runs on the host (outside the Nix container). The host's ID/GID 1000:1000 is assumed for the container-generated `dist` artifacts.

The capacity limit is checked when listing devices and again before writing. Override it explicitly if needed:

```sh
MAX_DEVICE_GIB=64 make flash
```

The limit is in binary GiB (`1 GiB = 1,073,741,824 bytes`), inclusive. It is a safeguard, not proof that a disk is safe to overwrite.
