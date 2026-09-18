# The VM profile — a declarative NixOS guest (UTM + Virtualization.framework).
#
# kura and navi use modules/nixos: physical hardware, br0 bridges, sops secrets
# keyed to host SSH keys, containers. None of that belongs in a guest:
# inheriting it would make activation fail (sops cannot decrypt without a
# matching age key) or start services that have no business running here.
#
# So the guest gets its own small, explicit module set, built from the same
# modules/shared base and the same lib/toolset.nix as yoru and navi. That is the
# whole point: one definition of the tools, three hosts.
#
# The tradeoff is a little duplication (the user/sudo/ssh block below mirrors
# modules/nixos/users.nix and security.nix). Kept separate on purpose — the
# physical hosts stay untouched and testable, and converging the two later is a
# refactor you can do with a working kura in front of you.
{
  pkgs,
  lib,
  outputs,
  vars,
  ...
}:

let
  toolset = import ../../lib/toolset.nix { inherit pkgs lib outputs; };
in
{
  # ---- boot: UEFI + virtio, as UTM's Virtualization.framework presents them ----
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.availableKernelModules = [
    "virtio_pci"
    "virtio_blk"
    "virtio_scsi"
    "virtio_net"
    "virtio_console"
    "xhci_pci"
    "usbhid"
    "hid_generic"
  ];
  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;

  # The guest gets 8 GB of yoru's 16; zram keeps a kernel build from swapping.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

  # ---- user ----
  users.users.${vars.user.name} = {
    isNormalUser = true;
    uid = vars.user.uid;
    shell = pkgs.zsh;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = vars.user.authorizedKeys;
  };
  programs.zsh.enable = true;

  security.sudo.extraRules = [
    {
      users = [ vars.user.name ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  # ---- reachable from yoru over UTM's NAT network ----
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      PubkeyAuthentication = true;
    };
  };
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
  };

  # ---- nix ----
  # Flakes are on via modules/shared. trusted-users lets yoru offload
  # aarch64-linux builds here later (nix.buildMachines on the Mac) instead of
  # failing to build them at all.
  nix.settings.trusted-users = [
    "root"
    vars.user.name
  ];

  # ---- the toolset ----
  # Same categorization as every other host. On Linux this set is *complete*:
  # netexec, hydra, bettercap, mitmproxy, bloodhound and the real wordlists are
  # all present, which is precisely what darwin cannot build.
  environment.systemPackages = lib.unique (
    lib.flatten [
      toolset.re
      toolset.dynamic
      toolset.ios
      toolset.kernel
      toolset.toolchain
      toolset.tracing
      toolset.offsec
    ]
  );

  system.stateVersion = vars.host.stateVersion;
}
