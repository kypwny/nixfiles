{
  pkgs,
  username ? "ky",
  ...
}:
{
  security.pam.services.sudo_local.touchIdAuth = true;

  users.users.${username}.openssh.authorizedKeys.keys = [
    # Key from ~/.ssh/authorized_keys
    "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBM01ry/NcHpDTNGz0kkmtj11FsY8NvbAEX7fRfmQOfy9rAaJ4ZY/5EZJehSuJC1PvGTDf6YP1tZhqCf+fW/HgpA="
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
