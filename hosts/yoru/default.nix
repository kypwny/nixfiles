{ pkgs, identity, ... }:
let
  # yoru's Tailscale IPv4 address (stable for this node).
  tailnetAddress = "100.102.52.1";
in
{
  networking.hostName = identity.hostname;

  # Keep these requested GUI tools available without entering a research shell.
  # ImHex's Homebrew cask failed at install time, so use the nixpkgs package.
  environment.systemPackages = [
    pkgs.ghidra
    pkgs.imhex
  ];

  # Nix-managed launchd daemon and CLI; authenticate once with sudo tailscale up.
  services.tailscale.enable = true;

  # sshd reachable only over the tailnet: Apple's sshd binary with the shared
  # /etc/ssh/sshd_config(.d) hardening (modules/darwin/security.nix), bound to
  # yoru's Tailscale address and nothing else. Until tailscaled brings that
  # address up, sshd exits with "Cannot bind any address" and launchd retries.
  # If yoru is re-registered and gets a new address, update it here.
  launchd.daemons.sshd-tailnet.serviceConfig = {
    ProgramArguments = [
      "/usr/sbin/sshd"
      "-D"
      "-o"
      "ListenAddress=${tailnetAddress}"
    ];
    RunAtLoad = true;
    KeepAlive = true;
    ThrottleInterval = 30;
    StandardErrorPath = "/var/log/sshd-tailnet.log";
  };

  users.users.${identity.user.name} = {
    name = identity.user.name;
    home = identity.homeDirectory;
    shell = pkgs.zsh;
  };

  programs.zsh.enable = true;
}
