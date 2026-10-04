# Game launchers and the Wine policy for navi.
#
# Wine policy (why there is no custom/overlaid wine anywhere in this repo):
#   A source build of wine (wow64 + staging) is the most expensive thing nixpkgs
#   can ask a machine to do, and none of navi's CPU flags would matter for it;
#   game performance comes from Proton-GE/DXVK/VKD3D builds and the kernel.
#   So every Wine here is the *unmodified* nixpkgs derivation, which means it is
#   fetched from cache.nixos.org (checked: wine staging 11.18, wine yabridge
#   9.21, proton-ge-bin, heroic, gamescope, umu-launcher are all cached; the
#   `lutris` wrapper is not, but it is a few seconds of Python). Never add an
#   overrideAttrs/overlay on a wine package: it turns that into a local rebuild
#   on every nixpkgs bump.
#
#   Three roles, kept separate so versions never fight over `wine` on PATH:
#     - DAW/VST bridge  -> wineWow64Packages.yabridge (9.21) is the Wine
#                          nixpkgs builds yabridge 5.x against; it is the user
#                          profile's `wine` (home/navi.nix). Wine 10+ breaks
#                          yabridge, so do NOT replace it with "newer staging".
#     - Steam games     -> Proton-GE as a compatibility tool, Valve's Proton via Steam.
#     - Everything else -> Lutris/Heroic, which carry their own FHS env; Lutris
#                          gets wine staging 11.18 as its "system" runner and
#                          can download further runners (ge-proton) into
#                          ~/.local/share/lutris, outside the nix store.
{ pkgs, ... }:
{
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    gamescopeSession.enable = true;
    extraCompatPackages = [ pkgs.proton-ge-bin ];
  };

  programs.gamemode.enable = true;
  programs.gamescope = {
    enable = true;
    capSysNice = true;
  };

  # 32-bit GL/Vulkan for wine/proton (steam turns this on too; stated here so
  # Lutris/Heroic do not depend on steam being enabled).
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  environment.systemPackages = [
    (pkgs.lutris.override {
      extraPkgs = p: [
        p.wineWow64Packages.staging
        p.winetricks
        p.gamemode
        p.gamescope
        p.mangohud
        p.umu-launcher
      ];
    })
    pkgs.heroic # Epic / GOG / Amazon; manages its own wine/proton runners
    pkgs.umu-launcher # Proton outside Steam, same runtime Lutris uses
    pkgs.protonplus # install/update Proton-GE & co. for Steam, Lutris, Heroic
    pkgs.protontricks
  ];
}
