{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (pkgs.stdenv.hostPlatform) isDarwin isLinux;
  # Hosts that opt out of Catppuccin (navi, see home/theme.nix) get the base16
  # palette instead of the plugin call, which would be undefined without it.
  theme = import ../theme { inherit lib; };
  quoted = map (c: ''"#${c}"'');
  base16Colors = ''
    config.colors = {
      foreground = "${theme.hash "base05"}",
      background = "${theme.hash "base00"}",
      cursor_bg = "${theme.hash "base05"}",
      cursor_fg = "${theme.hash "base00"}",
      selection_bg = "${theme.hash "base05"}",
      selection_fg = "${theme.hash "base00"}",
      ansi = { ${lib.concatStringsSep ", " (quoted (lib.take 8 theme.ansi))} },
      brights = { ${lib.concatStringsSep ", " (quoted (lib.drop 8 theme.ansi))} },
    }
  '';
in
{
  programs.wezterm = {
    enable = true;
    extraConfig =
      # catppuccin/nix prepends `catppuccin_plugin` (store path) and
      # `catppuccin_config` (flavor/accent) declarations to this file —
      # the theme is only applied when we invoke the plugin ourselves.
      ''
        local config = wezterm.config_builder()

        config.font = wezterm.font_with_fallback({ "Maple Mono Normal NF" })
        config.font_size = ${if isDarwin then "13.0" else "12.0"}
        config.default_cursor_style = "SteadyBlock"
        config.window_padding = { left = 8, right = 8, top = 8, bottom = 8 }
        config.hide_tab_bar_if_only_one_tab = true
        config.max_fps = 144
      ''
      + lib.optionalString isDarwin ''
        config.send_composed_key_when_left_alt_is_pressed = false
        config.send_composed_key_when_right_alt_is_pressed = false
      ''
      + lib.optionalString isLinux ''
        config.enable_wayland = true
        config.window_close_confirmation = "NeverPrompt"
      ''
      + (
        if config.catppuccin.enable then
          ''
            -- Apply catppuccin mocha/blue on top of the config built above.
            local catppuccin = require(catppuccin_plugin)
            config = catppuccin.apply_to_config(config, catppuccin_config)
          ''
        else
          base16Colors
      )
      + ''

        return config
      '';
  };
}
