# nixfiles

Nix development shells for reverse engineering, mobile research and security
labs, alongside personal NixOS and nix-darwin configurations. Use the tools
without adopting the host configurations or rebuilding your system.

## Quick start

Requires Nix with the `nix-command` and `flakes` experimental features enabled.
Run from your checkout:

```sh
cd ~/nixfiles
nix develop .#android-re
```

The focused Android RE shell includes JADX, APKTool, dex2jar, APKID, adb, Frida,
radare2/rizin, LLVM and inspection utilities. It uses a hash-pinned upstream JADX
distribution without the optional Quark analytics stack. APKTool is omitted on
ARM Linux; check the platform inventory before following tool-specific examples.

For general binary analysis or security labs:

```sh
nix develop .#re
nix develop .#offsec
```

The [shell guide](shells/README.md) covers every shell, package omissions and
helpers. Broader shells provide GUI suites, device mirroring, instrumentation,
tracing, compiler tools and kernel navigation. The `all` shell combines the
research categories and can have a large dependency closure; start with a
focused shell instead.
For example, QEMU is available in `.#kernel` but is not installed in Yoru's
default system package set (UTM is the usual VM runtime there).
ImHex uses nixpkgs on Darwin and Linux; it remains available in the `.#re` shell.
Yoru keeps research suites out of its always-installed package set; use these
focused shells when you need them; Ghidra and ImHex remain installed.
Yoru uses plain nixpkgs packages with no overrides so its closure comes from
cache.nixos.org; Linux-only build trims in `overlays/` do not apply to it.

**Working with new Nix files:** Git-backed flake references only include files
known to Git. Before using normal shell or host commands, add each new source
file to Git. If its contents should remain unstaged, record intent-to-add for
that new file instead:

```sh
# Replace this placeholder with the specific new source file.
git add --intent-to-add -- path/to/new-file.nix
```

Intent-to-add makes a new file visible to Nix without staging its contents; it
does not commit anything. Do not apply it indiscriminately to existing files or
the whole checkout when preserving a partially staged working tree.

For verification without changing the index, use an explicit path reference:

```sh
nix develop "path:$PWD#android-re"
```

Keep private artifacts outside the checkout: a `path:` source snapshot is not
limited to tracked files.

## Platform support

Declared shell platforms:

- Apple Silicon macOS (`aarch64-darwin`).
- ARM64 Linux (`aarch64-linux`).
- x86-64 Linux (`x86_64-linux`).

Intel macOS is not an advertised output. Categories are filtered for the selected
platform; available tools and explicit omission reasons can be inspected with:

```sh
nix eval --json .#lib.toolInventory.aarch64-darwin
```

Replace the platform suffix for Linux. Evaluation establishes that a derivation
can be constructed, not that every tool builds, launches or works with a device.
Linux binaries still need an appropriate Linux runtime to execute on a Mac;
static ELF inspection does not require running them.

Emulators, SDK system images, Xcode, KDKs, devices and guests are separate
prerequisites. Android SDK licenses are **not accepted automatically**. Objection
is excluded from the standard shells; the shell guide explains the separate
license opt-in and platform limitations.

## Workspace and research guides

Reusable tooling belongs in this repository; mutable research data does not.
The shell workspace defaults to:

```sh
RESEARCH_WORKSPACE="$HOME/workspace"
```

Select a different private workspace when entering a shell:

```sh
RESEARCH_WORKSPACE="$HOME/research" nix develop .#android-re
```

Keep APKs, firmware, captures, credentials, VPN profiles, kernel sources and build
outputs outside the checkout. Reusable scripts and guides live under `shells/`;
existing workspace directories are not renamed or migrated automatically.

Entering a shell does not create directories, download artifacts, scan targets,
connect to devices or deploy anything. Helpers run only when explicitly invoked;
inspect their `--help` first. Kernel builds are experimental and the deployment
helper deliberately refuses deployment.

- [Android APK, ELF and API investigation](shells/docs/android-re.md)
- [Linux runtime on a Mac](shells/docs/linux-runtime-on-mac.md)
- [iOS firmware and device research](shells/docs/ios-re.md)
- [Authorized security labs](shells/docs/authorized-labs.md)
- [Experimental Linux kernel work](shells/docs/kernel-work.md)
- [Experimental macOS kernel work](shells/docs/macos-kernel-work.md)

## Repository layout

```text
shells/
  default.nix       Shell construction
  tools.nix         Shared tool catalog and platform exclusions
  scripts/          Explicitly invoked research helpers
  docs/             General research guides
overlays/           Package fixes shared by shells and hosts
pkgs/               Custom pinned packages
identity.nix        Shared public user, Git and SSH-key definitions
hosts/default.nix   Host inventory and platform/profile selection
hosts/<host>/       Machine-specific configuration and values
modules/            Shared, NixOS, Darwin and VM system policy
home/               Home Manager environments and dotfiles
lib/                Constructors and compatibility adapters
tests/              Shell contracts, host assertions and helper tests
docs/hosts/         Personal host operations
```

The [layout guide](docs/layout.md) explains the data flow and ownership boundaries.
Host consumers reuse the catalog through a compatibility adapter; shell users do
not need to copy personal system configuration. Host-specific key membership,
credentials and state versions remain host-local.

## Personal hosts

| Host | Platform | Role | Documentation |
| --- | --- | --- | --- |
| yoru | aarch64-darwin | Mac workstation | [yoru](docs/hosts/yoru.md) |
| kura | x86_64-linux | NixOS server and internal services | [kura](docs/hosts/kura.md) |
| akuma | aarch64-linux | UTM NixOS guest and Linux toolbench | [akuma](docs/hosts/akuma.md) |

Yoru installs Linecast from nixpkgs through Home Manager. Its GnuPG settings and
`ky@tilde.horse` default key are declared in Home Manager with the HKPS clearnet
server `keys.openpgp.org`; the private keyring stays mutable and local in
`~/.gnupg`, and Git signing remains on its SSH key.

Akuma was formerly `aku`. Preserve intentional legacy disk labels
and backup paths. Java, networking and Tailscale instructions live in the
[host documentation](docs/hosts/README.md).

## Maintenance and verification

The default shell contains Nix maintenance tools, not the research tool suite:

```sh
nix develop
just --list
just check
just test
just lint
just scan
nix fmt
```

- `just check` evaluates all advertised platforms and builds native flake checks,
  including formatting, shell contracts, host identity and regression tests.
- `just test` runs desktop and helper tests directly. Desktop configuration
  assertions require Nix; external research operations are mocked.
- `just build` builds the native host configuration without activation.
  `just switch` activates it; review the host instructions first.
- `just update` changes the lockfile. It is not a routine verification step.

Cross-platform evaluation is not cross-platform runtime testing. Syncing,
evaluating, building, activating and enrolling a host are separate operations;
none is implied by entering a development shell. See
[host maintenance](docs/hosts/maintenance.md) for explicit targets and commands.

Preserve unrelated working-tree changes. Update the relevant documentation when
changing behavior, and never commit private research artifacts or credentials.
