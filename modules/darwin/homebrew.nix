{
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = false;
      cleanup = "zap";
      upgrade = false;
    };

    taps = [
      "can1357/tap"
    ];

    brews = [
      "mas"
      "can1357/tap/omp"
      "dnscrypt-proxy"
      "dnsmasq"
      "docker"
      "docker-compose"
    ];

    casks = [
      "affinity"
      "blackhole-2ch"
      "blender"
      "brave-browser"
      "burp-suite"
      "discord"
      "freecad"
      "github"
      "keepassxc"
      "kicad"
      "lulu"
      "netnewswire"
      "obs"
      "obsidian"
      "ollama-app"
      "prismlauncher"
      "protonvpn"
      "qbittorrent"
      "roblox"
      "signal"
      "simplex"
      "steam"
      "telegram"
      "ultimaker-cura"
      "utm"
      "vivaldi"
      "waves-central"
      "whatsapp"
      "zed"
    ];

    masApps = {
      "BeagleIM" = 1445349494;
      "Monal" = 1637078500;
      "The Unarchiver" = 425424353;
      "WutheringWaves" = 6475033368;
    };
  };
}
