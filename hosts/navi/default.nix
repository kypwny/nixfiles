{ lib, pkgs, ... }:
let
  vars = import ./vars.nix;
in
{
  _module.args.vars = vars;

  imports = [
    ./hardware-configuration.nix
    ./impermanence.nix
    ./kernel.nix
    ./kernel-dev.nix
    ./build-fixes.nix
    ./gaming.nix
    ./looking-glass.nix
  ];

  # Hostname matching audit
  networking.hostName = vars.host.name;

  # br0 (bridge + enp4s0 port) and its DHCP/static choice come from the shared
  # modules/nixos/networking.nix; wlp5s0 (taiko-5G) is a runtime keyfile persisted
  # under /persist (see impermanence.nix), not declared here because of its PSK.

  # Firewall rules reflecting audit (LAN-only SSH access + standard loopback/established)
  networking.firewall = {
    enable = true;
    trustedInterfaces = [ "waydroid0" ];
    extraCommands = ''
      iptables -A INPUT -s 192.168.67.0/24 -p tcp --dport 22 -m conntrack --ctstate NEW -j ACCEPT
    '';
  };

  networking.networkmanager.unmanaged = [ "interface-name:waydroid0" ];

  # Android containerisation
  virtualisation.waydroid.enable = true;

  # Virtualization & containerization (libvirtd / QEMU / Docker from Gentoo services)
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = true;
      swtpm.enable = true;
    };
  };
  virtualisation.docker.enable = true;

  # Audio (game launchers, steam and wine live in ./gaming.nix)
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
  security.rtkit.enable = true;

  # TTY palette: same base16 classic-dark source as home/theme.nix.
  console.colors = (import ../../theme { inherit lib; }).ansi;

  # Quiet boot: keep kernel/systemd chatter off the console so tuigreet's TUI
  # stays intact. The LUKS passphrase goes through the Plymouth splash.
  boot.plymouth.enable = true;
  boot.consoleLogLevel = 0;
  boot.initrd.verbose = false;
  boot.kernelParams = [
    "quiet"
    "splash"
    "loglevel=3"
    "udev.log_level=3"
    "systemd.show_status=auto"
    "rd.systemd.show_status=auto"
  ];

  # Hardware daemon: OpenRGB
  services.hardware.openrgb.enable = true;

  # Periodic fstrim (matching Gentoo cron job)
  services.fstrim.enable = true;

  # Wayland Compositors (Hyprland, Niri, Sway)
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };
  programs.niri.enable = true;
  programs.sway.enable = true;

  # gpg-agent (SSH support is enabled fleet-wide in modules/nixos/programs.nix);
  # a GUI pinentry is needed under Hyprland, the default is curses-only.
  programs.gnupg.agent.pinentryPackage = pkgs.pinentry-qt;

  # Display manager: greetd with tuigreet listing all available X11 and Wayland sessions
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --theme 'border=blue;text=white;prompt=green;time=darkgray;action=blue;button=yellow;container=black;input=white' --sessions /run/current-system/sw/share/xsessions:/run/current-system/sw/share/wayland-sessions";
        user = "greeter";
      };
    };
  };

  # AMD GPU Control daemon (LACT)
  services.lact.enable = true;

  # Network packet analysis privileges
  programs.wireshark = {
    enable = true;
    package = pkgs.wireshark;
  };

  # Host packages reflecting Gentoo install tooling
  environment.systemPackages = with pkgs; [
    git
    vim
    neovim
    curl
    wget
    pciutils
    usbutils
    lm_sensors
    liquidctl
    openrgb
    wireguard-tools
    btop
    fastfetch
    efibootmgr
  ];

  # zsh is navi's login shell (the shared users module defaults to fish; the
  # prompt and plugins are configured in home/default.nix).
  programs.zsh.enable = true;

  users.users.${vars.user.name} = {
    shell = lib.mkForce pkgs.zsh;
    extraGroups = [
      "wheel"
      "libvirtd"
      "kvm"
      "docker"
      "audio"
      "video"
      "networkmanager"
    ];
  };
}
