{
  pkgs,
  identity,
  username ? "ky",
  ...
}:
{
  security.pam.services.sudo_local.touchIdAuth = true;

  # The only key that may log in (declared in identity.nix). sshd reads it via
  # nix-darwin's AuthorizedKeysCommand; ~/.ssh/authorized_keys is ignored.
  users.users.${username}.openssh.authorizedKeys.keys = [ identity.sshKeys.yoruLogin ];

  # sshd: keys only (no password / kbd-interactive), no root login, restricted
  # to the primary user and to keys declared in Nix. Apple's launchd job
  # (com.openssh.sshd) listens on *:22 on every network and ignores
  # ListenAddress, so it is turned off here (`false`, not null, makes
  # nix-darwin boot it out). The host runs the same /usr/sbin/sshd itself,
  # bound to an address of its choosing; see hosts/yoru (tailnet only). These
  # settings still apply to it, since they are written to
  # /etc/ssh/sshd_config.d regardless.
  services.openssh = {
    enable = false;
    extraConfig = ''
      PasswordAuthentication no
      KbdInteractiveAuthentication no
      PermitRootLogin no
      AllowUsers ${username}
      AuthorizedKeysFile none
    '';
  };

  # mosh-server for roaming sessions (UDP 60000-61000, started over ssh).
  environment.systemPackages = [ pkgs.mosh ];
}
