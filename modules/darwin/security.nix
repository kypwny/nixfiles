{
  pkgs,
  identity,
  username ? "ky",
  ...
}:
{
  security.pam.services.sudo_local.touchIdAuth = true;

  users.users.${username}.openssh.authorizedKeys.keys = [
    # Secretive Secure Enclave key (public half declared in identity.nix).
    identity.sshKeys.yoruEcdsa
  ];

  # sshd: keys only (no password / kbd-interactive), no root login, restricted to primary user.
  # No source-address allowlist: reachable from any network the Mac joins.
  services.openssh = {
    enable = true;
    extraConfig = ''
      PasswordAuthentication no
      KbdInteractiveAuthentication no
      PermitRootLogin no
      AllowUsers ${username}
    '';
  };

  # mosh-server for roaming sessions (UDP 60000-61000, started over ssh).
  environment.systemPackages = [ pkgs.mosh ];
}
