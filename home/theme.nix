# navi's look: base16 Classic Dark everywhere, from a single palette (../theme).
#
# What reads from where:
#   - raw dotfiles (hypr, waybar, mako, fuzzel, foot, rmpc, ...): home/navi.nix
#     rewrites their Catppuccin Mocha colours at build time (theme.retheme)
#   - kitty / alacritty / btop / fzf / cava / mangohud / rofi: set below
#   - GTK3 + GTK4: the custom "psyche" theme (pkgs/psyche-gtk.nix, themes/psyche-gtk)
#   - Qt: follows the GTK settings through the gtk3 platform theme
#   - ttys + tuigreet: hosts/navi/default.nix (console.colors)
# The shared home/default.nix turns Catppuccin on for every host; navi opts out.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  theme = import ../theme { inherit lib; };
  inherit (theme) hash hex;
  psyche = pkgs.callPackage ../pkgs/psyche-gtk.nix { inherit theme; };
  ansiAttrs = lib.listToAttrs (
    lib.imap0 (i: c: lib.nameValuePair "color${toString i}" "#${c}") theme.ansi
  );
in
{
  catppuccin.enable = lib.mkForce false;

  # ---- terminals ---------------------------------------------------------------
  programs.kitty.settings = ansiAttrs // {
    foreground = hash "base05";
    background = hash "base00";
    selection_foreground = hash "base00";
    selection_background = hash "base05";
    cursor = hash "base05";
    cursor_text_color = hash "base00";
    url_color = hash "base0D";
    active_border_color = hash "base08";
    inactive_border_color = hash "base03";
    bell_border_color = hash "base0A";
    active_tab_foreground = hash "base07";
    active_tab_background = hash "base08";
    inactive_tab_foreground = hash "base04";
    inactive_tab_background = hash "base01";
    tab_bar_background = hash "base00";
    mark1_foreground = hash "base00";
    mark1_background = hash "base0D";
  };

  programs.alacritty.settings.colors = {
    primary = {
      background = hash "base00";
      foreground = hash "base05";
    };
    cursor = {
      text = hash "base00";
      cursor = hash "base05";
    };
    normal = {
      black = hash "base00";
      red = hash "base08";
      green = hash "base0B";
      yellow = hash "base0A";
      blue = hash "base0D";
      magenta = hash "base0E";
      cyan = hash "base0C";
      white = hash "base05";
    };
    bright = {
      black = hash "base03";
      red = hash "base08";
      green = hash "base0B";
      yellow = hash "base0A";
      blue = hash "base0D";
      magenta = hash "base0E";
      cyan = hash "base0C";
      white = hash "base07";
    };
  };

  # ---- shell + CLI -------------------------------------------------------------
  # The prompt (home/default.nix) uses ANSI names, so it picks the palette up
  # from the terminal: green user@host, blue path, magenta branch — same prompt
  # as yoru, in classic-dark colours.
  programs.bat.config.theme = "base16"; # ANSI theme: follows the terminal palette
  programs.fzf.colors = {
    fg = hash "base05";
    bg = hash "base00";
    hl = hash "base0D";
    "fg+" = hash "base06";
    "bg+" = hash "base01";
    "hl+" = hash "base0D";
    info = hash "base0A";
    prompt = hash "base0D";
    pointer = hash "base08";
    marker = hash "base0B";
    spinner = hash "base0C";
    header = hash "base03";
  };

  # btop: dotfiles/btop/btop.conf points at this theme name (see navi.nix).
  xdg.configFile."btop/themes/classic-dark.theme".text = ''
    theme[main_bg]="${hash "base00"}"
    theme[main_fg]="${hash "base05"}"
    theme[title]="${hash "base05"}"
    theme[hi_fg]="${hash "base0D"}"
    theme[selected_bg]="${hash "base02"}"
    theme[selected_fg]="${hash "base07"}"
    theme[inactive_fg]="${hash "base03"}"
    theme[graph_text]="${hash "base04"}"
    theme[meter_bg]="${hash "base02"}"
    theme[proc_misc]="${hash "base0C"}"
    theme[cpu_box]="${hash "base0B"}"
    theme[mem_box]="${hash "base0A"}"
    theme[net_box]="${hash "base0E"}"
    theme[proc_box]="${hash "base08"}"
    theme[div_line]="${hash "base02"}"
    theme[temp_start]="${hash "base0B"}"
    theme[temp_mid]="${hash "base0A"}"
    theme[temp_end]="${hash "base08"}"
    theme[cpu_start]="${hash "base0B"}"
    theme[cpu_mid]="${hash "base0A"}"
    theme[cpu_end]="${hash "base08"}"
    theme[free_start]="${hash "base0B"}"
    theme[free_mid]="${hash "base0A"}"
    theme[free_end]="${hash "base08"}"
    theme[cached_start]="${hash "base0D"}"
    theme[cached_mid]="${hash "base0E"}"
    theme[cached_end]="${hash "base08"}"
    theme[available_start]="${hash "base0B"}"
    theme[available_mid]="${hash "base0A"}"
    theme[available_end]="${hash "base08"}"
    theme[used_start]="${hash "base0B"}"
    theme[used_mid]="${hash "base0A"}"
    theme[used_end]="${hash "base08"}"
    theme[download_start]="${hash "base0D"}"
    theme[download_mid]="${hash "base0E"}"
    theme[download_end]="${hash "base08"}"
    theme[upload_start]="${hash "base0D"}"
    theme[upload_mid]="${hash "base0E"}"
    theme[upload_end]="${hash "base08"}"
  '';

  programs.cava.settings.color = {
    gradient = 1;
    gradient_color_1 = "'${hash "base0D"}'";
    gradient_color_2 = "'${hash "base0C"}'";
    gradient_color_3 = "'${hash "base0B"}'";
    gradient_color_4 = "'${hash "base0A"}'";
    gradient_color_5 = "'${hash "base09"}'";
    gradient_color_6 = "'${hash "base08"}'";
  };

  programs.mangohud.settings = {
    background_color = hex "base00";
    text_color = hex "base05";
    gpu_color = hex "base0B";
    cpu_color = hex "base0D";
    vram_color = hex "base0E";
    ram_color = hex "base0A";
    engine_color = hex "base08";
    frametime_color = hex "base0B";
    media_player_color = hex "base05";
  };

  # ---- toolkit theming ---------------------------------------------------------
  gtk = {
    enable = true;
    theme = {
      name = "psyche";
      package = psyche;
    };
    gtk4.theme = config.gtk.theme; # libadwaita reads ~/.config/gtk-4.0/gtk.css
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    font = {
      name = "Maple Mono NF CN";
      size = 10;
    };
  };

  # Qt follows the GTK theme: no Kvantum theme to keep in sync with the palette.
  qt = {
    enable = true;
    platformTheme.name = "gtk3";
  };

  home.pointerCursor = {
    enable = true;
    gtk.enable = true;
    x11.enable = true;
    name = "Bibata-Modern-Classic";
    package = pkgs.bibata-cursors;
    size = 24;
  };
}
