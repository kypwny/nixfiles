{ inputs, outputs }:
let
  commonIdentity = import ../identity.nix;
  mkIdentity =
    {
      hostname,
      username,
      system,
    }:
    commonIdentity
    // {
      inherit hostname username system;
      user = commonIdentity.user // {
        name = username;
      };
      homeDirectory =
        if nixpkgs.lib.hasSuffix "-darwin" system then "/Users/${username}" else "/home/${username}";
    };
  inherit (inputs)
    nixpkgs
    nix-darwin
    home-manager
    sops-nix
    mac-app-util
    catppuccin
    ;
in
{
  mkNixos =
    {
      hostname,
      username ? commonIdentity.user.name,
      system ? "x86_64-linux",
      # Which module set defines the host:
      #   "server" — kura: physical hardware, br0 bridges, sops secrets keyed
      #              to host SSH keys, containers.
      #   "vm"     — a guest (akuma): UEFI + virtio boot, no secrets, and none of
      #              the physical hosts' services.
      profile ? "server",
      extraModules ? [ ],
    }:
    let
      identity = mkIdentity { inherit hostname username system; };
      specialArgs = {
        inherit
          inputs
          outputs
          username
          hostname
          identity
          ;
        inherit (inputs) llm-agents;
      };
      homeFile =
        if builtins.pathExists (../home + "/${hostname}.nix") then
          ../home + "/${hostname}.nix"
        else
          ../home/default.nix;
    in
    assert builtins.elem profile [
      "server"
      "vm"
    ];
    nixpkgs.lib.nixosSystem {
      inherit system specialArgs;
      modules = [
        ../modules/shared
        ../modules/nixos/hostname-announcement.nix
        (if profile == "vm" then ../modules/vm else ../modules/nixos)
        (../hosts + "/${hostname}")
        sops-nix.nixosModules.sops
        home-manager.nixosModules.home-manager
        ({ config, vars, ... }: {
          assertions = [
            {
              assertion = vars.user.name == username && vars.host.name == hostname;
              message = "Host vars must agree with constructor identity.";
            }
            {
              assertion =
                config.networking.hostName == hostname
                && config.users.users.${username}.name == username
                && config.home-manager.users.${username}.home.username == username
                && config.home-manager.users.${username}.home.homeDirectory == config.users.users.${username}.home;
              message = "NixOS and Home Manager must agree with constructor identity.";
            }
          ];
        })
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            backupFileExtension = "hm-backup";
            extraSpecialArgs = specialArgs;
            sharedModules = [
              sops-nix.homeManagerModules.sops
              catppuccin.homeModules.catppuccin
            ];
            users.${username} = import homeFile;
          };
        }
      ]
      ++ extraModules;
    };

  mkDarwin =
    {
      hostname,
      username ? commonIdentity.user.name,
      system ? "aarch64-darwin",
      extraModules ? [ ],
    }:
    let
      identity = mkIdentity { inherit hostname username system; };
      specialArgs = {
        inherit
          inputs
          outputs
          username
          hostname
          identity
          ;
        inherit (inputs) llm-agents;
      };
      homeFile =
        if builtins.pathExists (../home + "/${hostname}.nix") then
          ../home + "/${hostname}.nix"
        else
          ../home/default.nix;
    in
    nix-darwin.lib.darwinSystem {
      inherit system specialArgs;
      modules = [
        ../modules/shared
        ../modules/darwin
        (../hosts + "/${hostname}")
        mac-app-util.darwinModules.default
        home-manager.darwinModules.home-manager
        ({ config, ... }: {
          assertions = [
            {
              assertion =
                config.networking.hostName == hostname
                && config.users.users.${username}.name == username
                && config.home-manager.users.${username}.home.username == username
                && config.home-manager.users.${username}.home.homeDirectory == config.users.users.${username}.home;
              message = "Darwin and Home Manager must agree with constructor identity.";
            }
          ];
        })
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            backupFileExtension = "hm-backup";
            extraSpecialArgs = specialArgs;
            sharedModules = [
              mac-app-util.homeManagerModules.default
              sops-nix.homeManagerModules.sops
              catppuccin.homeModules.catppuccin
            ];
            users.${username} = import homeFile;
          };
        }
      ]
      ++ extraModules;
    };
}
