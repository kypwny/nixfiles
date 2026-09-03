{ pkgs, ... }:
{
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
    btop
    nil
    sbcl
    lftp
    ffmpeg
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
        ++ pkgs.lib.optionals pkgs.stdenv.isLinux [ mpris ];
    })
    neovim
    openssh
    rojo
    sigrok-cli
    uv
    vips
    yubikey-manager
    zxing-cpp
    innoextract
    yt-dlp
  ];
}
