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
      # xcodes installs/switches Xcode versions from Apple's servers. There is
      # NO `xcode` cask — Xcode is Apple-ID gated, so it cannot be declared
      # declaratively. One-time: `xcodes install <version>` (interactive login).
      "xcodes"
      "dnscrypt-proxy"
      "dnsmasq"
      "docker"
      "docker-compose"
    ];

    casks = [
      # sdkmanager + avdmanager. The Android emulator and its system images are
      # Google-side downloads, so the SDK cannot come from nix; this cask is the
      # smallest way to get it. See ~/tansu/notes/android-api-re.md.
      "android-commandlinetools"
      "affinity"
      "blackhole-2ch"
      "blender"
      "blockblock"
      "brave-browser"
      "burp-suite"
      "discord"
      "freecad"
      "github"
      # Wine gaming launchers (requires Rosetta 2: softwareupdate --install-rosetta)
      "heroic"
      "porting-kit"
      # nixpkgs ghostty has no darwin build; the cask provides the app while
      # home/ghostty.nix writes its config.
      "ghostty"
      # Re-signing / bundling IPAs for on-device work. The other iOS-relevant
      # casks do not exist or are unusable: no `xcode` cask (Apple-ID gated, use
      # the xcodes formula), no `palera1n` cask (pinned as packages.palera1n),
      # no `ghidra` cask (nixpkgs ghidra is used instead), and the `checkra1n`
      # cask is disabled by Homebrew for failing the Gatekeeper check.
      "ios-app-signer"
      "keepassxc"
      "kicad"
      "linphone"
      "lulu"
      # fuse-t replaces macfuse: kext-free (userspace NFS-loopback) FUSE for
      # occasional HDD mounts. Nothing on this machine requires macFUSE.
      "fuse-t"
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
      "tor-browser"
      "ultimaker-cura"
      "utm"
      "whatsapp"
      # Token is wireshark-app (old token: wireshark). The cask installs the
      # GUI, ChmodBPF (live capture), and the CLI tools onto PATH.
      "wireshark-app"
      "zed"
    ];

    masApps = {
      "The Unarchiver" = 425424353;
      "WutheringWaves" = 6475033368;
    };
  };
}
