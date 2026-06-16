{ lib, ... }:

let
  containerName = "ascii";
in
{
  containers.${containerName} = {
    autoStart = true;
    privateNetwork = true;
    hostBridge = "br0";
    localAddress = "192.168.1.53/24";

    bindMounts = {
      "/srv/ascii.txt" = {
        hostPath = "/home/ky/nixos-config/ascii.txt";
        isReadOnly = true;
      };
      "/run/secrets/caddy_env" = {
        hostPath = "/run/secrets/caddy_env";
        isReadOnly = true;
      };
    };

    config =
      { pkgs, ... }:
      {
        networking = {
          hostName = containerName;
          defaultGateway = "192.168.1.1";
          useHostResolvConf = lib.mkForce false;
          nameservers = [
            "1.1.1.1"
            "9.9.9.9"
          ];
          firewall = {
            enable = true;
            allowedTCPPorts = [
              80
              443
            ];
          };
        };

        services.caddy = {
          enable = true;
          environmentFile = "/run/secrets/caddy_env";
          virtualHosts."{$DOMAIN}" = {
            extraConfig = ''
              root * /srv
              rewrite / /ascii.txt
              header Content-Type "text/plain; charset=utf-8"
              file_server
            '';
          };
        };

        system.stateVersion = "26.05";
      };
  };
}
