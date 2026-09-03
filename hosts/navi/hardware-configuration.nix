# Staged hardware-configuration for navi from audit facts
# Storage layout:
#   /dev/sda1 -> ESP (vfat) UUID=1923-AD36, PARTUUID=e7b2ac59-ea5f-b147-84b9-0951f7cebe26 -> /boot
#   /dev/sda2 -> crypto_LUKS PARTUUID=93399d55-76ef-8f41-aef6-0b98507ebec4, UUID=fcdbbfd0-d28c-4d4a-a34f-1fcd23a0068a
#     LVM VG: secure
#     LV: /dev/secure/root (UUID=38fa0987-7fd6-4074-aca7-68a36d54a080) -> / (xfs)
#     LV: /dev/secure/swap -> swap
#   /dev/nvme0n1p1 -> LABEL=extrastorage (xfs) -> /mnt/extrastorage
{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:
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

  # LUKS on LVM configuration
  boot.initrd.luks.devices."cryptroot" = {
    device = "/dev/disk/by-uuid/fcdbbfd0-d28c-4d4a-a34f-1fcd23a0068a";
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

  # Filesystems matching navi's existing partitioning
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/38fa0987-7fd6-4074-aca7-68a36d54a080";
    fsType = "xfs";
    options = [
      "defaults"
      "noatime"
      "discard"
    ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/1923-AD36";
    fsType = "vfat";
    options = [
      "umask=0077"
      "defaults"
    ];
  };

  fileSystems."/mnt/extrastorage" = {
    device = "/dev/disk/by-label/extrastorage";
    fsType = "xfs";
    options = [
      "defaults"
      "nofail"
      "noatime"
    ];
  };

  swapDevices = [
    { device = "/dev/secure/swap"; }
  ];

  # CPU microcode for AMD Ryzen (Zen 3 / Family 19h)
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # High-resolution console
  hardware.enableAllFirmware = true;
}
