# aku — the arm64 NixOS guest: the Linux bench for yoru.
#
# Where the things darwin cannot do happen: the Linux-only offensive tools
# (netexec, hydra, bettercap, mitmproxy, bloodhound, real wordlists), the HTB
# VPN in an environment that expects it, and Linux kernel builds with a KVM
# boot loop if nested virtualisation is available.
#
# Installed from the NixOS aarch64 ISO and managed from inside with
#   nixos-rebuild switch --flake ~/nixfiles#aku
# See ~/tansu/notes/nixos-vm.md for the one-time bootstrap.
let
  adminUser = "ky";
  stateVersion = "26.05";
in
{
  # The one key already trusted on kura and navi, reused so there is a single
  # source of truth for "which key is ky".
  _module.args.vars = {
    host = {
      name = "aku";
      system = "aarch64-linux";
      inherit stateVersion;
    };

    user = {
      name = adminUser;
      uid = 1000;
      authorizedKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILrGOBlnxXx7U52BuS+M2swzKufwu1A76RyjfHK8w48A pwny"
      ];
    };
  };

  networking.hostName = "aku";

  # Declared, not discovered. UTM gives the guest a single virtio disk as /dev/vda;
  # the bootstrap partitions it exactly this way, so no hardware-configuration.nix
  # is needed and the layout survives a reinstall.
  fileSystems."/" = {
    device = "/dev/vda2";
    fsType = "ext4";
  };
  fileSystems."/boot" = {
    device = "/dev/vda1";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  # zramSwap comes from modules/vm; there is no swap partition.
  swapDevices = [ ];
}
