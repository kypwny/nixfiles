{ pkgs, identity, ... }:
{
  networking.hostName = identity.hostname;

  # Keep these requested GUI tools available without entering a research shell.
  # ImHex's Homebrew cask failed at install time, so use the nixpkgs package.
  environment.systemPackages = [
    pkgs.ghidra
    pkgs.imhex
  ];

  users.users.${identity.user.name} = {
    name = identity.user.name;
    home = identity.homeDirectory;
    shell = pkgs.zsh;
  };

  programs.zsh.enable = true;
}
