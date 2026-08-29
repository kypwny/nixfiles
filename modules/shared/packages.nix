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
  ];
}
