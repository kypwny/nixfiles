{ lib, ... }:

let
  containerName = "eepsite";
in
{
  systemd.tmpfiles.rules = [
    "z /home/ky/webserver/kypwny.dat 0600 ky users - -"
    "z /home/ky/webserver/wireguard/wg0.conf 0600 ky users - -"
  ];

  containers.${containerName} = {
    autoStart = true;
    privateNetwork = true;
    hostBridge = "br0";
    localAddress = "192.168.1.51/24";
    enableTun = true;

    bindMounts = {
      "/run/secrets/kypwny.dat" = {
        hostPath = "/home/ky/webserver/kypwny.dat";
        isReadOnly = true;
      };
      "/run/secrets/wg0.conf" = {
        hostPath = "/home/ky/webserver/wireguard/wg0.conf";
        isReadOnly = true;
      };
      "/srv/www/kypwny" = {
        hostPath = "/home/ky/webroot/dist";
        isReadOnly = true;
      };
    };

    config =
      { pkgs, ... }:
      {
        networking = {
          hostName = containerName;
          enableIPv6 = true;
          defaultGateway = "192.168.1.1";
          useHostResolvConf = lib.mkForce false;
          nameservers = [
            "1.1.1.1"
            "9.9.9.9"
          ];

          wg-quick.interfaces.wg0.configFile = "/run/secrets/wg0.conf";

          firewall = {
            enable = true;
            interfaces.eth0.allowedTCPPorts = [
              4444
              4447
            ];
            interfaces.wg0.allowedTCPPorts = [ 3333 ];
          };
        };

        services.yggdrasil = {
          enable = true;
          persistentKeys = true;
          settings = {
            Peers = [
              "tls://ygg-dc.lxak.net:8880"
              "tls://ygg4.mk16.de:1338?key=000000573433e11f23768b078bcdc10b42712a7b131d6d04b82042ffc0c97df0"
            ];
            Listen = [ ];
          };
        };

        services.yggdrasil-jumper.enable = true;

        services.nginx = {
          enable = true;
          serverTokens = false;

          appendHttpConfig = ''
            set_real_ip_from 10.200.200.1;
            real_ip_header X-Forwarded-For;
            real_ip_recursive on;

            map $http_user_agent $is_cli {
              default 0;
              "~*^curl/" 1;
              "~*^Wget" 1;
            }
          '';

          virtualHosts.kypwny = {
            default = true;
            serverName = "_";
            root = "/srv/www/kypwny";
            listen = [
              {
                addr = "0.0.0.0";
                port = 3333;
              }
            ];

            locations = {
              "= /curl" = {
                alias = "/srv/www/kypwny/curl";
                extraConfig = ''
                  default_type text/plain;
                  add_header Content-Type "text/plain; charset=utf-8";
                '';
              };
              "= /" = {
                tryFiles = "$uri $uri/ =404";
                extraConfig = ''
                  if ($is_cli) {
                    rewrite ^ /curl last;
                  }
                  ssi on;
                '';
              };
              "/" = {
                tryFiles = "$uri $uri/ =404";
              };
            };
          };
        };

        services.i2pd = {
          enable = true;
          logLevel = "warn";
          notransit = true;
          precomputation.elgamal = false;
          yggdrasil.enable = true;

          proto = {
            http.enable = false;
            httpProxy = {
              enable = true;
              address = "0.0.0.0";
              port = 4444;
            };
            socksProxy = {
              enable = true;
              address = "0.0.0.0";
              port = 4447;
            };
          };

          inTunnels.kypwny = {
            type = "http";
            address = "127.0.0.1";
            port = 3333;
            inPort = 80;
            keys = "kypwny.dat";
          };
        };

        systemd.services = {
          install-kypwny-i2p-key = {
            description = "Install the kypwny I2P destination key";
            requiredBy = [ "i2pd.service" ];
            before = [ "i2pd.service" ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
            };
            script = ''
              ${pkgs.coreutils}/bin/install \
                --owner=i2pd --group=i2pd --mode=0600 \
                /run/secrets/kypwny.dat /var/lib/i2pd/kypwny.dat
            '';
          };

          i2pd.after = [
            "network-online.target"
            "wg-quick-wg0.service"
            "yggdrasil.service"
          ];
          i2pd.wants = [
            "network-online.target"
            "wg-quick-wg0.service"
            "yggdrasil.service"
          ];
        };

        system.stateVersion = "26.05";
      };
  };
}
