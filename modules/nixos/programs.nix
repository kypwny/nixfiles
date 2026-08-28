{ pkgs, ... }:
{
  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set fish_greeting
      fish_config theme choose catppuccin-mocha --color-theme=dark >/dev/null 2>&1
    '';
  };

  environment.systemPackages = with pkgs; [
    aria2
    bubblewrap
    python3
    gnupg
  ];

  environment.localBinInPath = true;

  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    libx11
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxrandr
    libxcb
    gtk3
    glib
    nss
    nspr
    alsa-lib
    cups
    libdrm
    dbus
    expat
    fontconfig
    freetype
    mesa
    pango
    cairo
    wayland
    libxkbcommon
  ];

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
    settings = {
      allow-loopback-pinentry = true;
    };
  };
}
