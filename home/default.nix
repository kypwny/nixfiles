{
  pkgs,
  username,
  ...
}:
{
  home.username = username;
  home.homeDirectory = if pkgs.stdenv.isDarwin then "/Users/${username}" else "/home/${username}";

  home.stateVersion = "26.05";

  # Global Catppuccin Mocha theme for home-manager tools
  catppuccin = {
    enable = true;
    flavor = "mocha";
    accent = "blue";
  };

  home.sessionPath = [
    "$HOME/.local/bin"
    "/opt/homebrew/bin"
    "$HOME/go/bin"
    "$HOME/bin"
  ];

  home.sessionVariables = {
    MANPAGER = "sh -c 'col -bx | bat -l man -p'";
    MANROFFOPT = "-c";
  };

  programs.home-manager.enable = true;

  programs.git = {
    enable = true;
    settings.user = {
      name = "ky";
      email = "ky@tilde.horse";
    };
  };

  # Disable starship in favor of minimal custom prompt
  programs.starship.enable = false;

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    historySubstringSearch.enable = true;

    initContent = ''
      export TERM=xterm-256color

      # Git-aware minimal prompt
      autoload -Uz add-zsh-hook vcs_info
      zstyle ':vcs_info:git:*' check-for-changes true
      zstyle ':vcs_info:git:*' stagedstr '+'
      zstyle ':vcs_info:git:*' unstagedstr '*'
      zstyle ':vcs_info:git:*' formats ' %F{magenta}[%b%u%c]%f'
      zstyle ':vcs_info:git:*' actionformats ' %F{yellow}[%b|%a]%f'
      add-zsh-hook precmd vcs_info
      setopt prompt_subst

      prompt_status() {
        local code=$?
        if [[ $code -eq 0 ]]; then
          print -n "%F{green}●%f"
        elif [[ $code -eq 130 || $code -eq 148 ]]; then
          print -n "%F{yellow}◐%f"
        else
          print -n "%F{red}○%f"
        fi
      }

      PROMPT='$(prompt_status) %F{green}%n@%m%f %F{blue}%~%f''${vcs_info_msg_0_} %# '

      # Key bindings for history substring search
      bindkey '^[[A' history-substring-search-up
      bindkey '^[[B' history-substring-search-down
      bindkey -M vicmd 'k' history-substring-search-up
      bindkey -M vicmd 'j' history-substring-search-down
    '';
  };

  programs.ripgrep.enable = true;

  programs.bat = {
    enable = true;
    config = {
      paging = "never";
    };
  };

  programs.btop = {
    enable = true;
  };

  programs.eza = {
    enable = true;
    enableZshIntegration = true;
    icons = "auto";
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
