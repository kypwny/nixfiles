{
  description = "Multi-host NixOS and nix-darwin configuration";

  nixConfig = {
    extra-substituters = [ "https://cache.numtide.com" ];
    extra-trusted-public-keys = [
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
    mac-app-util.url = "github:hraban/mac-app-util";
    llm-agents.url = "github:numtide/llm-agents.nix";
    nix-minecraft.url = "github:Infinidoge/nix-minecraft";
    catppuccin.url = "github:catppuccin/nix";
    catppuccin.inputs.nixpkgs.follows = "nixpkgs";

    # kypwny.net docroot, built by kura at switch time (see personal-webserver).
    # https, not ssh: kura's key is passphrase-protected, which would block an
    # unattended switch. Publish = push, `nix flake update kypwny-site`, switch.
    kypwny-site.url = "git+https://git.tilde.horse/ky/kypwny-net.git";
    kypwny-site.inputs.nixpkgs.follows = "nixpkgs";
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
      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];
      forEachSystem = nixpkgs.lib.genAttrs systems;
      treefmtEval = forEachSystem (
        system: treefmt-nix.lib.evalModule nixpkgs.legacyPackages.${system} ./treefmt.nix
      );
    in
    {
      lib = mylib;

      nixosConfigurations = {
        kura = mylib.mkNixos {
          hostname = "kura";
          username = "ky";
          system = "x86_64-linux";
        };
        navi = mylib.mkNixos {
          hostname = "navi";
          username = "ky";
          system = "x86_64-linux";
        };
      };

      darwinConfigurations = {
        yoru = mylib.mkDarwin {
          hostname = "yoru";
          username = "ky";
          system = "aarch64-darwin";
        };
      };

      formatter = forEachSystem (system: treefmtEval.${system}.config.build.wrapper);

      checks = forEachSystem (system: {
        formatting = treefmtEval.${system}.config.build.check self;
      });

      devShells = forEachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
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
      );
    };
}
