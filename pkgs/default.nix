# Only publish artifacts built for the requested architecture.
{ pkgs }:
{
  jadx = pkgs.callPackage ./jadx.nix { };
}
// pkgs.lib.optionalAttrs (pkgs.stdenv.hostPlatform.system == "aarch64-darwin") {
  palera1n = pkgs.callPackage ./palera1n.nix { };
}
