{ lib, ... }:

let
  containerName = "ascii-webserver";
in
{
  containers.${containerName} = {
    autoStart = true;
    privateNetwork = true;
    hostBridge = "br0";
    localAddress = "192.168.1.53/24";

    bindMounts = {
      "/srv/ascii/ascii.txt" = {
        hostPath = "/home/ky/nixos-config/webservers/ascii-webserver/ascii.txt";
        isReadOnly = true;
      };
      "/run/secrets/caddy_env" = {
        hostPath = "/run/secrets/caddy_env";
        isReadOnly = true;
      };
    };

    config =
      { pkgs, ... }:
      let
        asciiHtmlDir = pkgs.writeTextDir "ascii.html" (builtins.readFile ./ascii.html);
      in
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
              @cli header_regexp User-Agent (?i)(curl|wget)

              handle @cli {
                header Content-Type "text/plain; charset=utf-8"
                root * /srv
                rewrite * /ascii/ascii.txt
                file_server
              }

              handle {
                root * ${asciiHtmlDir}
                rewrite * /ascii.html
                file_server
              }
            '';
          };
        };

        system.stateVersion = "26.05";
      };
  };
}
