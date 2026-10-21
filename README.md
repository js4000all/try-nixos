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

