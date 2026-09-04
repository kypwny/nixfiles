{
  pkgs,
  inputs,
  ...
}:
let
  llmAgentsPkgs = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  imports = [
    ./default.nix
  ];

  # Full user application suite matching active Gentoo environment
  home.packages =
    with pkgs;
    [
      # Shell / CLI tools
      pfetch-rs
      fish
      tmux
      ripgrep
      fd
      jq
      bat
      eza
      tree
      glow
      fastfetch

      # Email & Communications
      aerc
      profanity
      dino
      gajim
      gomuks
      vesktop
      weechat
      mumble

      # Password & Security
      keepassxc

      # Audio, DAWs, Synthesis & Windows VST Bridge
      renoise
      ardour
      audacity
      easyeffects
      yabridge
      yabridgectl
      wineWow64Packages.staging
      sox
      cava
      ncmpcpp
      mpd

      # Graphics, 3D & Video Production
      blender
      gimp
      inkscape
      (wrapOBS {
        plugins = with obs-studio-plugins; [
          obs-websocket
          obs-tuna
          obs-vkcapture
          obs-pipewire-audio-capture
          obs-move-transition
          input-overlay
          advanced-scene-switcher
        ];
      })
      yt-dlp
      feh
      imv

      # Gaming, Emulation & Virtualization
      gamescope
      mangohud
      looking-glass-client

      # Desktop / Window Manager utilities (X11 & Wayland)
      rofi
      dunst
      i3status-rust
      foot
      kitty
      alacritty
      kdePackages.spectacle
      libnotify
      wl-clipboard
      xclip

      # Hardware, System & Network inspection
      lact
      wireshark

      # Development
      nil
      nixfmt
      zig
    ]
    ++ (with llmAgentsPkgs; [
      omp
      openskills
      skills
      skills-installer
    ]);

  # Window manager: i3 configuration stub
  xsession.windowManager.i3 = {
    enable = true;
    config = {
      modifier = "Mod4";
      terminal = "alacritty";
    };
  };

  # Alacritty terminal emulator
  programs.alacritty = {
    enable = true;
    settings = {
      window.opacity = 0.95;
      font.normal = {
        family = "monospace";
      };
    };
  };

  # mpv configuration matching shared config with AMD gpu/wayland optimizations
  programs.mpv = {
    enable = true;
    scripts = with pkgs.mpvScripts; [
      uosc
      sponsorblock
      autoload
      mpv-webm
      mpris
    ];
    config = {
      alang = "jpn,jp,eng,en,enUS,en-US";
      slang = "eng,en,und,jp,jap";
      blend-subtitles = "no";
      demuxer-mkv-subtitle-preroll = "yes";
      embeddedfonts = "yes";
      no-osd-bar = true;
      osd-font = "monospace";

      # Hardware acceleration & GPU
      vo = "gpu";
      hwdec = "vaapi";
      gpu-context = "wayland";
      profile = "gpu-hq";

      # Quality & scaling
      scale = "ewa_lanczossharp";
      cscale = "ewa_lanczossharp";
      dscale = "mitchell";
      video-sync = "display-resample";
      interpolation = true;
      tscale = "oversample";

      # AMD optimizations
      vd-lavc-dr = "yes";
      opengl-pbo = "yes";
      hwdec-codecs = "all";

      # Buffer & cache
      demuxer-max-bytes = 150000000;
      demuxer-max-back-bytes = 75000000;
      demuxer-readahead-secs = 10;

      # Screenshots
      screenshot-directory = "~/Pictures/mpv/screenshots";
      screenshot-png-compression = 9;

      # Subtitle styling
      sub-ass-scale-with-window = "no";
      sub-ass-use-video-data = "all";
      sub-auto = "fuzzy";
      sub-fix-timing = "no";

      # Streaming / yt-dlp
      ytdl-format = "bestvideo[height<=1440][ext=webm]+bestaudio/best";
    };
    bindings = {
      "LEFT" = "seek -3";
      "RIGHT" = "seek 3";
    };
  };
}
