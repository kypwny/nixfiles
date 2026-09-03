let
  adminUser = "ky";
  adminHome = "/home/${adminUser}";
  repoRoot = "${adminHome}/nixfiles";
  stateVersion = "26.05";
  lanPrefixLength = 24;
  mkCidr = address: "${address}/${toString lanPrefixLength}";
in
{
  host = {
    name = "kura";
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
    primaryInterface = "enp1s0";
    prefixLength = lanPrefixLength;
    hostAddress = "192.168.1.31";
    hostCidr = mkCidr hostAddress;
    gateway = "192.168.1.1";
    hostDns = "192.168.1.1;";
    containerNameservers = [
      "1.1.1.1"
      "9.9.9.9"
    ];
  };

  containers = {
    personalWebserver = rec {
      name = "personal-webserver";
      address = "192.168.1.51";
      cidr = mkCidr address;
    };
    qbittorrent = rec {
      name = "qbittorrent";
      address = "192.168.1.52";
      cidr = mkCidr address;
    };
    minecraft = rec {
      name = "minecraft";
      address = "192.168.1.54";
      cidr = mkCidr address;
    };
  };

  paths = {
    home = adminHome;
    repo = repoRoot;
    i2pKey = "${adminHome}/webserver/kypwny.dat";
    wireguardConfig = "${adminHome}/webserver/wireguard/wg0.conf";
    minecraftData = "${adminHome}/minecraft/fabric-server";
    minecraftSecrets = "${adminHome}/minecraft/secrets";
    qbittorrentWebUiEnv = "${adminHome}/qbittorrent/webui.env";
    mediaMount = "/srv/media-usb";
  };
}
