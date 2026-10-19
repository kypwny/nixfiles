# nix eval --impure --json --expr 'import ./tests/akuma-desktop.nix { flake = builtins.getFlake ("git+file://" + toString ./.); }'
{ flake }:
let
  c = flake.nixosConfigurations.akuma.config;
  h = c.home-manager.users.ky;
in
assert flake.nixosConfigurations.akuma.pkgs.stdenv.hostPlatform.system == "aarch64-linux";
assert c.services.xserver.enable;
assert c.services.xserver.windowManager.i3.enable;
assert c.services.xserver.displayManager.lightdm.enable;
assert c.services.xserver.displayManager.lightdm.greeters.mini.enable;
assert c.services.xserver.displayManager.lightdm.greeters.mini.user == "ky";
assert c.services.xserver.displayManager.lightdm.greeters.gtk.enable == false;
assert c.services.displayManager.defaultSession == "none+i3";
assert c.services.xserver.displayManager.startx.enable == false;
assert !c.services.displayManager.autoLogin.enable;
assert
  builtins.match ".*Cozette.*" c.services.xserver.displayManager.lightdm.greeters.mini.extraConfig
  != null;
assert c.services.openssh.enable;
assert !c.services.openssh.settings.PasswordAuthentication;
assert c.fonts.fontconfig.allowBitmaps;
assert builtins.elem "cozette" (map (p: p.pname or "") c.fonts.packages);
assert builtins.hasAttr "i3/config" h.xdg.configFile;
assert builtins.match ".*Cozette.*" h.xdg.configFile."i3/config".text != null;
assert h.programs.kitty.enable;
assert builtins.match ".*bindsym.*Return exec .*kitty.*" h.xdg.configFile."i3/config".text != null;
assert !flake.nixosConfigurations.kura.config.services.xserver.enable;
{
  host = c.networking.hostName;
  inherit (flake.nixosConfigurations.akuma.pkgs.stdenv.hostPlatform) system;
  i3Config = h.xdg.configFile."i3/config".source;
  xresources = h.home.file.${h.xresources.path}.source;
  toplevel = c.system.build.toplevel.drvPath;
}
