
{ modulesPath, ... }:

{
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
  ];

  # ホスト名
  networking.hostName = "nixos-bootstrap";

  # mDNSによるホスト名の公開
  services.avahi = {
    enable = true;
    ipv4 = true;
    ipv6 = false;
    openFirewall = true;

    publish = {
      enable = true;
      addresses = true;
    };
  };

  # SSHサーバー
  services.openssh = {
    enable = true;
    openFirewall = true;

    settings = {
      PermitRootLogin = "yes";
      PermitEmptyPasswords = "yes";
      PasswordAuthentication = true;
    };
  };

  # インストーラー専用の空パスワード認証
  users.users.root.initialHashedPassword = "";
  security.pam.services.sshd.allowNullPassword = true;
}
