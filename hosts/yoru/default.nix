{ pkgs, ... }:
{
  networking.hostName = "yoru";

  # Keep these requested GUI tools available without entering a research shell.
  # ImHex's Homebrew cask failed at install time, so use the nixpkgs package.
  environment.systemPackages = [
    pkgs.ghidra
    pkgs.imhex
  ];

  users.users.ky = {
    name = "ky";
    home = "/Users/ky";
    shell = pkgs.zsh;
  };

  programs.zsh.enable = true;
}
