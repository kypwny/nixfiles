{ lib, pkgs, ... }:
let
  theme = import ../theme { inherit lib; };
  inherit (theme) hash;
  # Cozette 6x13 bitmap font — supports core X11 and Xft/Pango.
  bitmap = "-inesw-Cozette-Medium-R-Normal--13-120-75-75-M-60-ISO10646-1";
  pangoFont = "pango:Cozette 10";
  status = pkgs.writeText "akuma-i3status.conf" ''
    general {
      colors = false
      interval = 5
    }
    order += "load"
    order += "memory"
    order += "tztime local"
    load { format = "load %1min" }
    memory { format = "RAM %used / %total" }
    tztime local { format = "%Y-%m-%d %H:%M" }
  '';
in
{
  home.packages = [ pkgs.firefox ];

  xresources.properties = {
    "XTerm*faceName" = "Cozette";
    "XTerm*faceSize" = 10;
    "XTerm*font" = bitmap;
    "XTerm*boldFont" = bitmap;
    "XTerm*renderFont" = true;
    "XTerm*background" = hash "base00";
    "XTerm*foreground" = hash "base05";
    "XTerm*cursorColor" = hash "base05";
    "XTerm*saveLines" = 10000;
    "XTerm*scrollBar" = false;
    "XTerm*loginShell" = true;
    "XTerm*selectToClipboard" = true;
  }
  // lib.listToAttrs (
    lib.imap0 (i: c: lib.nameValuePair "XTerm*color${toString i}" "#${c}") theme.ansi
  );

  # No compositor, wallpaper service, panel framework, or auto-started VPN.
  # Alt avoids macOS consuming Command shortcuts.
  xdg.configFile."i3/config".text = ''
    set $mod Mod1
    font ${pangoFont}
    floating_modifier $mod
    default_border pixel 1
    focus_follows_mouse no
    client.focused ${hash "base0D"} ${hash "base00"} ${hash "base05"} ${hash "base0D"} ${hash "base0D"}
    client.unfocused ${hash "base02"} ${hash "base00"} ${hash "base04"} ${hash "base02"} ${hash "base02"}
    client.focused_inactive ${hash "base02"} ${hash "base00"} ${hash "base05"} ${hash "base02"} ${hash "base02"}
    client.urgent ${hash "base08"} ${hash "base08"} ${hash "base07"} ${hash "base08"} ${hash "base08"}

    bindsym $mod+Return exec ${pkgs.kitty}/bin/kitty
    bindsym $mod+d exec ${pkgs.dmenu}/bin/dmenu_run -fn 'Cozette-10' -nb '${hash "base00"}' -nf '${hash "base05"}' -sb '${hash "base02"}' -sf '${hash "base07"}'
    bindsym $mod+b exec ${pkgs.firefox}/bin/firefox
    bindsym $mod+Shift+q kill
    bindsym $mod+Shift+c reload
    bindsym $mod+Shift+r restart
    bindsym $mod+Shift+e exec ${pkgs.i3}/bin/i3-nagbar -t warning -m 'Exit i3?' -b 'Exit' '${pkgs.i3}/bin/i3-msg exit'
    bindsym $mod+Control+l exec ${pkgs.i3lock}/bin/i3lock -c ${theme.hex "base00"}
    bindsym $mod+f fullscreen toggle
    bindsym $mod+space focus mode_toggle
    bindsym $mod+Shift+space floating toggle
    bindsym $mod+h split h
    bindsym $mod+v split v
    bindsym $mod+s layout stacking
    bindsym $mod+w layout tabbed
    bindsym $mod+e layout toggle split
    bindsym $mod+Left focus left
    bindsym $mod+Down focus down
    bindsym $mod+Up focus up
    bindsym $mod+Right focus right
    bindsym $mod+Shift+Left move left
    bindsym $mod+Shift+Down move down
    bindsym $mod+Shift+Up move up
    bindsym $mod+Shift+Right move right
    ${lib.concatMapStringsSep "\n" (n: ''
      bindsym $mod+${toString n} workspace number ${toString n}
      bindsym $mod+Shift+${toString n} move container to workspace number ${toString n}
    '') (lib.range 1 9)}
    bindsym $mod+r mode "resize"
    mode "resize" {
      bindsym Left resize shrink width 10 px or 10 ppt
      bindsym Down resize grow height 10 px or 10 ppt
      bindsym Up resize shrink height 10 px or 10 ppt
      bindsym Right resize grow width 10 px or 10 ppt
      bindsym Return mode "default"
      bindsym Escape mode "default"
    }
    bar {
      font ${pangoFont}
      status_command ${pkgs.i3status}/bin/i3status -c ${status}
      colors {
        background ${hash "base00"}
        statusline ${hash "base05"}
        focused_workspace ${hash "base0D"} ${hash "base02"} ${hash "base05"}
        inactive_workspace ${hash "base00"} ${hash "base00"} ${hash "base04"}
        urgent_workspace ${hash "base08"} ${hash "base08"} ${hash "base07"}
      }
    }
  '';
}
