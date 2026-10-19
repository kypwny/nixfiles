{
  description = "Multi-host NixOS and nix-darwin configuration";

  nixConfig = {
    extra-substituters = [
      "https://cache.numtide.com"
      "https://attic.xuyh0120.win/lantian"
    ];
    extra-trusted-public-keys = [
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    impermanence.url = "github:nix-community/impermanence";
    impermanence.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
    mac-app-util.url = "github:hraban/mac-app-util";
    mac-app-util.inputs.nixpkgs.follows = "nixpkgs";
    llm-agents.url = "github:numtide/llm-agents.nix";
    catppuccin.url = "github:catppuccin/nix";
    catppuccin.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      treefmt-nix,
      ...
    }@inputs:
    let
      outputs = self;
      mylib = import ./lib { inherit inputs outputs; };
      inventory = import ./hosts;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      forEachSystem = nixpkgs.lib.genAttrs systems;
      pkgsFor = forEachSystem (system: import ./lib/mk-pkgs.nix { inherit nixpkgs system; });
      catalogs = forEachSystem (system: import ./shells/tools.nix { pkgs = pkgsFor.${system}; });
      shells = forEachSystem (
        system:
        import ./shells {
          pkgs = pkgsFor.${system};
          catalog = catalogs.${system};
        }
      );
      treefmtEval = forEachSystem (
        system: treefmt-nix.lib.evalModule nixpkgs.legacyPackages.${system} ./treefmt.nix
      );
    in
    {
      lib = mylib // {
        inherit systems inventory;
        toolInventory = forEachSystem (system: catalogs.${system}.manifest);
      };

      nixosConfigurations = nixpkgs.lib.mapAttrs (_: mylib.mkNixos) inventory.nixos;
      darwinConfigurations = nixpkgs.lib.mapAttrs (_: mylib.mkDarwin) inventory.darwin;

      packages = forEachSystem (system: import ./pkgs { pkgs = pkgsFor.${system}; });
      overlays.default = import ./overlays;
      formatter = forEachSystem (system: treefmtEval.${system}.config.build.wrapper);
      devShells = shells;

      checks = forEachSystem (
        system:
        let
          pkgs = pkgsFor.${system};
          shellContract = import ./tests/shells.nix {
            inherit pkgs;
            catalog = catalogs.${system};
            shells = shells.${system};
          };
        in
        {
          formatting = treefmtEval.${system}.config.build.check self;
          shell-evaluation = builtins.deepSeq shellContract (
            pkgs.runCommand "shell-evaluation" { } "touch $out"
          );
          regression =
            pkgs.runCommand "nixfiles-regression"
              {
                nativeBuildInputs = with pkgs; [
                  python3
                  bash
                  coreutils
                  gnugrep
                  gnused
                ];
              }
              ''
                export HOME="$TMPDIR/home"
                export PYTHONDONTWRITEBYTECODE=1
                mkdir -p "$HOME"
                cd ${self}
                python3 -m unittest discover -s tests -p 'test_*.py' -v
                for script in shells/scripts/*.sh; do
                  bash -n "$script"
                done
                touch "$out"
              '';
        }
      );
    };
}
