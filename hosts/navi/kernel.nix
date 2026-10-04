# Use the release-pinned, prebuilt CachyOS BORE kernel for navi. Keep the
# upstream kernel config intact: no local Kconfig edits or kernel compilation.
{ inputs, pkgs, ... }:
{
  # Pinned overlay matches the Cachy release's CI nixpkgs so the kernel resolves
  # to its signed binary-cache output rather than rebuilding locally.
  nixpkgs.overlays = [ inputs.nix-cachyos-kernel.overlays.pinned ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Desktop/gaming BORE (not PREEMPT_RT); full upstream Cachy driver support.
  boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-bore;

  # Keep only host-specific runtime settings that still matter.
  boot.kernelParams = [
    "amdgpu.dpm=1"
    "amdgpu.ppfeaturemask=0xffffffff"
    "amd_pstate=active"
    "random.trust_cpu=off"
    "iommu=pt"
    "video=DP-1:2560x1440@144"
    "video=DP-2:2560x1440@144"
    "kvm_amd.avic=1"
    "kvm_amd.nested=0"
    "kvm.ignore_msrs=1"
    "kvm.report_ignored_msrs=0"
  ];

  # Keep existing VFIO/VM module setup; the stock kernel includes these modules.
  boot.initrd.kernelModules = [ "vfio-pci" ];
  boot.extraModprobeConfig = ''
    softdep snd_hda_intel pre: vfio-pci
    options vfio-pci ids=10de:2208,10de:1aef
    options snd-hda-core gpu_bind=0
    options snd-hda-codec-hdmi enable_acomp=n
    options kvm_amd avic=1 nested=0
    options kvm ignore_msrs=1 report_ignored_msrs=0
  '';

  # The old kernel reserved 16 GiB in 1-GiB hugepages and isolated half the
  # CPUs. Leave the stock scheduler/memory setup alone for a normal desktop.

  # Sysctl performance & security settings (from /etc/sysctl.d/performance.conf & security.conf)
  boot.kernel.sysctl = {
    "vm.swappiness" = 25;
    "vm.max_map_count" = 2147483642; # for gaming / Steam
    "kernel.kptr_restrict" = 2;
    "kernel.dmesg_restrict" = 1;
    "kernel.perf_event_paranoid" = 3;
    "kernel.unprivileged_bpf_disabled" = 2;
    "net.core.bpf_jit_harden" = 2;
    "kernel.kexec_load_disabled" = 1;
  };
}
