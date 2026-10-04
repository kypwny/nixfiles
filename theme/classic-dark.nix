# Base16 "Classic Dark" by Jason Heeris (http://heeris.id.au)
# Source: https://github.com/tinted-theming/schemes (base16/classic-dark.yaml)
# Browse: https://tinted-theming.github.io/tinted-gallery/#base16-classic-dark
#
# Vendored as a Nix attrset (rather than fetched YAML) so evaluation needs no
# IFD. Hex digits only, lowercase, no leading `#`.
{
  system = "base16";
  name = "Classic Dark";
  slug = "classic-dark";
  variant = "dark";
  colors = {
    base00 = "151515"; # default background
    base01 = "202020"; # lighter background (status bars)
    base02 = "303030"; # selection background
    base03 = "505050"; # comments, invisibles, line highlighting
    base04 = "b0b0b0"; # dark foreground (status bars)
    base05 = "d0d0d0"; # default foreground
    base06 = "e0e0e0"; # light foreground
    base07 = "f5f5f5"; # lightest foreground
    base08 = "ac4142"; # red
    base09 = "d28445"; # orange
    base0A = "f4bf75"; # yellow
    base0B = "90a959"; # green
    base0C = "75b5aa"; # cyan
    base0D = "6a9fb5"; # blue
    base0E = "aa759f"; # magenta
    base0F = "8f5536"; # brown
  };
}
