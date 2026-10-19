# Experimental Linux kernel work

**Build Linux kernels in Linux.** Use the Mac for editing, navigation, static
inspection and carefully scoped cross-compilation experiments. This guide is
not an automated deployment path and does not authorize changing a production
host's boot or tracing policy.

## Choose a build host and boot target

A matching Linux host or guest avoids the Darwin Kbuild host-tool boundary.
Cross-building on ARM64 Linux for x86_64 still requires the right target compiler,
configuration and boot hardware; a built file is not a successful boot. Keep
source, separate output directories, build logs and artifacts outside this repo
under `RESEARCH_WORKSPACE` (default `$HOME/workspace`). Pin the kernel source
revision and retain a known-good configuration.

Use `host-tools` and `toolchain` for build tooling, `kernel` for board/navigation
tools, and the platform inventory to check omissions. The `all` shell combines
these categories but may realize a large closure. Linux may still need extra
headers, libraries or source-version-specific dependencies; no shell is a
promise that an arbitrary kernel configuration builds.

For LLVM, upstream documents `LLVM=1` and `ARCH=<target>` for all-LLVM builds;
`CROSS_COMPILE` is not required in that case and is not a universal way to choose
a Clang target. Mixed GNU tools and a disabled integrated assembler have their
own requirements. Use the same `LLVM` selection at configure and build time.[4]

Illustrative Linux-side commands, after selecting a source tree, output directory
and appropriate configuration:

```sh
make O="$BUILD_DIR" LLVM=1 ARCH=arm64 defconfig
make O="$BUILD_DIR" LLVM=1 ARCH=arm64 olddefconfig
make O="$BUILD_DIR" LLVM=1 ARCH=arm64 -j"$JOBS"
```

`BUILD_DIR` and `JOBS` must be explicitly chosen. A stock defconfig is a starting
point for a disposable test, not a replacement for a physical host's hardware
configuration. A x86 target normally uses `ARCH=x86`, not the ELF architecture
string `x86_64`.

## Why the Mac helper remains experimental

[`kbuild.sh`](../scripts/kbuild.sh) is an experimental helper. Read its `--help`
before invoking it; do not infer a supported full build from the presence of
LLVM or isolated ELF headers.

The original `kernel-dev-navi.md` records an earlier Darwin build attempt that
failed in host tools: missing `elf.h`, a Mach-O/ELF host-linker mismatch, then
`objtool`'s Linux header requirements. Those are **historical notes**, not a new
reproduction or proof that every current kernel fails at the same point.

Remember the boundary:

- Target LLVM utilities inspect/build ELF; host tools run on Darwin and need
  Darwin-compatible headers/linking and dependency libraries.
- An isolated `elf.h` workaround does not supply a complete Linux host ABI.
  Do not prepend all glibc headers to Darwin host compiler includes.
- `pahole` is platform-constrained here. A configuration without BTF does not
  validate BTF-dependent tooling or BPF CO-RE workflows.
- Verify filesystem case sensitivity rather than assuming a source tree is safe
  on the default macOS volume.
- Shell-scoped GNU utilities/compiler tooling must not replace Apple's system
  toolchain for unrelated Xcode/device work.

## Test in isolation, not on the daily host

Use a disposable VM with snapshots, a known root filesystem/initramfs, a console
and a documented recovery route. Select QEMU architecture and acceleration to
match the build. `/dev/kvm` and permission to open it must be checked; nested
virtualization is not promised. A kernel-only `qemu -kernel ...` command without
its userspace/console plan is not a complete test environment.

Modules must match the target kernel's release, config and build interfaces.
Signing and lockdown determine whether loading is permitted; do not assume an
unsigned module is accepted merely because an old note says so. Test crashes,
module loads and fuzzing on an isolated guest. Fuzzing requires intentionally
chosen instrumentation (for example KCOV/KASAN), images, corpus and resource
limits, not just installing syzkaller.

Tracing also depends on the running kernel and capabilities. Use a matching
`perf`, inspect BPF/BTF availability and the current permissions, and retain
protective policy unless a separately approved isolated experiment needs a
change. The old sysctl recipes are not defaults. In particular,
`kexec_load_disabled` cannot simply be toggled back after it is locked for the
boot; do not treat it as a harmless session switch.

## Deployment is deliberately absent

[`kernel-deploy.sh`](../scripts/kernel-deploy.sh) is quarantined and **does not
deploy**. No helper should upload, invoke kexec, alter hardening, switch a NixOS
generation or reboot a host as an incidental research action.

For a separately approved permanent NixOS kernel change, use the host's
declarative kernel module and [maintenance workflow](../../docs/hosts/maintenance.md).
Resolve Kconfig, build its generated config, then build the full host toplevel
including initrd dependencies before activation. Keep a bootable prior generation
and verify actual boot/runtime state separately. Evaluation alone is insufficient.

The current [Navi declaration](../../docs/hosts/navi.md) uses a prebuilt
CachyOS BORE kernel for desktop/gaming. The host no longer installs the
kernel-development toolchain; use the opt-in research shells for kernel work.
Preserve legacy on-disk labels while using the current `navi` flake target.

No full kernel build, boot, module load, fuzzing campaign or deployment was
performed for this documentation change.

[Shells](../README.md) · [Linux runtime on a Mac](linux-runtime-on-mac.md)

## Sources

[4] https://docs.kernel.org/kbuild/llvm.html