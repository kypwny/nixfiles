# Linux runtime on a Mac

macOS can inspect ELF, disassemble code and cross-compile selected targets. It
cannot provide the Linux kernel ABI by entering a Nix shell. Pick the runtime
based on what must execute, not the file extension alone.

## Choose the smallest useful environment

| Task | Environment |
| --- | --- |
| Read APK/ELF metadata, symbols, strings and disassembly | Mac `android-re` or `re` shell; no guest needed |
| Run an Android app, ART/JNI or Android/bionic-native code | Compatible Android emulator/device; [Android guide](android-re.md) |
| Run ARM64 Linux userland, Linux-only tools or a kernel build | ARM64 Linux VM, or a Linux container hosted by a Linux VM |
| Run an x86_64 Linux program | x86_64 Linux host/guest, or deliberate user-mode emulation with the required userspace |
| Load a Linux module, trace Linux syscalls/BPF or boot a test kernel | Linux guest/host with matching kernel, permissions and configuration |
| Work on physical drivers, VFIO or hardware-specific faults | Dedicated matching hardware, not an unrelated ARM guest |

A container on macOS uses a Linux VM underneath; it shares that guest kernel,
not the macOS kernel. A container is useful for build userspace isolation but
is not equivalent to a disposable boot target for custom kernels. User-mode
emulation cannot substitute for a Linux-kernel-specific exploit or driver test.

For an unknown ELF, inspect architecture, interpreter and dynamic dependencies
without running it on your daily host. Match architecture **and** userspace ABI:
glibc, musl and Android bionic are not interchangeable. Prefer readelf to `ldd`
for initial inspection of untrusted artifacts.

## ARM64 guest on Apple Silicon

Use UTM's virtualization path with an ARM64 Linux image when native guest
execution is the goal. An x86_64 image needs an emulation path and has different
performance/compatibility tradeoffs; it is not inherently useless if x86_64 is
what the task requires. Do not ignore architecture mismatch warnings.

Choose CPU/RAM/disk budgets for the current host, rather than copying a historic
16-GB-machine allocation. Leave memory for macOS, the browser and analysis GUIs.
Use a private guest disk and snapshots before risky runtime experiments. Limit
shared folders and credentials; do not expose your whole home directory to
untrusted code.

Shared/NAT networking is suitable for outbound package downloads and lab VPNs.
Bridging changes exposure and must be chosen deliberately. Discover the guest's
actual address in UTM/the guest instead of hardcoding a historical NAT gateway.
Guest-agent commands vary by UTM backend and installed agent; inspect their
help and do not assume `utmctl exec` works for every VM.

## The repository's guest: akuma

[Akuma's host guide](../../docs/hosts/akuma.md) contains the personal NixOS guest
bootstrap and SSH policy. Its current flake target is
`nixosConfigurations.akuma`, not `aku`; it uses the VM module profile rather than
the physical-host server profile. The old notes disagree about Kali versus
NixOS; use the current host declaration for this managed guest. A separate Kali
VM is a separate machine, not a drop-in flake target.

Inside a compatible Linux environment with this checkout:

```sh
cd ~/nixfiles
nix develop .#offsec
# Or choose re/android-re/kernel/toolchain as the task requires.
nix eval --json .#lib.toolInventory.aarch64-linux
```

Linux does not mean every package works on every architecture. In particular,
APKTool is omitted on ARM Linux, and Objection is omitted from standard shells
because of license-gated dependencies. Do not label the guest's tool set
"complete"; read the inventory and realize only the tools you need.

Keep research data under a private external workspace (`RESEARCH_WORKSPACE`
defaults to `$HOME/workspace`). Copy only the artifact subset the guest needs.
Do not transfer SSH private keys, VPN profiles or accounts as part of syncing
the repository.

## Kernels, tracing and builders

Check whether `/dev/kvm` exists **and** whether the chosen QEMU backend can open
it before selecting KVM acceleration. Nested virtualization depends on hardware,
host OS, backend and guest configuration; it is not promised by an ARM64 VM.
TCG is a slower fallback when appropriate, not an implicit acceptance of a
hardware-dependent result. Kernel testing also needs a root filesystem/initramfs
and a recoverable console; a bare kernel invocation is not a complete boot setup.

Build Linux kernels in Linux. A successful LLVM cross-compile of a translation
unit on the Mac does not validate all Kbuild host tools. See
[experimental kernel work](kernel-work.md).

A remote Nix builder is opt-in. Configure SSH identity, trust and actual builder
capabilities explicitly; do not advertise `kvm` or `nixos-test` without checking
them. Evaluating an `aarch64-linux` derivation on Darwin does not build it locally;
a matching guest/remote builder or suitable binary cache is a separate step.

## Authorized labs

Put a lab VPN in the environment running the lab tools when practical. Verify
route, DNS and interface inside that environment; Mac connectivity alone does
not prove guest reachability. Keep VPN profiles private and disconnect when
finished. See [authorized labs](authorized-labs.md) before invoking helpers.

## Provenance and verification boundary

Curated from `nixos-vm.md`, `utm-vms.md`, `kernel-dev-navi.md` and the original
workspace README. Historical claims about installed UTM releases, guest agents,
RAM, addresses, nested KVM and successful shell builds are not current evidence.
No guest was provisioned, booted or enrolled as part of this guide update.

[Shells](../README.md) · [macOS kernel work](macos-kernel-work.md)
