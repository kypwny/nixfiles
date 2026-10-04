# Staged hardware-configuration for navi: btrfs-on-LUKS boot disk + xfs data NVMe.
#
# Devices are referenced by LABEL, not UUID, so this config is valid the moment
# the installer creates the filesystems with matching labels — no post-install
# edits. When laying out the disk (see impermanence.nix for the rollback flow):
#
#   /dev/sda (Samsung 860 EVO 500GB — wipe & repartition)
#     sda1  1 GiB ESP, mkfs.vfat -n BOOT
#     sda2  8 GiB swap, mkswap -L SWAP
#     sda3  rest, cryptsetup luksFormat --label navi-crypt
#           cryptsetup open navi-crypt enc && mkfs.btrfs -L NIXOS /dev/mapper/enc
#           subvolumes: root (snapshot to root-blank at install!), nix, persist, log, home
#
#   /dev/nvme0n1p1 (GIGABYTE 1.8T — untouched, stays xfs) LABEL=extrastorage
{
  config,
  lib,
  modulesPath,
  ...
}:
let
  btrfsSubvolOptions = [
    "compress=zstd"
    "noatime"
  ];
in
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # Initrd storage & crypto modules
  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ahci"
    "nvme"
    "usbhid"
    "usb_storage"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [
    "dm_snapshot"
    "dm_crypt"
  ];

  # LUKS2 on the boot disk (label set at luksFormat time)
  boot.initrd.luks.devices."enc" = {
    device = "/dev/disk/by-label/navi-crypt";
    allowDiscards = true;
    preLVM = true;
  };

  # Host hardware modules
  boot.kernelModules = [
    "kvm-amd"
    "amdgpu"
    "iwlwifi"
    "nct6775"
  ];

  # Btrfs subvolumes on the LUKS container. Root is rolled back to root-blank
  # on every boot by the initrd rollback service in impermanence.nix, so only
  # persist/log carry state across reboots (neededForBoot).

  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS";
    fsType = "btrfs";
    options = [ "subvol=root" ] ++ btrfsSubvolOptions;
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-label/NIXOS";
    fsType = "btrfs";
    options = [ "subvol=nix" ] ++ btrfsSubvolOptions;
  };

  fileSystems."/persist" = {
    device = "/dev/disk/by-label/NIXOS";
    fsType = "btrfs";
    options = [ "subvol=persist" ] ++ btrfsSubvolOptions;
    neededForBoot = true;
  };

  fileSystems."/var/log" = {
    device = "/dev/disk/by-label/NIXOS";
    fsType = "btrfs";
    options = [ "subvol=log" ] ++ btrfsSubvolOptions;
    neededForBoot = true;
  };

  # /home stays a persistent btrfs subvolume (no home impermanence)
  fileSystems."/home" = {
    device = "/dev/disk/by-label/NIXOS";
    fsType = "btrfs";
    options = [ "subvol=home" ] ++ btrfsSubvolOptions;
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/BOOT";
    fsType = "vfat";
    options = [
      "umask=0077"
      "defaults"
    ];
  };

  # Data drive: xfs on NVMe, carried over from the Gentoo layout untouched
  fileSystems."/mnt/extrastorage" = {
    device = "/dev/disk/by-label/extrastorage";
    fsType = "xfs";
    options = [
      "defaults"
      "nofail"
      "noatime"
    ];
  };

  # Encrypted-at-boot swap: fresh random key each boot (no hibernation)
  swapDevices = [
    {
      device = "/dev/disk/by-partuuid/2aa3d452-6bfe-4701-b5ca-73f4751e3b1c";
      randomEncryption.enable = true;
    }
  ];

  # CPU microcode for AMD Ryzen (Zen 3 / Family 19h)
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # High-resolution console
  hardware.enableAllFirmware = true;
}
