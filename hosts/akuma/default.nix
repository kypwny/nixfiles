# akuma — the arm64 NixOS guest: the Linux bench for yoru.
#
# Where the things darwin cannot do happen: the Linux-only offensive tools
# (netexec, hydra, bettercap, mitmproxy, bloodhound, real wordlists), the HTB
# VPN in an environment that expects it, and Linux kernel builds with a KVM
# boot loop if nested virtualisation is available.
#
# Installed from the NixOS aarch64 ISO and managed from inside with
#   nixos-rebuild switch --flake ~/nixfiles#akuma
# See docs/hosts/akuma.md for the one-time bootstrap.
{
  pkgs,
  lib,
  identity,
  ...
}:

let
  adminUser = identity.user.name;
  stateVersion = "26.05";

  # Shared classic-dark palette; the greeter is themed from it so
  # there is one source of truth for colour.
  theme = import ../../theme { inherit lib; };

  # Cozette is 6x13 at its native size; 10pt is the integer scale GTK picks it at.
  greeterFont = "Cozette 10";
in
{
  # The one key already trusted on kura, reused so there is a single
  # source of truth for "which key is ky".
  _module.args.vars = {
    host = {
      name = identity.hostname;
      inherit stateVersion;
    };

    user = {
      name = adminUser;
      uid = identity.user.uid;
      authorizedKeys = [
        identity.sshKeys.pwny
      ];
    };
  };

  networking.hostName = identity.hostname;

  # Declared, not discovered. UTM gives the guest a single virtio disk as /dev/vda;
  # the bootstrap partitions it exactly this way, so no hardware-configuration.nix
  # is needed and the layout survives a reinstall.
  fileSystems."/" = {
    device = "/dev/vda2";
    fsType = "ext4";
  };
  fileSystems."/boot" = {
    device = "/dev/vda1";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  # zramSwap comes from modules/vm; there is no swap partition.
  swapDevices = [ ];

  # ---- graphical login on the UTM console -------------------------------------
  # lightdm + the mini greeter: a real login prompt on tty1 that starts i3.
  # SSH stays the primary control plane and is untouched. NixOS owns the system
  # plumbing (xserver, lightdm, the i3 session script, fonts, xterm on PATH);
  # Home Manager owns the per-user config (i3 config text, Xresources, XTerm
  # theme).
  services.xserver = {
    enable = true;
    videoDrivers = [ "modesetting" ];
    windowManager.i3 = {
      enable = true;
      # Runs inside the session before i3, so XTerm picks up the Home Manager
      # Xresources. Without this the file on disk is never loaded.
      extraSessionCommands = ''
        if [ -r "$HOME/.Xresources" ]; then
          ${pkgs.xrdb}/bin/xrdb -merge "$HOME/.Xresources"
        fi
        ${pkgs.xsetroot}/bin/xsetroot -solid '${theme.hash "base00"}'
      '';
    };

    displayManager.lightdm = {
      enable = true;
      background = theme.hash "base00";
      # Single-user bench: the mini greeter authenticates one account and starts
      # the default session. No autologin — this is a real login prompt.
      greeters.mini = {
        enable = true;
        user = adminUser;
        extraConfig = ''
          [greeter-theme]
          font = ${greeterFont}
          text-color = "${theme.hash "base05"}"
          error-color = "${theme.hash "base08"}"
          background-color = "${theme.hash "base00"}"
          window-color = "${theme.hash "base02"}"
          border-color = "${theme.hash "base0D"}"
          border-width = 2px
          password-color = "${theme.hash "base05"}"
          password-background-color = "${theme.hash "base01"}"
          password-border-color = "${theme.hash "base0D"}"
          password-border-width = 2px
        '';
      };
    };
  };

  # The mini greeter only ever starts the default session; `none+i3` is the name
  # NixOS gives the bare i3 window manager (no desktop manager in the pair).
  services.displayManager.defaultSession = "none+i3";

  fonts = {
    packages = [
      pkgs.cozette
      pkgs.terminus_font
    ];
    fontDir.enable = true;
    fontconfig.allowBitmaps = true;
  };

  environment.systemPackages = with pkgs; [
    xterm
    xclip
    xrandr
    xlsfonts
  ];
}
