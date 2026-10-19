# Portable task shells; importing/entering a shell never operates on a target.
{
  pkgs,
  catalog ? import ./tools.nix { inherit pkgs; },
}:
let
  inherit (pkgs) lib;
  mkTaskShell =
    name: packages:
    pkgs.mkShell {
      inherit name packages;
      shellHook = ''
        export RESEARCH_WORKSPACE="''${RESEARCH_WORKSPACE:-$HOME/workspace}"
        printf '%s\n' '${name}: ${toString (builtins.length packages)} tools' "  workspace: $RESEARCH_WORKSPACE"
      ''
      + lib.optionalString (name == "all" || name == "offsec") ''
        export SECLISTS="${pkgs.seclists}/share/wordlists/seclists"
        export ROCKYOU="${pkgs.rockyou}/share/wordlists/rockyou.txt"
      ''
      + lib.optionalString (name == "offsec" || name == "all") ''
        export PATH="${catalog.offsecPython}/bin:$PATH"
      ''
      + lib.optionalString (name == "all" || name == "toolchain") ''
        export KBUILD_ELF_INCLUDE="${catalog.elfHeaders}/include"
      '';
    };
in
{
  # Preserve the repository-maintenance default and all existing public task names.
  default = pkgs.mkShell {
    packages = with pkgs; [
      nixfmt
      nil
      statix
      deadnix
      nh
      just
      sops
      age
      ssh-to-age
    ];
  };
}
// lib.mapAttrs mkTaskShell catalog.categories
