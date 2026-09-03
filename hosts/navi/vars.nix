let
  adminUser = "ky";
  adminHome = "/home/${adminUser}";
  repoRoot = "${adminHome}/code/nixfiles";
  stateVersion = "26.05";
  lanPrefixLength = 24;
  mkCidr = address: "${address}/${toString lanPrefixLength}";
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
    ];
  };

  network = rec {
    bridge = "br0";
    primaryInterface = "enp4s0";
    wifiInterface = "wlp5s0";
    prefixLength = lanPrefixLength;
    # LAN DHCP/static allocation observed during audit: 192.168.1.215 (or .30)
    hostAddress = "192.168.1.215";
    hostCidr = mkCidr hostAddress;
    gateway = "192.168.1.1";
    hostDns = "192.168.1.1";
  };

  paths = {
    home = adminHome;
    repo = repoRoot;
  };
}
