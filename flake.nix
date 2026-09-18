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
    mac-app-util.inputs.nixpkgs.follows = "nixpkgs";
    llm-agents.url = "github:numtide/llm-agents.nix";
    nix-minecraft.url = "github:Infinidoge/nix-minecraft";
    catppuccin.url = "github:catppuccin/nix";
    catppuccin.inputs.nixpkgs.follows = "nixpkgs";

    # kypwny.net docroot, built by kura at switch time (see personal-webserver).
    # https, not ssh: kura's key is passphrase-protected, which would block an
    # unattended switch. Publish = push, `nix flake update kypwny-site`, switch.
    kypwny-site.url = "git+https://git.tilde.horse/ky/kypwny-net.git";
    kypwny-site.inputs.nixpkgs.follows = "nixpkgs";

    # gomuks Matrix client & backend
    gomuks.url = "git+https://git.tilde.horse/ky/gomuks.git?ref=pwny";
    gomuks.inputs.nixpkgs.follows = "nixpkgs";
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
        "aarch64-linux"
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
        # The arm64 UTM guest on yoru: its own module set, so it does not inherit
        # sops secrets, br0 bridges or containers meant for the physical hosts.
        aku = mylib.mkNixos {
          hostname = "aku";
          username = "ky";
          system = "aarch64-linux";
          profile = "vm";
        };
      };

      darwinConfigurations = {
        yoru = mylib.mkDarwin {
          hostname = "yoru";
          username = "ky";
          system = "aarch64-darwin";
        };
      };

      # Pinned upstream binaries live here so both the modules and the CLI can
      # reach them by one name (`nix build .#palera1n`).
      packages = forEachSystem (system: {
        palera1n = nixpkgs.legacyPackages.${system}.callPackage ./pkgs/palera1n.nix { };
      });

      formatter = forEachSystem (system: treefmtEval.${system}.config.build.wrapper);

      checks = forEachSystem (system: {
        formatting = treefmtEval.${system}.config.build.check self;
      });

      devShells = forEachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          lib = nixpkgs.lib;

          # Tools are categorized once in lib/toolset.nix (RedNix's packages.nix
          # + shells/ shape) and one shell is generated per category, named
          # plainly for what it holds. Entries the current host cannot build are
          # filtered out there, so one definition serves both systems:
          #   nix develop .#all       everything (this is the one to build kernels in)
          #   nix develop .#re        reversing only
          #   nix develop .#kernel    kernel + board tooling
          toolset = import ./lib/toolset.nix { inherit pkgs lib outputs; };

          # `system` in the toolset is a convenience list for systemPackages, not
          # a category worth its own shell; elfHeaders is an include dir, consumed
          # through KBUILD_ELF_INCLUDE below.
          categories = builtins.removeAttrs toolset [
            "system"
            "elfHeaders"
          ];
        in
        {
          # `default` stays the nix-tooling shell it has always been.
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
        // lib.mapAttrs' (
          name: packages:
          lib.nameValuePair name (
            pkgs.mkShell {
              name = name;
              packages = packages;
              shellHook = ''
                echo "${name}: ${toString (builtins.length packages)} tools (tansu)"
                echo "  lab root: ~/tansu"
              ''
              + lib.optionalString (name == "all" || name == "offsec") ''
                # Wordlists are data packages, so they never appear on PATH.
                #   ffuf -w $SECLISTS/Discovery/Web-Content/raft-medium-directories.txt
                #   hashcat ... $ROCKYOU
                export SECLISTS="${pkgs.seclists}/share/wordlists/seclists"
                export ROCKYOU="${pkgs.rockyou}/share/wordlists/rockyou.txt"
              ''
              + lib.optionalString (name == "all" || name == "toolchain") ''
                # Host tools in a Linux kernel build include <elf.h>, which macOS
                # does not ship. Referencing the isolated header (rather than
                # glibc's whole include dir) keeps it in the closure without
                # hijacking host compiles.
                export KBUILD_ELF_INCLUDE="${toolset.elfHeaders}/include"
              '';
            }
          )
        ) categories
      );
    };
}
