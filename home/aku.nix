{ ... }:
{
  imports = [ ./default.nix ];

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

  programs.zsh = {
    initContent = ''
      # aku evil arsenal prompt: blood-red kanji + gothic arrows
      PROMPT='%F{red}☠ %B悪%b%f %F{196}❯%F{160}❯%F{124}❯%f %F{red}%n@%m%f %F{244}%~%f %F{red}#%f '
    '';
  };
}
