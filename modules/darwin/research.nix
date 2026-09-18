# yoru — iOS / macOS / Linux-kernel research stack.
#
# Lab root: ~/tansu        Reproducible shells: nix develop .#all (or .#re, .#kernel, …)
#
# The tool list itself lives in lib/toolset.nix, which categorizes it once and
# derives the devShells, this module, and navi's kernel-side set from the same
# definition. That is the one idea worth taking from redcode-labs/RedNix; the
# other is to filter every category through lib.meta.availableOn so a mixed
# darwin/linux fleet does not break.
#
# What lands in systemPackages is the `system` view of that toolset: the
# reversing, dynamic, iOS and kernel-board tools. Two categories are excluded on
# purpose:
#   * host-tools — GNU sed/coreutils must not shadow the BSD userland
#     system-wide; they belong inside the build shell only.
#   * toolchain — nix's clang/ld.lld would shadow Apple's clang on PATH and
#     break Xcode and every iOS/macOS build.
# Both remain available via `nix develop .#all`.
#
# Not here, and why:
#   * checkra1n  — nixpkgs ships the Linux build (meta.platforms has no darwin
#                  entry), so it can never execute here. Declared on navi.
#   * pongoOS    — no nixpkgs attribute; build from source with Xcode
#                  (see ~/tansu/notes/ios-re.md).
#   * dtrace     — ships with macOS at /usr/bin/dtrace; no darwin build in nixpkgs.
#   * usbmuxd    — macOS provides its own; the nixpkgs one is a Linux daemon.
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
  environment.systemPackages = toolset.system;
}
