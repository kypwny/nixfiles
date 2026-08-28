{ pkgs, ... }:
{
  networking.hostName = "yoru";

  users.users.ky = {
    name = "ky";
    home = "/Users/ky";
    shell = pkgs.zsh;
  };

  programs.zsh.enable = true;
}
