{ ... }:
{
  imports = [
    ./default.nix
    ./wezterm.nix
  ];

  home.file.".config/fastfetch/aku-logo.txt".source = ./aku-logo.txt;

  programs.fastfetch = {
    enable = true;
    settings = {
      logo = {
        type = "file-raw";
        source = "~/.config/fastfetch/aku-logo.txt";
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
