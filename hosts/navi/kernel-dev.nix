# navi — Linux kernel development, module/hardening work and fuzzing.
#
# Division of labour: yoru (the Mac) cross-compiles and reverses; navi runs the
# kernels, loads modules, drives VFIO and hosts fuzzing campaigns. See
# ~/tansu/scripts/kbuild.sh and ~/tansu/notes/kernel-dev-navi.md.
#
# The tool list comes from lib/toolset.nix — the same categorized definition that
# generates yoru's shells and systemPackages — so a tool added once shows up on
# both hosts where its platform allows.
#
# Nothing here changes navi's security posture: hosts/navi/kernel.nix holds the
# audit-driven sysctls (kexec_load_disabled=1, perf_event_paranoid=3,
# dmesg_restrict=1, kptr_restrict=2) and they are left alone. The notes record
# which of them block which workflow, and the temporary reverts needed to
# profile or kexec.
{
  pkgs,
  lib,
  outputs,
  ...
}:

let
  toolset = import ../../lib/toolset.nix { inherit pkgs lib outputs; };
in
{
  environment.systemPackages = lib.unique (
    lib.flatten [
      toolset.toolchain # llvm / lld / clang-tools / ccache
      toolset.kernel # dtc, ubootTools, pahole, qemu, ctags, cscope, bear
      toolset.tracing # bpftrace, sysdig, bcc, trace-cmd, strace, ltrace
      toolset.offsec # the Linux-only half of the offensive set
      (with pkgs; [
        # ---- Kbuild dependencies -----------------------------------------
        gcc
        gnumake
        bc
        flex
        bison
        perl
        python3
        rsync
        cpio
        kmod # insmod/rmmod/modinfo/depmod
        elfutils # libelf for objtool and BPF builds
        openssl
        pkg-config
        ncurses
        zlib

        # ---- debug ---------------------------------------------------------
        gdb # multiarch on Linux; there is no separate gdb-multiarch attr
        strace
        ltrace

        # ---- tracing, matched to the running kernel -------------------------
        linuxPackages_latest.perf # same set boot.kernelPackages pulls from

        # ---- fuzzing --------------------------------------------------------
        aflplusplus
        # nixpkgs' syzkaller snapshot is from 2024-01, which is old for current
        # kernels. Build it from source for real campaigns — see the notes.
        syzkaller

        # ---- bootchain ------------------------------------------------------
        # checkra1n from nixpkgs is the Linux build (meta.platforms is
        # linux-only, no darwin entry), so navi is the only host in this fleet
        # that can run it. Unfree: allowed by modules/shared/nix-settings.nix.
        checkra1n

        # ---- serial / device ------------------------------------------------
        socat
        minicom
        picocom
        usbutils
        pciutils
      ])
    ]
  );
}
