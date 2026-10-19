{ lib, identity, ... }:

let
  vars = import ./vars.nix { inherit identity; };
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

  # Out-of-band access and home-LAN subnet routing, without changing the BPI-R3.
  # Authenticate after activation and approve the advertised route in the tailnet.
  services.tailscale = {
    enable = true;
    openFirewall = true;
    useRoutingFeatures = "server";
    extraSetFlags = [
      "--advertise-routes=${lib.concatStringsSep "," vars.network.tailscaleSubnetRoutes}"
    ];
  };
}
