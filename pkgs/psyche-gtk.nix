{
  lib,
  runCommand,
  writeText,
  theme,
}:
let
  # %%base0X%% tokens in the GTK4 template -> "#rrggbb" from the shared palette.
  slots = builtins.attrNames theme.colors;
  gtk4 = writeText "psyche-gtk4.css" (
    builtins.replaceStrings (map (s: "%%${s}%%") slots) (map theme.hash slots) (
      builtins.readFile ../themes/psyche-gtk/gtk-4.0/gtk.css.in
    )
  );
in
runCommand "psyche-gtk"
  {
    meta = {
      description = "ahoka GTK theme ported to GTK3 + GTK4 on base16 Classic Dark";
      # Derived from ahodesuka/dotfiles, which ships no licence: personal use only.
      license = lib.licenses.unfree;
      platforms = lib.platforms.linux;
    };
  }
  ''
    d=$out/share/themes/psyche
    mkdir -p $d/gtk-4.0
    cp ${../themes/psyche-gtk/index.theme} $d/index.theme
    cp -r --no-preserve=mode ${../themes/psyche-gtk/gtk-3.0} $d/gtk-3.0
    cp ${gtk4} $d/gtk-4.0/gtk.css
    cp ${gtk4} $d/gtk-4.0/gtk-dark.css
  ''
