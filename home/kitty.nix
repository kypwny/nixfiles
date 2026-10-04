{ lib, pkgs, ... }:
{
  programs.kitty = {
    enable = true;
    font = {
      name = "Maple Mono Normal";
      size = if pkgs.stdenv.hostPlatform.isDarwin then 13.0 else 12.0;
    };
    settings = {
      disable_ligatures = "cursor";
      cursor_shape = "block";
      enabled_layouts = "splits";
      window_padding_width = 8;
      allow_remote_control = "yes";
      repaint_delay = 10;
      input_delay = 3;
      sync_to_monitor = true;
    }
    // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
      macos_option_as_alt = "both";
      macos_quit_when_last_window_closed = true;
      text_composition_strategy = "platform";
    }
    // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
      linux_display_server = "auto";
      confirm_os_window_close = 0;
    };
  };
}
