{ pkgs, ... }:
{
  fonts.packages = with pkgs; [
    maple-mono.Normal-NF
  ];

  environment.systemPackages = with pkgs; [
    vim
    wget
    curl
    git
    jq
    ripgrep
    fd
    tree
    fastfetch
    nil
    sbcl
    lftp
    ffmpeg
    imagemagick
    bun
    cmake
    flashrom
    go
    gopls
    libimobiledevice
    (mpv.override {
      scripts =
        with pkgs.mpvScripts;
        [
          uosc
          sponsorblock
          autoload
          mpv-webm
        ]
        ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [ mpris ];
    })
    weechat
    pfetch
    nix-output-monitor
    dust
    nvd
    sops
    age
    mtr
    neovim
    openssh
    rojo
    sigrok-cli
    uv
    vips
    yubikey-manager
    zxing-cpp
    innoextract
    lgogdownloader
    yt-dlp
    speedtest-go
    # The justfile assumes these are reachable from a plain shell. They were only
    # in the `default` devShell, which made `just switch` fail unless you had
    # already run `nix develop`. (Still needs one successful switch to appear.)
    just
    nh
    kitty.terminfo
  ];
}
