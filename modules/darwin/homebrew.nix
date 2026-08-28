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
      "bun"
      "can1357/tap/omp"
      "cmake"
      "dnscrypt-proxy"
      "dnsmasq"
      "docker"
      "docker-compose"
      "flashrom"
      "go"
      "gopls"
      "libimobiledevice"
      "mpv"
      "neovim"
      "openssh"
      "rojo"
      "sigrok-cli"
      "tree"
      "uv"
      "vips"
      "ykman"
      "zxing-cpp"
    ];

    casks = [
      "blackhole-2ch"
      "github"
      "ollama-app"
      "qbittorrent"
      "zed"
    ];
  };
}
