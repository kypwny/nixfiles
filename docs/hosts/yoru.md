# yoru

`darwinConfigurations.yoru` is the `aarch64-darwin` Mac workstation. Its system
module is `hosts/yoru/default.nix`; shared macOS integration lives under
`modules/darwin/`, and Home Manager provides the user environment.

## Operations

- [Maintenance](maintenance.md): native builds and explicit darwin-rebuild switch.
- [Networking and Tailscale](networking.md): native Bonjour and the Nix-managed
  launchd Tailscale daemon/CLI; enrollment is a separate operator action.
- [Prism Launcher Java](desktop-java.md): Home Manager's macOS JDK bundle link and
  launcher auto-detection after restart.
- [Linux runtime](../../shells/docs/linux-runtime-on-mac.md): use a compatible
  guest/remote host for Linux-only execution and builds.
- [macOS kernel research](../../shells/docs/macos-kernel-work.md): experimental,
  no automatic installation or security reduction.

Ghidra and ImHex remain system-installed. ImHex uses the nixpkgs package because
its Homebrew cask failed to install. Other research tools are on-demand: enter a
focused `nix develop .#<shell>` instead of installing the full reversing,
dynamic, iOS and kernel toolsets system-wide.
Yoru uses Ghostty; Kitty's terminfo is kept only on the Linux hosts that use Kitty.
QEMU is available via `nix develop .#kernel`; UTM is the usual VM runtime on Yoru.
ImHex is installed from nixpkgs on Yoru and remains available in the research
shell on supported platforms. SDKs, Xcode and KDKs remain separate prerequisites;
no current installation or successful native shell-build claim is made here.
Yoru takes nixpkgs packages as-is so they come from cache.nixos.org. Overrides
that change a library's hash (like the Linux-only libtiff trim in `overlays/`)
would force everything built on top of it to compile locally.
Linecast 2.9.2 is installed from the pinned nixpkgs unstable package through
Home Manager (`home/yoru.nix`), not Homebrew.

## Secretive (Secure Enclave SSH)

Secretive (`home.packages`, `home/yoru.nix`) holds the `yoru` Secure Enclave key;
the private half never leaves the enclave. The public half is declared as
`identity.sshKeys.yoruEcdsa` and wired to SSH via Secretive's agent socket
(`programs.ssh.settings."*".identityAgent) and to commit signing via the
`ssh-keygen-secretive` wrapper (`programs.git`).

- Agent socket: `~/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh`
- After creating or rotating the key in Secretive.app, update `identity.nix`
  (and `tests/host-identity.nix`) with the new public key, then
  `sudo darwin-rebuild switch --flake .#yoru`.
- Non-Nix follow-ups for a new key: `gh ssh-key add ~/.ssh/yoru.pub`, add it to
  `tilde.horse` / `git.tilde.horse` authorized keys, and enable SecretAgent
  launch on login in Secretive settings.

[Host index](README.md) · [Repository README](../../README.md)
