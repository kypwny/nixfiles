{
  pkgs,
  lib,
  inputs,
  ...
}:
let
  llmAgentsPkgs = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
  theme = import ../theme { inherit lib; };
in
{
  imports = [
    ./default.nix
    ./kitty.nix
    ./wezterm.nix
    ./theme.nix # base16 classic-dark: kitty, GTK/Qt, cursor, shell colours
  ];

  # navi runs red; the shared default.nix stays blue for the other hosts.
  catppuccin.accent = lib.mkForce "red";

  # Navi's prompt is blue; yoru and the other hosts keep the shared green.
  programs.zsh.initContent = lib.mkAfter ''
    PROMPT='$(prompt_status) %F{blue}%n@%m%f %F{blue}%~%f''${vcs_info_msg_0_} %# '
  '';

  # Allow legacy olm for gomuks
  nixpkgs.config.permittedInsecurePackages = [
    "olm-3.2.16"
  ];

  # Full user application suite matching active Gentoo environment
  home.packages =
    with pkgs;
    [
      # Shell / CLI tools
      glow

      # Email & Communications
      aerc
      dino
      gomuks-web
      vesktop
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
      wineWow64Packages.yabridge # the Wine yabridge 5.x is built against; see hosts/navi/gaming.nix
      sox
      ncmpcpp
      mpd

      # Graphics, 3D & Video Production
      blender
      gimp
      inkscape
      yt-dlp
      feh
      imv

      # Gaming, Emulation & Virtualization
      gamescope
      mangohud
      looking-glass-client

      # Wayland Desktop utilities
      grim
      slurp
      wl-clipboard
      libnotify

      # Development
      nil
      nixfmt
      zig

      # Tools the dotfiles call by name
      hyprlock
      hypridle
      hyprpaper
      hyprsunset
      hyprpicker
      waybar
      mako
      fuzzel
      swappy
      satty
      grimblast
      wlsunset
      playerctl
      brightnessctl
      pulsemixer
      torsocks
      ruby
      (python3.withPackages (ps: [ ps.requests ])) # waybar/weather.py
      lm_sensors
      liquidctl
      radeontop
      xrandr
      nnn
      bemoji
      pass
      rmpc
    ]
    ++ (with llmAgentsPkgs; [
      omp
      openskills
      skills
      skills-installer
    ]);

  # gpg.conf carried over from Gentoo (~/.gnupg/gpg.conf). The agent itself is
  # the NixOS-level programs.gnupg.agent, so no services.gpg-agent here.
  programs.gpg = {
    enable = true;
    settings = {
      keyid-format = "0xlong";
      fixed-list-mode = true;
      personal-digest-preferences = "SHA512 SHA384 SHA256 SHA224";
      default-preference-list = "SHA512 SHA384 SHA256 SHA224 AES256 AES192 AES CAST5 BZIP2 ZLIB ZIP Uncompressed";
      verify-options = "show-uid-validity";
      list-options = "show-uid-validity";
      cert-digest-algo = "SHA512";
      s2k-cipher-algo = "AES256";
      s2k-digest-algo = "SHA512";
      auto-key-locate = "local";
    };
  };

  # Hyprland + hy3. The compositor config is the dotfile, kept as-is so it can be
  # diffed against ~/dotfiles; only Gentoo-specific lines (hyprpm, gentoo-pipewire-
  # launcher, /usr/local portal path) were removed. HM loads hy3 declaratively.
  catppuccin.hyprland.enable = false; # its output is lua-only; this host uses hyprlang
  wayland.windowManager.hyprland = {
    enable = true;
    # Let NixOS module provide the wrapper and portal packages
    package = null;
    portalPackage = null;
    configType = "hyprlang";
    plugins = [ pkgs.hyprlandPlugins.hy3 ];
    extraConfig = builtins.readFile ./dots/hypr/hyprland.conf;
  };

  # gpg: keyserver over tor, as on Gentoo (~/.gnupg/dirmngr.conf)
  services.gpg-agent.enable = false;
  home.file.".gnupg/dirmngr.conf".text = ''
    use-tor
    keyserver hkp://zkaan2xfbuxia2wpf7ofnkbz6r5zdbbvxbunvp5g2iebopbfc4iqmbad.onion
  '';

  # passmenu was a hand-installed /usr/local/bin script; fuzzel + pass come from nix.
  home.file.".local/bin/passmenu" = {
    source = ./dots/bin/passmenu;
    executable = true;
  };

  xdg.configFile =
    let
      # The dotfiles are kept verbatim from ~/dotfiles (Catppuccin Mocha); every
      # Mocha colour is swapped for its base16 classic-dark role on the way in
      # (see theme/default.nix). `extra` handles strings the swap cannot know.
      retheme = theme.retheme {
        extra = [
          {
            from = "catppuccin_mocha.theme";
            to = "classic-dark.theme";
          }
        ];
      };
      read = path: retheme (builtins.readFile (./dots + "/${path}"));
      dot = path: { text = read path; };
      exe = path: {
        text = read path;
        executable = true;
      };
    in
    {
      "hypr/mocha.conf" = dot "hypr/mocha.conf";
      "hypr/hypridle.conf" = dot "hypr/hypridle.conf";
      "hypr/hyprlock.conf" = dot "hypr/hyprlock.conf";
      "hypr/hyprpaper.conf" = dot "hypr/hyprpaper.conf";
      "hypr/hyprsunset.conf" = dot "hypr/hyprsunset.conf";
      "hypr/scripts/screenshot.sh" = exe "hypr/scripts/screenshot.sh";
      "hypr/scripts/lock.sh" = exe "hypr/scripts/lock.sh";

      "waybar/config.jsonc" = dot "waybar/config.jsonc";
      "waybar/style.css" = dot "waybar/style.css";
      "waybar/sysinfo.rb" = exe "waybar/sysinfo.rb";
      "waybar/crypto.rb" = exe "waybar/crypto.rb";
      "waybar/xmr-price.sh" = exe "waybar/xmr-price.sh";

      "mako/config".text =
        builtins.replaceStrings
          [ "/usr/share/icons/Papirus-Dark" ]
          [ "${pkgs.papirus-icon-theme}/share/icons/Papirus-Dark" ]
          (read "mako/config");
      "fuzzel/fuzzel.ini" = dot "fuzzel/fuzzel.ini";
      "swappy/config" = dot "swappy/config";
      "rmpc/config.ron" = dot "rmpc/config.ron";
      "rmpc/themes/ky.ron" = dot "rmpc/themes/ky.ron";
      "fastfetch/config.jsonc" = dot "fastfetch/config.jsonc";
      "mpd/mpd.conf" = dot "mpd/mpd.conf";

      # programs.btop (default.nix) also writes this file; the dotfile wins.
      "btop/btop.conf".source = lib.mkForce (pkgs.writeText "btop.conf" (read "btop/btop.conf"));

      "xdg-desktop-portal-termfilechooser/config" = dot "termfilechooser/config";
      "xdg-desktop-portal-termfilechooser/nnn-wrapper.sh" = exe "termfilechooser/nnn-wrapper.sh";
    };

  # Gentoo's kitty.conf, layered over home/kitty.nix (font/opacity/IPC differ).
  programs.kitty = {
    font = {
      name = lib.mkForce "Maple Mono NF CN";
      size = lib.mkForce 11.0;
    };
    settings = {
      background_opacity = "0.95";
      listen_on = "unix:/tmp/kitty";
      wayland_enable_ime = true;
      text_composition_strategy = "platform";
    };
  };

  # Waybar is not a programs.waybar module here: the dotfile config/style are
  # linked individually below so ~/.config/waybar/weather.py (untracked, holds an
  # API key) can live next to them.

  # Notifications: mako (dots/mako/config), not dunst -- only one can own the bus name.

  # Rofi app launcher
  programs.rofi = {
    enable = true;
    settings = {
      terminal = "kitty";
    };
  };

  # OBS Studio with plugins
  programs.obs-studio = {
    enable = true;
    plugins = with pkgs.obs-studio-plugins; [
      obs-websocket
      obs-tuna
      obs-vkcapture
      obs-pipewire-audio-capture
      obs-move-transition
      input-overlay
      advanced-scene-switcher
    ];
  };

  # MangoHud game overlay
  programs.mangohud = {
    enable = true;
  };

  # Cava audio visualizer
  programs.cava = {
    enable = true;
  };

  # GTK, Qt and the cursor are themed in ./theme.nix (base16 classic-dark).

  # Environment variables for Wayland desktop
  home.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    ELECTRON_OZONE_PLATFORM_HINT = "auto";
    QT_QPA_PLATFORM = "wayland;xcb";
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

  # Ungoogled Chromium, Wayland-native under Hyprland
  programs.chromium = {
    enable = true;
    package = pkgs.ungoogled-chromium;
    commandLineArgs = [
      "--ozone-platform=wayland"
      "--enable-features=UseOzonePlatform,VaapiVideoDecoder,VaapiVideoEncoder"
    ];
    extensions = [
      { id = "cjpalhdlnbpafiamejdnhcphjbkeiagm"; } # uBlock Origin
    ];
  };
}
