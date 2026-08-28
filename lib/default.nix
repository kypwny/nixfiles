{ inputs, outputs }:
let
  inherit (inputs)
    nixpkgs
    nix-darwin
    home-manager
    sops-nix
    mac-app-util
    ;
in
{
  mkNixos =
    {
      hostname,
      username ? "ky",
      system ? "x86_64-linux",
      extraModules ? [ ],
    }:
    let
      specialArgs = {
        inherit
          inputs
          outputs
          username
          hostname
          ;
        inherit (inputs) llm-agents nix-minecraft;
      };
      homeFile =
        if builtins.pathExists (../home + "/${hostname}.nix") then
          ../home + "/${hostname}.nix"
        else
          ../home/default.nix;
    in
    nixpkgs.lib.nixosSystem {
      inherit system specialArgs;
      modules = [
        ../modules/shared
        ../modules/nixos
        (../hosts + "/${hostname}")
        sops-nix.nixosModules.sops
        home-manager.nixosModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            backupFileExtension = "hm-backup";
            extraSpecialArgs = specialArgs;
            users.${username} = import homeFile;
          };
        }
      ]
      ++ extraModules;
    };

  mkDarwin =
    {
      hostname,
      username ? "ky",
      system ? "aarch64-darwin",
      extraModules ? [ ],
    }:
    let
      specialArgs = {
        inherit
          inputs
          outputs
          username
          hostname
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
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            backupFileExtension = "hm-backup";
            extraSpecialArgs = specialArgs;
            sharedModules = [
              mac-app-util.homeManagerModules.default
              sops-nix.homeManagerModules.sops
            ];
            users.${username} = import homeFile;
          };
        }
      ]
      ++ extraModules;
    };
}
