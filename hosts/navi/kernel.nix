# Custom kernel and bootloader configuration for navi
# Derived from audit 00-REPORT.md and cmdline.bin:
# - Self-built kernel parameters: AMD GPU overdrive, Zen 3 pstate, VFIO isolation, hugepages
# - Option to build custom kernel packages with structured extraConfig or manual config
{ lib, pkgs, ... }:
{
  # Boot loader: systemd-boot for UEFI
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Base kernel packages: latest upstream linux package set,
  # or customized with structured extraConfig mirroring navi's self-compiled options
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Custom kernel config deltas based on gentoo-7.2.0-psyche from audit
  boot.kernelPatches = [
    {
      name = "navi-kernel-tuning";
      patch = null;
      structuredExtraConfig = with lib.kernel; {
        # Performance & preemption
        PREEMPT_DYNAMIC = lib.mkForce yes;
        HZ_1000 = lib.mkForce yes;

        # Hardening gaps noted in audit §8
        SECURITY_LOCKDOWN_LSM = lib.mkForce yes;
        MODULE_SIG = lib.mkForce yes;
        MODULE_SIG_ALL = lib.mkForce yes;
        MODULE_SIG_SHA512 = lib.mkForce yes;

        # Hardware sensors & Wi-Fi
        SENSORS_NCT6775 = lib.mkForce module;
        IWLWIFI = lib.mkForce module;
        IWLMVM = lib.mkForce module;
        BT_INTEL_PCIE = lib.mkForce module;

        # VFIO passthrough for win11/gaming VM
        VFIO = lib.mkForce yes;
        VFIO_PCI = lib.mkForce module;
        VFIO_PCI_CORE = lib.mkForce module;
      };
    }
  ];

  # Kernel command-line arguments derived from running UKI /etc/kernel/cmdline
  boot.kernelParams = [
    # AMD GPU power management & overdrive
    "amdgpu.dpm=1"
    "amdgpu.ppfeaturemask=0xfff7ffff"

    # CPU & scheduler tuning
    "preempt=full"
    "amd_pstate=active"
    "cpufreq.default_governor=performance"
    "nowatchdog"
    "random.trust_cpu=off"
    "iommu=pt"

    # PCIe & NVMe power management (keep controllers responsive)
    "nvme_core.default_ps_max_latency_us=0"
    "pcie_aspm=off"
    "pcie_port_pm=off"

    # Displays
    "video=DP-1:2560x1440@144"
    "video=DP-2:2560x1440@144"

    # KVM & virtualization (GPU passthrough)
    "kvm_amd.avic=1"
    "kvm_amd.nested=0"
    "kvm.ignore_msrs=1"
    "kvm.report_ignored_msrs=0"

    # CPU core isolation & IRQ affinity for VM
    "irqaffinity=0-7,16-23"
    "isolcpus=managed_irq,8-15,24-31"

    # Hugepages for virtualization
    "default_hugepagesz=1G"
    "hugepagesz=1G"
    "hugepages=16"
  ];

  # Module options (GPU passthrough & audio)
  boot.extraModprobeConfig = ''
    softdep snd_hda_intel pre: vfio-pci
    options vfio-pci ids=10de:2208,10de:1aef
    options snd-hda-core gpu_bind=0
    options snd-hda-codec-hdmi enable_acomp=n
    options kvm_amd avic=1 nested=0
    options kvm ignore_msrs=1 report_ignored_msrs=0
  '';

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
