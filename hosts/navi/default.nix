{ pkgs, ... }:
let
  vars = import ./vars.nix;
  inherit (vars) network;
in
{
  _module.args.vars = vars;

  imports = [
    ./hardware-configuration.nix
    ./kernel.nix
  ];

  # Hostname matching audit
  networking.hostName = vars.host.name;

  # NetworkManager configuration matching audit (br0 bridge with enp4s0 + Wi-Fi)
  networking.networkmanager = {
    enable = true;
    ensureProfiles.profiles = {
      "${network.bridge}" = {
        connection = {
          id = network.bridge;
          type = "bridge";
          interface-name = network.bridge;
          autoconnect = true;
          autoconnect-priority = 100;
        };
        bridge.stp = false;
        ipv4 = {
          method = "manual";
          address1 = network.hostCidr;
          inherit (network) gateway;
          dns = network.hostDns;
        };
        ipv6.method = "auto";
      };

      "${network.bridge}-${network.primaryInterface}" = {
        connection = {
          id = "${network.bridge}-${network.primaryInterface}";
          type = "ethernet";
          interface-name = network.primaryInterface;
          controller = network.bridge;
          port-type = "bridge";
          autoconnect = true;
          autoconnect-priority = 100;
        };
      };
    };
  };

  # Firewall rules reflecting audit (LAN-only SSH access + standard loopback/established)
  networking.firewall = {
    enable = true;
    extraCommands = ''
      iptables -A INPUT -s 192.168.1.0/24 -p tcp --dport 22 -m conntrack --ctstate NEW -j ACCEPT
    '';
  };

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

  # Gaming & audio support
  programs.steam.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
  security.rtkit.enable = true;

  # Hardware daemon: OpenRGB
  services.hardware.openrgb.enable = true;

  # Periodic fstrim (matching Gentoo cron job)
  services.fstrim.enable = true;
  # X11 Window Manager (i3)
  services.xserver = {
    enable = true;
    windowManager.i3.enable = true;
  };

  # Wayland Compositors (Niri and Sway available alongside i3)
  programs.niri.enable = true;
  programs.sway.enable = true;

  # Display manager: greetd with tuigreet listing all available X11 and Wayland sessions
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --sessions /run/current-system/sw/share/xsessions:/run/current-system/sw/share/wayland-sessions";
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

  # User group memberships
  users.users.${vars.user.name}.extraGroups = [
    "wheel"
    "libvirtd"
    "docker"
    "audio"
    "video"
    "networkmanager"
  ];
}
