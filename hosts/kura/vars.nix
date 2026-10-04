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
      # unicorn (~/.ssh/ky on yoru) — the primary from now on
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDw0aRfa+YINgWJP7FKsRZ+swvPOLE5cc94ZyijkZFoX unicorn"
      # pwny (~/.ssh/id_ed25519) — legacy; drop once unicorn is confirmed working
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILrGOBlnxXx7U52BuS+M2swzKufwu1A76RyjfHK8w48A pwny"
    ];
    passwordlessSudo = true;
  };

  network = rec {
    bridge = "br0";
    primaryInterface = "enp1s0";
    prefixLength = lanPrefixLength;
    # DHCP: no hostAddress/hostCidr/hostDns here. The shared networking
    # module sees their absence and sets the br0 profile to ipv4 "auto".
    # Resolve the host from other machines as kura.local (Avahi/mDNS) or via
    # Tailscale MagicDNS.
    # Only used by the (currently disabled) qbittorrent container:
    gateway = "192.168.67.1"; # assumed router address on the new LAN
    containerNameservers = [
      "1.1.1.1"
      "9.9.9.9"
    ];
  };

  containers = {
    qbittorrent = rec {
      name = "qbittorrent";
      address = "192.168.67.52";
      cidr = mkCidr address;
    };
  };

  paths = {
    home = adminHome;
    repo = repoRoot;
    qbittorrentWebUiEnv = "${adminHome}/qbittorrent/webui.env";
    mediaMount = "/srv/media-usb";
  };
}
