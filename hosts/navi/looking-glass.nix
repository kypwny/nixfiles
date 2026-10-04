# KVMFR host support for Looking Glass (IVSHMEM DMA path).
# 64 MiB is the documented size for 2560x1440 SDR; use 128 MiB for HDR at
# 1440p (or recalculate for a different maximum guest resolution).
{ config, pkgs, ... }:
{
  # Build this out-of-tree module against the exact selected CachyOS kernel.
  boot.extraModulePackages = [ config.boot.kernelPackages.kvmfr ];
  boot.initrd.kernelModules = [ "kvmfr" ];
  boot.kernelParams = [ "kvmfr.static_size_mb=64" ];

  # Grant the logged-in desktop user access to the module's character device.
  services.udev.packages = [
    (pkgs.writeTextFile {
      name = "kvmfr-udev-rules";
      destination = "/etc/udev/rules.d/70-kvmfr.rules";
      text = ''
        SUBSYSTEM=="kvmfr", GROUP="kvm", MODE="0660", TAG+="uaccess"
      '';
    })
  ];

  # Libvirt's per-VM device cgroup ACL must allow this character device.
  # verbatimConfig replaces its default text, so keep the namespace setting and
  # standard shared-device ACLs while adding KVMFR.
  virtualisation.libvirtd.qemu.verbatimConfig = ''
    namespaces = []
    cgroup_device_acl = [
      "/dev/null", "/dev/full", "/dev/zero",
      "/dev/random", "/dev/urandom",
      "/dev/ptmx", "/dev/kvm", "/dev/kqemu",
      "/dev/rtc", "/dev/hpet", "/dev/vfio/vfio",
      "/dev/kvmfr0"
    ]
  '';
}
