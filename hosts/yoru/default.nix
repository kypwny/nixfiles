{
  pkgs,
  identity,
  inputs,
  ...
}:
let
  stablePkgs = inputs.nixpkgs-stable.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  networking.hostName = identity.hostname;

  # Keep these requested GUI tools available without entering a research shell.
  # ImHex's Homebrew cask failed at install time, so use the nixpkgs package.
  environment.systemPackages = [
    pkgs.ghidra
    pkgs.imhex
  ];

  # Use cached outputs from the stable package set for the shared graphics and
  # media stack. In particular, keep ffmpeg paired with the HarfBuzz it was built
  # against instead of changing its dependency via a host-wide doCheck override.
  nixpkgs.overlays = [
    (_: _prev: {
      inherit (stablePkgs)
        harfbuzz
        libjxl
        ffmpeg
        imagemagick
        vips
        mpv
        ;
    })
  ];

  # Nix-managed launchd daemon and CLI; authenticate once with sudo tailscale up.
  services.tailscale.enable = true;

  users.users.${identity.user.name} = {
    name = identity.user.name;
    home = identity.homeDirectory;
    shell = pkgs.zsh;
  };

  programs.zsh.enable = true;
}
