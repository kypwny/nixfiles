{
  lib,
  pkgs,
  vars,
  ...
}:

let
  enableQbittorrent = false;
  container = vars.containers.qbittorrent;
  containerName = container.name;
  hostDataRoot = "/srv/qbittorrent-data";
  containerDataRoot = "/srv/qbittorrent";
  qbProfileDir = "${containerDataRoot}/profile";
  qbDataDir = "${containerDataRoot}/data";
  qbIncompleteDir = "${containerDataRoot}/incomplete";
  qbTorrentExportDir = "${containerDataRoot}/torrents";
  qbWebUiEnvPath = vars.paths.qbittorrentWebUiEnv;
  i2pSamAddress = "127.0.0.1";
  i2pSamPort = 7656;
  qbWebUiPort = 8080;
  containerUnit = "container@${containerName}.service";
  helperDescription = "LAN qBittorrent helper for ${vars.user.name}";

  qbittorrentHelper = pkgs.writeShellApplication {
    name = "qbittorrent";
    runtimeInputs = with pkgs; [
      coreutils
      systemd
      util-linux
    ];
    text = ''
      readonly app_name='qbittorrent'
      readonly placeholder_enabled='${if enableQbittorrent then "1" else "0"}'
      readonly host_data_root=${lib.escapeShellArg hostDataRoot}
      readonly container_name=${lib.escapeShellArg containerName}
      readonly container_unit=${lib.escapeShellArg containerUnit}
      readonly container_address=${lib.escapeShellArg container.address}
      readonly qb_webui_port='${toString qbWebUiPort}'
      readonly qb_webui_env_path=${lib.escapeShellArg qbWebUiEnvPath}
      readonly i2p_sam_address=${lib.escapeShellArg i2pSamAddress}
      readonly i2p_sam_port='${toString i2pSamPort}'
      readonly sudo_path='/run/wrappers/bin/sudo'

      usage() {
        cat <<EOF
      Usage: $app_name <help|status|start|stop>

      help    Show this help.
      status  Show the placeholder state and planned LAN container layout.
      start   Start the qBittorrent container when enabled.
      stop    Stop the qBittorrent container when enabled.
      EOF
      }

      require_root() {
        if [[ $EUID -eq 0 ]]; then
          return 0
        fi

        exec "$sudo_path" -- "$0" "$command"
      }

      require_enabled() {
        if [[ "$placeholder_enabled" == '1' ]]; then
          return 0
        fi

        printf 'placeholder is disabled in modules/containers/qbittorrent.nix (enableQbittorrent = false)\n' >&2
        exit 1
      }
      require_webui_env() {
        if [[ -f "$qb_webui_env_path" ]]; then
          return 0
        fi

        printf 'error: %s is not present\n' "$qb_webui_env_path" >&2
        return 1
      }

      show_layout() {
        printf 'placeholder: %s\n' "$([[ "$placeholder_enabled" == '1' ]] && printf enabled || printf disabled)"
        printf 'container: %s\n' "$container_name"
        printf 'LAN address: %s\n' "$container_address"
        printf 'host data root: %s\n' "$host_data_root"
        printf 'WebUI: http://%s:%s\n' "$container_address" "$qb_webui_port"
        printf 'WebUI credentials env: %s\n' "$qb_webui_env_path"
        printf 'Required env keys: WEBUI_USERNAME WEBUI_PASSWORD_PBKDF2\n'
        printf 'I2P SAM bridge: %s:%s\n' "$i2p_sam_address" "$i2p_sam_port"
      }

      show_units() {
        local state
        if systemctl cat "$container_unit" >/dev/null 2>&1; then
          state="$(systemctl is-active "$container_unit" 2>/dev/null || true)"
          printf '%s: %s\n' "$container_unit" "''${state:-inactive}"
        else
          printf '%s: not installed in current system\n' "$container_unit"
        fi
      }

      if [[ $# -ne 1 ]]; then
        usage >&2
        exit 64
      fi

      readonly command="$1"

      case "$command" in
        help|-h|--help)
          usage
          ;;
        status)
          show_layout
          if [[ -f "$qb_webui_env_path" ]]; then
            printf '%s is present\n' "$qb_webui_env_path"
          else
            printf '%s is not present\n' "$qb_webui_env_path"
          fi
          show_units
          ;;
        start)
          require_enabled
          require_root
          require_webui_env
          systemctl start "$container_unit"
          show_layout
          show_units
          ;;
        stop)
          require_enabled
          require_root
          systemctl stop "$container_unit"
          show_units
          ;;
        *)
          usage >&2
          exit 64
          ;;
      esac
    '';
    meta.description = helperDescription;
  };

  mkQbittorrentContainer =
    {
      enable ? false,
    }:
    lib.mkIf enable {
      containers.${containerName} = {
        autoStart = false;
        privateNetwork = true;
        hostBridge = vars.network.bridge;
        localAddress = container.cidr;

        bindMounts = {
          "${containerDataRoot}" = {
            hostPath = hostDataRoot;
            isReadOnly = false;
          };
          "/run/secrets/qbittorrent-webui.env" = {
            hostPath = qbWebUiEnvPath;
            isReadOnly = true;
          };
        };

        config =
          { lib, pkgs, ... }:
          {
            networking = {
              hostName = containerName;
              defaultGateway = vars.network.gateway;
              useHostResolvConf = lib.mkForce false;
              nameservers = vars.network.containerNameservers;
              firewall = {
                enable = true;
                interfaces.eth0.allowedTCPPorts = [ qbWebUiPort ];
              };
            };

            services.i2pd = {
              enable = true;
              logLevel = "warn";
              notransit = true;
              precomputation.elgamal = false;

              proto = {
                http.enable = false;
                socksProxy.enable = false;
                sam = {
                  enable = true;
                  address = i2pSamAddress;
                  port = i2pSamPort;
                };
              };
            };

            services.qbittorrent = {
              enable = true;
              package = pkgs.qbittorrent-nox;
              openFirewall = false;
              webuiPort = qbWebUiPort;
              profileDir = qbProfileDir;
              extraArgs = [ "--confirm-legal-notice" ];
            };

            systemd.services = {
              i2pd.wantedBy = lib.mkForce [ ];

              install-qbittorrent-config = {
                description = "Install qBittorrent configuration";
                requiredBy = [ "qbittorrent.service" ];
                before = [ "qbittorrent.service" ];
                unitConfig.ConditionPathExists = "/run/secrets/qbittorrent-webui.env";
                serviceConfig = {
                  Type = "oneshot";
                  RemainAfterExit = true;
                  EnvironmentFile = "/run/secrets/qbittorrent-webui.env";
                };
                script = ''
                  ${pkgs.coreutils}/bin/install -d -o qbittorrent -g qbittorrent -m 0750 ${lib.escapeShellArg containerDataRoot}
                  ${pkgs.coreutils}/bin/install -d -o qbittorrent -g qbittorrent -m 0750 ${lib.escapeShellArg qbProfileDir}
                  ${pkgs.coreutils}/bin/install -d -o qbittorrent -g qbittorrent -m 0750 ${lib.escapeShellArg "${qbProfileDir}/qBittorrent"}
                  ${pkgs.coreutils}/bin/install -d -o qbittorrent -g qbittorrent -m 0750 ${lib.escapeShellArg "${qbProfileDir}/qBittorrent/config"}
                  ${pkgs.coreutils}/bin/install -d -o qbittorrent -g qbittorrent -m 0750 ${lib.escapeShellArg qbDataDir}
                  ${pkgs.coreutils}/bin/install -d -o qbittorrent -g qbittorrent -m 0750 ${lib.escapeShellArg qbIncompleteDir}
                  ${pkgs.coreutils}/bin/install -d -o qbittorrent -g qbittorrent -m 0750 ${lib.escapeShellArg qbTorrentExportDir}
                  cat > ${lib.escapeShellArg "${qbProfileDir}/qBittorrent/config/qBittorrent.conf"} <<EOF
                  [BitTorrent]
                  Session\\AnonymousModeEnabled=true
                  Session\\DHTEnabled=false
                  Session\\DefaultSavePath=${qbDataDir}
                  Session\\FinishedTorrentExportDirectory=${qbTorrentExportDir}
                  Session\\I2P\\Address=${i2pSamAddress}
                  Session\\I2P\\Enabled=true
                  Session\\I2P\\InboundLength=3
                  Session\\I2P\\InboundQuantity=3
                  Session\\I2P\\MixedMode=false
                  Session\\I2P\\OutboundLength=3
                  Session\\I2P\\OutboundQuantity=3
                  Session\\I2P\\Port=${toString i2pSamPort}
                  Session\\LSDEnabled=false
                  Session\\PeXEnabled=false
                  Session\\TempPath=${qbIncompleteDir}
                  Session\\TempPathEnabled=true
                  Session\\TorrentExportDirectory=${qbTorrentExportDir}

                  [LegalNotice]
                  Accepted=true

                  [Preferences]
                  WebUI\\Address=${container.address}
                  WebUI\\LocalHostAuth=true
                  WebUI\\Password_PBKDF2=$WEBUI_PASSWORD_PBKDF2
                  WebUI\\Username=$WEBUI_USERNAME
                  EOF
                  ${pkgs.coreutils}/bin/chown qbittorrent:qbittorrent ${lib.escapeShellArg "${qbProfileDir}/qBittorrent/config/qBittorrent.conf"}
                  ${pkgs.coreutils}/bin/chmod 0600 ${lib.escapeShellArg "${qbProfileDir}/qBittorrent/config/qBittorrent.conf"}
                '';
              };

              qbittorrent = {
                wantedBy = lib.mkForce [ ];
                wants = [
                  "i2pd.service"
                  "install-qbittorrent-config.service"
                ];
                after = [
                  "i2pd.service"
                  "install-qbittorrent-config.service"
                ];
              };
            };

            system.stateVersion = vars.host.stateVersion;
          };
      };

      systemd.services.prepare-qbittorrent-host-layout = {
        description = "Prepare qBittorrent host data directory";
        requiredBy = [ containerUnit ];
        before = [ containerUnit ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          ${pkgs.coreutils}/bin/install -d -m 0750 ${lib.escapeShellArg hostDataRoot}
        '';
      };

      systemd.services."${containerUnit}" = {
        wantedBy = lib.mkForce [ ];
        wants = [
          "network-online.target"
          "prepare-qbittorrent-host-layout.service"
        ];
        after = [
          "network-online.target"
          "prepare-qbittorrent-host-layout.service"
        ];
        unitConfig.ConditionPathExists = qbWebUiEnvPath;
      };
    };
in
{
  config = lib.mkMerge [
    {
      environment.systemPackages = [ qbittorrentHelper ];
    }
    (mkQbittorrentContainer { enable = enableQbittorrent; })
  ];
}
