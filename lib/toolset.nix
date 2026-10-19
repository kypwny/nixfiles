# Compatibility view for existing host modules. The catalog lives in shells/.
# outputs remains accepted so external consumers need not migrate atomically.
{ pkgs, lib, ... }:
let
  catalog = import ../shells/tools.nix { inherit pkgs lib; };
in
catalog.categories
// {
  inherit (catalog) system elfHeaders offsecPython;
}
