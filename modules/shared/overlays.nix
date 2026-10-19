# Module adapter: the same pure overlay is also used by devShells.
{
  nixpkgs.overlays = [ (import ../../overlays) ];
}
