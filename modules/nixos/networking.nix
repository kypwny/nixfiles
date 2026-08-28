{ vars, ... }:
let
  inherit (vars) network;
in
{
  networking.hostName = vars.host.name;

  networking.networkmanager = {
    enable = true;

    # Put the host and bridged NixOS containers directly on the LAN.
    ensureProfiles.profiles = {
      "${network.bridge}" = {
        connection = {
          id = network.bridge;
          type = "bridge";
          interface-name = network.bridge;
          autoconnect = true;
          autoconnect-priority = 100;
        };
        bridge.stp = false;
        ipv4 = {
          method = "manual";
          address1 = network.hostCidr;
          inherit (network) gateway;
          dns = network.hostDns;
        };
        ipv6.method = "auto";
      };

      "${network.bridge}-${network.primaryInterface}" = {
        connection = {
          id = "${network.bridge}-${network.primaryInterface}";
          type = "ethernet";
          interface-name = network.primaryInterface;
          controller = network.bridge;
          port-type = "bridge";
          autoconnect = true;
          autoconnect-priority = 100;
        };
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ 22 ];
}
