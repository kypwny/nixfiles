{ identity }:
let
  adminUser = identity.user.name;
  adminHome = identity.homeDirectory;
  repoRoot = "${adminHome}/nixfiles";
  stateVersion = "26.05";
  lanPrefixLength = 24;
  mkCidr = address: "${address}/${toString lanPrefixLength}";
in
{
  host = {
    name = identity.hostname;
    inherit stateVersion;
  };

  user = {
    name = adminUser;
    group = "users";
    uid = identity.user.uid;
    gid = 100;
    home = adminHome;
    authorizedKeys = [
      # unicorn (~/.ssh/ky on yoru) — the primary from now on
      identity.sshKeys.unicorn
      # pwny (~/.ssh/id_ed25519) — legacy; drop once unicorn is confirmed working
      identity.sshKeys.pwny
      # yoru's Secretive Secure Enclave key (public half in identity.nix)
      identity.sshKeys.yoruEcdsa
    ];
    passwordlessSudo = true;
  };

  network = rec {
    bridge = "br0";
    primaryInterface = "enp1s0";
    prefixLength = lanPrefixLength;
    # Reach the home LAN through kura without installing Tailscale on each device.
    tailscaleSubnetRoutes = [ "192.168.67.0/${toString lanPrefixLength}" ];
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
