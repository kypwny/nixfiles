# Research shells

Tool declarations, platform omissions, shell construction, helpers and general
research guides live together here. Nix pins the tools; devices, SDK downloads,
guest machines and mutable artifacts are separate.

## Enter a shell

Run from `~/nixfiles`; these commands do not rebuild a host:

| Command | Use |
| --- | --- |
| `nix develop` | Default Nix maintenance tools: just, nh, nixfmt, nil, statix, deadnix, sops, age, ssh-to-age |
| `nix develop .#android-re` | Focused APK/ELF CLI tools: JADX, APKTool, dex2jar, APKID, adb, Frida, radare2/rizin, LLVM and inspection utilities |
| `nix develop .#android` | APK/DEX/resources, adb/fastboot, signing and device mirroring |
| `nix develop .#re` | General reverse engineering and static binary analysis |
| `nix develop .#dynamic` | Frida and hardware/process instrumentation |
| `nix develop .#ios` | IPSW, entitlements, USB device and supported bootchain tools |
| `nix develop .#kernel` | Kernel/board tools and source navigation |
| `nix develop .#tracing` | Tracing and capture tools available on the platform |
| `nix develop .#offsec` | Authorized security labs, GnuPG, VPN/client tools and wordlists |
| `nix develop .#host-tools` | GNU build utilities kept out of the system-wide macOS PATH |
| `nix develop .#toolchain` | Clang, LLVM, LLD and compiler support tools |
| `nix develop .#all` | Deduplicated union of the research categories; potentially large closure |

The `android-re` shell uses a hash-pinned upstream JADX distribution without the
optional Quark analytics integration. Broad Android/reversing shells retain the
nixpkgs package; GUI suites, device mirroring and hardware debugging remain in
the broader categories. Use `toolchain` when compiling. `kernel` alone is a
navigation/board shell, not a promise of a complete kernel-build environment.

## Inventory and limitations

Supported output systems: **aarch64-darwin**, **aarch64-linux**,
**x86_64-linux**. There is no Intel macOS support claim.

```sh
nix eval --json .#lib.toolInventory.aarch64-darwin
```

Change the suffix for another declared platform. Each category exposes included
tool names and omitted entries with `name` and `reason`; this manifest is the
source of truth, rather than a hand-maintained platform matrix.

- Objection is absent from standard shells on all systems: its Linux closure
  requires Android SDK license acceptance, and the pinned Darwin path is broken.
  If you have reviewed and explicitly accept Google's SDK terms, this optional
  Linux-side command uses an independent nixpkgs package set:

  ```sh
  NIXPKGS_ACCEPT_ANDROID_SDK_LICENSE=1 NIXPKGS_ALLOW_UNFREE=1 \
    nix shell nixpkgs#objection --impure
  ```

  This is **not tested here**, does not fix Darwin packaging, and is not a
  recommendation to add license acceptance to the flake.
- APKTool is omitted on `aarch64-linux` because its `aapt2` dependency is
  unsupported. The remaining Android tools can still be useful; inspect the
  inventory before copying APKTool commands into that guest.
- Linux-only tracing/security tools may be absent on Darwin. Use a
  [Linux runtime](docs/linux-runtime-on-mac.md), not `allowUnsupportedSystem`.
- Cutter is intentionally outside the standard catalog to avoid its heavy GUI
  closure. Optional tools from `nix shell nixpkgs#...` use that nixpkgs reference,
  not necessarily this repository's pin or overlays.
- The emulator and system images are not supplied by the Android shell. Unfree
  package permission is explicit and distinct from Android SDK license consent.
- A resolved derivation is not a completed native build, a successful launch or a
  working USB/session permission setup. No historical build claims are carried
  forward as current verification.

`all` and `offsec` export `SECLISTS` and `ROCKYOU` as packaged data paths; they are
not commands. System consumers use a narrower compatibility selection: GNU host
utilities and Nix compiler tooling must not shadow Apple's tools system-wide.
Akuma's baseline omits JADX's heavy analytics closure; use an Android shell on
demand rather than making every guest switch pay for it.

## Workspace and helpers

`RESEARCH_WORKSPACE` defaults to `$HOME/workspace`. Keep APKs, captures, IPSWs,
kernel source, build outputs, device logs, VPN profiles and credentials there or
in another private external workspace. Existing workspace directories are not renamed,
overwritten or migrated automatically.

Shell entry has no research side effects: no directory creation, downloads,
network connection, device changes or deployment. Helpers create directories
only when explicitly invoked. Inspect each helper's `--help` before use; package
and upstream subcommands also have version-sensitive flags.

Helpers live under `shells/scripts/`. In particular,
[`htb.sh`](scripts/htb.sh) is a lab helper,
[`kbuild.sh`](scripts/kbuild.sh) is an **experimental** build helper, and
[`kernel-deploy.sh`](scripts/kernel-deploy.sh) is **quarantined**: it does not
deploy a kernel. Do not use historical deployment scripts to change a host.

The build helper requires a pre-existing architecture-matching config and
separate external output. Symlink children in that output, including Kbuild's
generated `source` link, are refused; unrestricted incremental builds are not
supported. See the kernel guide for the experimental Darwin boundary.

## Guides

- [Android APK/ELF and API investigation](docs/android-re.md): static first;
  runtime and proxy trust are separate problems.
- [Linux runtime on a Mac](docs/linux-runtime-on-mac.md): choose guest, container,
  emulator or remote host based on the task.
- [iOS research](docs/ios-re.md): firmware/static inspection before device changes.
- [Experimental Linux kernel work](docs/kernel-work.md): build on Linux; isolated
  test kernels, no automated deployment or weakened host policy.
- [Experimental macOS kernel work](docs/macos-kernel-work.md): XNU/KDK constraints
  and why old security-reduction recipes are not defaults.
- [Authorized security labs](docs/authorized-labs.md): explicit VPN and target
  scope, no automatic scan on shell entry.

These guides are general workflows, not evidence of a tested target app,
enrolled machine, jailbroken device or working kernel. Personal host operations
are kept in [docs/hosts](../docs/hosts/README.md).

[Repository README](../README.md) · [Layout](../docs/layout.md)
