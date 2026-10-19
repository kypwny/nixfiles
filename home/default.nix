{
  pkgs,
  identity,
  ...
}:
{
  home.username = identity.user.name;
  home.homeDirectory = identity.homeDirectory;

  home.stateVersion = "26.05";

  # Global Catppuccin Mocha theme for home-manager tools
  catppuccin = {
    enable = true;
    autoEnable = true;
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
    MANPAGER = "sh -c 'col -bx | bat -l man -p --paging=always'";
    MANROFFOPT = "-c";
  };

  programs.home-manager.enable = true;

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      "*" = {
        hashKnownHosts = true;
        addressFamily = "inet";
        visualHostKey = true;
      };
      "github.com" = {
        user = "git";
        identitiesOnly = true;
        identityFile = "~/.ssh/ky";
        controlMaster = "no";
      };
      "git.tilde.horse" = {
        user = "forgejo";
        identitiesOnly = true;
        identityFile = "~/.ssh/ky";
      };
      "root@tilde.horse" = {
        hostname = "tilde.horse";
        user = "root";
        identitiesOnly = true;
        identityFile = "~/.ssh/evil";
        identityAgent = "none";
      };
      "tilde.horse" = {
        user = "ky";
        identitiesOnly = true;
        identityFile = "~/.ssh/ky";
      };
      # Fallback for the home network, where the ISP blacklists tilde.horse's
      # IP: hop through kura, which routes 65.87.7.164 via the Mullvad split
      # tunnel. Direct is the default because the jump fails whenever kura
      # isn't reachable. For the other tilde.horse hosts use `ssh -J kura <host>`.
      "tilde.horse-via-kura" = {
        hostname = "tilde.horse";
        user = "ky";
        identitiesOnly = true;
        identityFile = "~/.ssh/ky";
        proxyJump = "kura";
      };
      "matrix.tilde.horse" = {
        user = "root";
        port = 2077;
        identitiesOnly = true;
        identityFile = "~/.ssh/evil";
        identityAgent = "none";
      };
      "pony.kyun.li" = {
        user = "root";
        identitiesOnly = true;
        identityFile = "~/.ssh/evil";
        identityAgent = "none";
      };
      "kura" = {
        hostname = "kura.local";
        user = "ky";
        identityFile = "~/.ssh/ky"; # unicorn
        identitiesOnly = true;
      };
      "akuma" = {
        hostname = "192.168.64.2";
        user = "ky";
        identityFile = "~/.ssh/id_ed25519";
      };
    };
  };

  programs.git = {
    enable = true;
    settings = {
      user = identity.git;
      gpg = {
        format = "ssh";
        ssh = {
          # nix-darwin leaves a stale /run/current-system ssh-keygen first on
          # PATH; pin the platform signer so commits actually get signed.
          program = if pkgs.stdenv.hostPlatform.isDarwin then "/usr/bin/ssh-keygen" else "ssh-keygen";
          allowedSignersFile = "~/.ssh/allowed_signers";
        };
      };
      commit = {
        gpgsign = true;
      };
      tag = {
        gpgsign = true;
      };
    };
  };

  # Trust our own ssh signing keys so `git log --show-signature` verifies:
  # the file-backed key (old commits) and yoru's Secretive key (new commits).
  home.file.".ssh/allowed_signers".text = ''
    ${identity.allowedSigner}
    ${identity.git.email} ${identity.sshKeys.yoruEcdsa}
  '';

  programs.gh = {
    enable = true;
  };

  # Disable starship in favor of minimal custom prompt
  programs.starship.enable = false;

  # Fish shell enabled in Home Manager across all hosts
  # (Enables declarative completions, catppuccin.fish, and fzf/zoxide/direnv integrations)
  programs.fish.enable = true;

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    historySubstringSearch.enable = true;

    initContent = ''
      # Preserve the configured terminal's terminfo; fallback only for unknown terminals.
      if [[ -z "$KITTY_WINDOW_ID" && "$TERM" != "xterm-kitty" && "$TERM" != "xterm-ghostty" ]]; then
        export TERM=xterm-256color
      fi

      # Git-aware minimal prompt
      autoload -Uz add-zsh-hook vcs_info
      zstyle ':vcs_info:git:*' check-for-changes true
      zstyle ':vcs_info:git:*' stagedstr '+'
      zstyle ':vcs_info:git:*' unstagedstr '*'
      zstyle ':vcs_info:git:*' formats ' %F{yellow}[%b%u%c]%f'
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

      case "$HOST" in
        *kura*) host_color="green" ;;
        *akuma*) host_color="red" ;;
        *yoru*|*) host_color="250" ;;
      esac

      PROMPT='$(prompt_status) %B%F{green}%n%f@%F{''${host_color}}%m%f%b %F{magenta}%~%f''${vcs_info_msg_0_} %# '

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

  programs.tmux = {
    enable = true;
    mouse = true;
    keyMode = "vi";
    escapeTime = 0;
    terminal = "tmux-256color";

    # Load defaults first so the explicit settings above still win.
    sensibleOnTop = true;
    # Continuum must follow theme plugins: its status-right hook drives saves.
    plugins = pkgs.lib.mkAfter [
      {
        plugin = pkgs.tmuxPlugins.yank;
        extraConfig = ''
          # Use OSC 52 over SSH when no desktop clipboard tool is available.
          set -g @custom_copy_command 'tmux set-buffer -w -- "$(cat)"'
          # Keep tmux's existing mouse-selection behavior.
          set -g @yank_with_mouse 'off'
        '';
      }
      {
        plugin = pkgs.tmuxPlugins.resurrect;
        extraConfig = ''
          # Restore layouts manually, never restart saved applications or log panes.
          set -g @resurrect-processes 'false'
          set -g @resurrect-capture-pane-contents 'off'
          set -g @resurrect-never-overwrite 'on'
        '';
      }
      {
        plugin = pkgs.tmuxPlugins.continuum;
        extraConfig = ''
          set -g @continuum-save-interval '15'
          set -g @continuum-restore 'off'
          set -g @continuum-boot 'off'
        '';
      }
    ];
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
  };

  programs.tealdeer = {
    enable = true;
    settings.updates.auto_update = true;
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
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

  programs.yt-dlp = {
    enable = true;
    settings = {
      extractor-args = "youtube:player_client=mweb,android,web";
    };
  };
}
