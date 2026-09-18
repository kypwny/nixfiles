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
    lgogdownloader
    ext4fuse
    yt-dlp
    speedtest-go
    # The justfile assumes these are reachable from a plain shell. They were only
    # in the `default` devShell, which made `just switch` fail unless you had
    # already run `nix develop`. (Still needs one successful switch to appear.)
    just
    nh
  ];
}
