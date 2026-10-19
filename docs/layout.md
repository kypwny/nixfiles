# Repository layout

The flake has two entry paths: disposable research shells and personal host
configurations. They reuse package fixes, but entering a shell does not construct
or activate a host.

## Entry points and ownership

| Path | Responsibility |
| --- | --- |
| `flake.nix` | Flake outputs, supported systems and wiring |
| `shells/default.nix` | Default Nix-tooling shell, categorized shells and composed `android-re` shell |
| `shells/tools.nix` | Explicit tool categories, platform exclusions and omission reasons |
| `shells/scripts/` | Explicitly invoked workspace/device/lab helpers; no shell-entry actions |
| `shells/docs/` | Curated, general research guides |
| `overlays/default.nix` | Pure package overlays; no NixOS/nix-darwin module options |
| `hosts/default.nix` | Explicit host inventory: hostname, platform and profile |
| `identity.nix` | Shared identity; host-specific key membership stays host-local |
| `lib/default.nix` | Host constructors and exported library values |
| `lib/toolset.nix` | Compatibility shim for existing system consumers of the research catalog |
| `hosts/<host>/` | Machine-specific declarations, hardware and host vars |
| `modules/shared/` | Fleet-wide module policy and overlay attachment |
| `modules/nixos/` | Physical-host/server profile and shared NixOS behavior |
| `modules/darwin/` | macOS system integration, Homebrew and research-package consumers |
| `modules/vm/` | Guest profile; no physical-host bridges, containers or host-key-based sops inheritance |
| `home/` | Home Manager environments, native application modules and dotfiles |
| `home/scripts/` | Desktop/migration helpers and existing regression tests |
| `pkgs/` | Custom pinned derivations |
| `theme/` | Shared base16 classic-dark palette and retheming helpers |
| `docs/hosts/` | Personal host operations moved out of the tools-first README |

There is one `shells/` layer; mutable research data stays outside the repository.
`RESEARCH_WORKSPACE` defaults to `$HOME/workspace` and selects the workspace root
without changing the catalog; merely entering a shell creates nothing.

## Data flows

```text
flake.nix ── shells/default.nix ── shells/tools.nix ── devShells
          └─ hosts/default.nix + identity.nix ── lib constructors
                                                └─ hosts + modules + home

overlays/default.nix ── shell package sets
                     └─ shared module adapter ── system package sets
shells/tools.nix ── lib/toolset.nix compatibility shim ── existing host consumers
```

Keep package fixes independent of system options so devShells can reuse overlays
without importing a host. The pure shell package set explicitly permits unfree
tools but does not accept Google's Android SDK license. License-gated optional
tools need a separate, deliberate invocation.

The advertised shell systems are `aarch64-darwin`, `aarch64-linux` and
`x86_64-linux`; Intel macOS is not an output. Inventory is available with:

```sh
nix eval --json .#lib.toolInventory.aarch64-darwin
nix eval --json .#lib.toolInventory.aarch64-linux
nix eval --json .#lib.toolInventory.x86_64-linux
```

Each category reports included tool names and omitted entries with `name` and
`reason`. Metadata filtering alone cannot prove a closure builds: dependencies
can have stricter platform constraints than their parent package.

## Host-specific values

Physical-host vars live in `hosts/<host>/vars.nix`; a guest can declare its vars
inside its own host module. Shared identity belongs in `identity.nix`, not copied
between constructors and modules. Preserve each host's authorized-key membership,
UID where specified and `stateVersion`. State version is a compatibility setting,
not the installed NixOS release.

Keep service-local values with their consumers. Do not turn identity into a
global bucket of network addresses, credentials or application settings.
Behavior shared between machines belongs in conditional shared modules, not
near-identical host forks.

## Validation boundary

Run from the repository root. [Host maintenance](hosts/maintenance.md) contains
explicit evaluation and activation commands; [shells](../shells/README.md)
contains shell selection and support caveats.

1. Inspect the complete dirty state and preserve unrelated changes.
2. Format and evaluate affected outputs, including sibling hosts sharing modules.
3. Build on a matching platform or a deliberately configured builder.
4. Activate only when requested; confirm runtime state separately.

`nix flake check --no-build --all-systems` resolves checks without building them.
A formatting check alone does not run script tests; the regression check does.
New untracked
Nix files are invisible to Git-backed flake sources until included in that source;
choose source/staging policy deliberately rather than silently committing them.

[Repository README](../README.md) · [Host index](hosts/README.md)
