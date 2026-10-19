# Portable package sets must not depend on personal host module evaluation.
{ nixpkgs, system }:
import nixpkgs {
  inherit system;
  overlays = [ (import ../overlays) ];
  config.allowUnfree = true;
  # Android SDK license acceptance is deliberately not enabled here.
}
