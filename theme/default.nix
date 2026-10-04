# Single source of truth for navi's colours. Imported by NixOS modules (tty
# palette), home-manager modules (terminals, GTK/Qt) and pkgs/psyche-gtk.
{ lib }:
let
  scheme = import ./classic-dark.nix;
  inherit (scheme) colors;

  # `hex "base08"` -> "ac4142";  `hash "base08"` -> "#ac4142"
  hex = slot: colors.${slot};
  hash = slot: "#${colors.${slot}}";

  # ANSI 0-15 in the tinted-theming base16 shell order. Each terminal module
  # takes this list so they cannot drift from one another.
  ansi = map hex [
    "base00"
    "base08"
    "base0B"
    "base0A"
    "base0D"
    "base0E"
    "base0C"
    "base05"
    "base03"
    "base08"
    "base0B"
    "base0A"
    "base0D"
    "base0E"
    "base0C"
    "base07"
  ];

  # ---- retheme: Catppuccin Mocha -> this scheme --------------------------------
  # The Hyprland/waybar/mako/fuzzel/rmpc/... dotfiles are kept verbatim from
  # ~/dotfiles (so they still diff cleanly) and are written in Mocha colours.
  # Every Mocha value is swapped for its base16 counterpart at build time.
  # replaceStrings is a single left-to-right pass, so output is never rescanned,
  # and it matches substrings: `1e1e2edd` (8-digit alpha) and `rgb(f38ba8)` work
  # without any format-specific handling.
  mocha = {
    rosewater = "f5e0dc";
    flamingo = "f2cdcd";
    pink = "f5c2e7";
    mauve = "cba6f7";
    red = "f38ba8";
    maroon = "eba0ac";
    peach = "fab387";
    yellow = "f9e2af";
    green = "a6e3a1";
    teal = "94e2d5";
    sky = "89dceb";
    sapphire = "74c7ec";
    blue = "89b4fa";
    lavender = "b4befe";
    text = "cdd6f4";
    subtext1 = "bac2de";
    subtext0 = "a6adc8";
    overlay2 = "9399b2";
    overlay1 = "7f849c";
    overlay0 = "6c7086";
    surface2 = "585b70";
    surface1 = "45475a";
    surface0 = "313244";
    base = "1e1e2e";
    mantle = "181825";
    crust = "11111b";
  };
  # Where each Mocha role lands. Greys collapse (base16 has 8 greys, Mocha 12):
  # the three darkest backgrounds all become base00.
  mapping = {
    rosewater = "base06";
    flamingo = "base08";
    pink = "base0E";
    mauve = "base0E";
    red = "base08";
    maroon = "base08";
    peach = "base09";
    yellow = "base0A";
    green = "base0B";
    teal = "base0C";
    sky = "base0C";
    sapphire = "base0D";
    blue = "base0D";
    lavender = "base0D";
    text = "base05";
    subtext1 = "base04";
    subtext0 = "base04";
    overlay2 = "base04";
    overlay1 = "base03";
    overlay0 = "base03";
    surface2 = "base03";
    surface1 = "base02";
    surface0 = "base01";
    base = "base00";
    mantle = "base00";
    crust = "base00";
  };
  roles = builtins.attrNames mocha;

  # `extra` is a list of { from; to; } for strings the generic swap cannot know
  # about (e.g. a theme filename, or a terminal palette slot that needs the
  # official base16 ANSI mapping rather than the nearest Mocha grey).
  retheme =
    {
      extra ? [ ],
    }:
    text:
    builtins.replaceStrings (map (e: e.from) extra ++ map (r: mocha.${r}) roles) (
      map (e: e.to) extra ++ map (r: hex mapping.${r}) roles
    ) text;
in
{
  inherit
    scheme
    colors
    hex
    hash
    ansi
    retheme
    ;
  inherit (scheme) variant slug;
}
