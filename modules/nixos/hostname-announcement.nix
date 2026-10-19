{ lib, vars, ... }:
let
  network = vars.network or { };
in
{
  # Shared by physical hosts and guests: publish <hostname>.local on each
  # attached LAN, without reflecting discovery between networks.
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
    allowInterfaces =
      if network ? bridge then
        [ network.bridge ] ++ lib.optional (network ? wifiInterface) network.wifiInterface
      else
        null;
    denyInterfaces = [ "tailscale0" ];
    publish = {
      enable = true;
      addresses = true;
    };
  };
}
