{
  config,
  lib,
  vars,
  ...
}:

let
  container = vars.containers.asciiWebserver;
  containerName = container.name;
in
{
  sops.secrets."caddy_env".restartUnits = [ "container@${containerName}.service" ];

  containers.${containerName} = {
    autoStart = true;
    privateNetwork = true;
    hostBridge = vars.network.bridge;
    localAddress = container.cidr;

    bindMounts = {
      "/srv/ascii/ascii.txt" = {
        hostPath = "${vars.paths.repo}/modules/containers/ascii-webserver/ascii.txt";
        isReadOnly = true;
      };
      "${config.sops.secrets."caddy_env".path}" = {
        hostPath = config.sops.secrets."caddy_env".path;
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
          defaultGateway = vars.network.gateway;
          useHostResolvConf = lib.mkForce false;
          nameservers = vars.network.containerNameservers;
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
          environmentFile = config.sops.secrets."caddy_env".path;
          virtualHosts."{$DOMAIN}" = {
            extraConfig = ''
              @cli header_regexp User-Agent (?i)(curl|wget)

              redir /jellyfin /jellyfin/ 308

              handle /jellyfin/* {
                reverse_proxy ${vars.network.hostAddress}:8096
              }

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

        system.stateVersion = vars.host.stateVersion;
      };
  };
}
