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

    ../../modules/nixos/services/jellyfin.nix
    ../../modules/nixos/services/motd.nix
    ../../modules/nixos/containers/qbittorrent.nix
    ../../modules/nixos/containers/minecraft.nix
    ../../modules/nixos/containers/personal-webserver.nix
  ];
}
