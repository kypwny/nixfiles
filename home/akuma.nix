{ ... }:
{
  imports = [
    ./default.nix
    ./kitty.nix
    ./akuma-i3.nix
  ];

  home.file.".config/fastfetch/akuma-logo.txt".source = ./akuma-logo.txt;

  programs.fastfetch = {
    enable = true;
    settings = {
      logo = {
        type = "file-raw";
        source = "~/.config/fastfetch/akuma-logo.txt";
      };
      display = {
        color = "red";
      };
      modules = [
        "title"
        "separator"
        "os"
        "host"
        "kernel"
        "uptime"
        "packages"
        "shell"
        "cpu"
        "memory"
        "disk"
        "localip"
        "break"
        "colors"
      ];
    };
  };
}
