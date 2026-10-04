{ ... }:

let
  vars = import ./vars.nix;
in
{
  _module.args.vars = vars;

  # Upgrade guidance: when bumping nixpkgs across a systemd major version
  # (e.g. 26.05 -> 26.11), `nixos-rebuild switch` can fail with exit status 4
  # because `systemd-machined.socket` cannot restart while its service is
  # already active. Prefer `nixos-rebuild boot` + reboot for cross-version
  # upgrades; use `switch` only for same-version changes.
  imports = [
    ./hardware-configuration.nix
    ./wireguard.nix

    ../../modules/nixos/services/jellyfin.nix
    ../../modules/nixos/services/motd.nix
    ../../modules/nixos/containers/qbittorrent.nix
  ];

  # kura lives on DHCP behind a double-NAT router. Announce kura.local over
  # mDNS so LAN machines (macOS resolves .local natively) can reach it without
  # knowing the leased address.
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true; # UDP 5353
    publish = {
      enable = true;
      addresses = true;
    };
  };

  # Out-of-band access through the double NAT via the tailnet; also provides
  # kura as a MagicDNS name. Authenticate once after rebuild with:
  #   sudo tailscale up
  services.tailscale = {
    enable = true;
    openFirewall = true;
  };
}
