{ lib, pkgs, ... }:
{
  # nixpkgs ghostty is Linux-only (no darwin in meta.platforms), so the app
  # comes from the homebrew cask (modules/darwin/homebrew.nix) and this module
  # writes ~/.config/ghostty/config, which that app reads.
  programs.ghostty = {
    enable = true;
    package = null;

    settings = {
      font-family = "Maple Mono Normal NF";
      font-size = if pkgs.stdenv.hostPlatform.isDarwin then 13.0 else 12.0;
      cursor-style = "block";
      window-padding-x = 8;
      window-padding-y = 8;
    }
    // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
      macos-option-as-alt = true;
      quit-after-last-window-closed = true;
    };
  };
}
