let
  adminUser = "ky";
  adminHome = "/home/${adminUser}";
  repoRoot = "${adminHome}/code/nixfiles";
  stateVersion = "26.05";
  lanPrefixLength = 24;
in
{
  host = {
    name = "navi";
    system = "x86_64-linux";
    inherit stateVersion;
  };

  user = {
    name = adminUser;
    group = "users";
    uid = 1000;
    gid = 100;
    home = adminHome;
    authorizedKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILrGOBlnxXx7U52BuS+M2swzKufwu1A76RyjfHK8w48A pwny"
      # unicorn (~/.ssh/ky on yoru) -- same primary key kura trusts
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDw0aRfa+YINgWJP7FKsRZ+swvPOLE5cc94ZyijkZFoX unicorn"
      # yoru's ecdsa key, as already authorised in modules/darwin/security.nix
      "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBM01ry/NcHpDTNGz0kkmtj11FsY8NvbAEX7fRfmQOfy9rAaJ4ZY/5EZJehSuJC1PvGTDf6YP1tZhqCf+fW/HgpA="
    ];
    # crypt(3) hash copied from this machine's current /etc/shadow entry for ky
    # (README, "Install"); lives on /persist (neededForBoot) so it is readable
    # before users are activated.
    hashedPasswordFile = "/persist/secrets/ky.passwd";
  };

  network = rec {
    bridge = "br0";
    primaryInterface = "enp4s0";
    wifiInterface = "wlp5s0";
    prefixLength = lanPrefixLength;
    # DHCP, like kura: the old static 192.168.1.215/24 profile survived the move
    # to the 192.168.67.0/24 LAN and its dead default route (metric 425, below
    # wifi's 600) black-holed all traffic while the cable was out. With no
    # hostCidr the shared networking module sets br0 to ipv4 "auto".
    # Only read by the (disabled) qbittorrent container module:
    gateway = "192.168.67.1";
  };

  paths = {
    home = adminHome;
    repo = repoRoot;
  };
}
