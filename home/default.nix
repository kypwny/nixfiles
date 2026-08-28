{
  pkgs,
  username,
  ...
}:
{
  home.username = username;
  home.homeDirectory = if pkgs.stdenv.isDarwin then "/Users/${username}" else "/home/${username}";

  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  programs.git = {
    enable = true;
    settings.user = {
      name = "ky";
      email = "ky@tilde.horse";
    };
  };

  programs.starship = {
    enable = true;
    settings = {
      nix_shell = {
        disabled = false;
        heuristic = true;
      };
    };
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
  };

  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set fish_greeting
      fish_config theme choose catppuccin-mocha --color-theme=dark >/dev/null 2>&1
    '';
  };

  programs.ripgrep.enable = true;
  programs.bat.enable = true;
  programs.eza.enable = true;
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
