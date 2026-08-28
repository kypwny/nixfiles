{
  config,
  lib,
  pkgs,
  ...
}:

let
  ignoredHostServiceNames = [
    "NetworkManager"
    "NetworkManager-dispatcher"
    "NetworkManager-ensure-profiles"
    "linger-users"
    "logrotate-checkconf"
    "mandb"
    "nscd"
    "post-boot"
    "reload-systemd-vconsole-setup"
    "resolvconf"
    "sshd-keygen"
    "systemd-modules-load"
    "systemd-oomd"
    "systemd-sysctl"
    "wpa_supplicant"
  ];

  ignoredHostServicePrefixes = [
    "container@"
    "systemd-"
  ];

  hostServiceLabelOverrides = {
    jellyfin = "Jellyfin";
    sshd = "SSH";
  };

  isMotdHostService =
    name: service:
    service.enable
    && builtins.elem "multi-user.target" service.wantedBy
    && !(builtins.elem name ignoredHostServiceNames)
    && !(lib.any (prefix: lib.hasPrefix prefix name) ignoredHostServicePrefixes)
    && !(lib.hasInfix "@" name);

  hostServices =
    map
      (name: {
        label = hostServiceLabelOverrides.${name} or name;
        unit = "${name}.service";
      })
      (
        builtins.filter (name: isMotdHostService name config.systemd.services.${name}) (
          lib.attrNames config.systemd.services
        )
      );

  containerServices = map (name: {
    label = name;
    unit = "container@${name}.service";
  }) (lib.attrNames config.containers);

  mkServiceFile =
    name: services:
    pkgs.writeText name (
      lib.concatMapStringsSep "\n" (service: "${service.label}|${service.unit}") services + "\n"
    );

  hostServiceFile = mkServiceFile "snowbox-motd-host-services" hostServices;
  containerServiceFile = mkServiceFile "snowbox-motd-containers" containerServices;

  snowboxMotd = pkgs.writeShellApplication {
    name = "snowbox-motd";

    runtimeInputs = with pkgs; [
      coreutils
      gawk
      gnused
      procps
      systemd
      toilet
    ];

    text = ''
      if [[ ! -t 1 ]]; then
        exit 0
      fi

      readonly host_name=${lib.escapeShellArg config.networking.hostName}
      readonly os_label=${lib.escapeShellArg "NixOS ${config.system.nixos.label}"}

      if [[ -n "''${NO_COLOR:-}" || "''${TERM:-}" == "dumb" ]]; then
        reset=""
        bold=""
        red=""
        green=""
        yellow=""
        blue=""
        cyan=""
      else
        reset=$'\033[0m'
        bold=$'\033[1m'
        red=$'\033[31m'
        green=$'\033[32m'
        yellow=$'\033[33m'
        blue=$'\033[34m'
        cyan=$'\033[36m'
      fi

      kv() {
        local label="$1"
        local value="$2"
        printf "  %b%-12s%b %s\n" "$cyan" "$label" "$reset" "$value"
      }

      section() {
        printf "\n%b%s%b\n" "$bold$blue" "$1" "$reset"
      }

      meminfo_kib() {
        local key="$1:"
        awk -v key="$key" '$1 == key { print $2; found = 1; exit } END { if (!found) print 0 }' /proc/meminfo
      }

      human_kib() {
        awk -v kib="$1" 'BEGIN {
          if (kib >= 1048576) {
            printf "%.1f GiB", kib / 1048576
          } else if (kib >= 1024) {
            printf "%.0f MiB", kib / 1024
          } else {
            printf "%d KiB", kib
          }
        }'
      }

      percent_used() {
        awk -v used="$1" -v total="$2" 'BEGIN {
          if (total > 0) {
            printf "%.0f", used * 100 / total
          } else {
            printf "0"
          }
        }'
      }
      format_uptime() {
        awk 'BEGIN {
          if ((getline < "/proc/uptime") <= 0) {
            print "unknown"
            exit
          }

          total = int($1)
          days = int(total / 86400)
          hours = int((total % 86400) / 3600)
          minutes = int((total % 3600) / 60)

          if (days > 0) {
            printf "%dd", days
            if (hours > 0) {
              printf " %dh", hours
            }
          } else if (hours > 0) {
            printf "%dh", hours
            if (minutes > 0) {
              printf " %dm", minutes
            }
          } else {
            printf "%dm", minutes
          }
        }'
      }


      mem_bar() {
        local used_kib="$1"
        local total_kib="$2"
        local percent
        local filled
        local empty
        local filled_bar
        local empty_bar
        local used_human
        local total_human

        if [[ "$total_kib" -le 0 ]]; then
          kv "Mem" "unknown"
          return
        fi

        percent="$(percent_used "$used_kib" "$total_kib")"
        filled=$((used_kib * 20 / total_kib))
        if [[ "$filled" -gt 20 ]]; then
          filled=20
        fi
        empty=$((20 - filled))
        printf -v filled_bar '%*s' "$filled" ""
        printf -v empty_bar '%*s' "$empty" ""
        filled_bar="''${filled_bar// /█}"
        empty_bar="''${empty_bar// /░}"
        used_human="$(human_kib "$used_kib")"
        total_human="$(human_kib "$total_kib")"
        printf "  %b%-12s%b [%s%s %3s%%]  %s/%s\n" "$cyan" "Mem" "$reset" "$filled_bar" "$empty_bar" "$percent" "$used_human" "$total_human"
      }

      unit_state() {
        local unit="$1"
        local state
        state="$(systemctl is-active "$unit" 2>/dev/null || true)"
        if [[ -z "$state" ]]; then
          state="unknown"
        fi
        printf "%s" "$state"
      }

      status_color() {
        case "$1" in
          active)
            printf "%s" "$green"
            ;;
          failed)
            printf "%s" "$red"
            ;;
          *)
            printf "%s" "$yellow"
            ;;
        esac
      }

      status_line() {
        local label="$1"
        local unit="$2"
        local state
        local color
        state="$(unit_state "$unit")"
        color="$(status_color "$state")"
        printf "  %-20s %b%s%b\n" "$label" "$color" "$state" "$reset"
      }

      unit_counts() {
        local file="$1"
        local label
        local unit
        local total=0
        local active=0

        while IFS='|' read -r label unit; do
          if [[ -z "$label" || -z "$unit" ]]; then
            continue
          fi
          total=$((total + 1))
          if [[ "$(unit_state "$unit")" == "active" ]]; then
            active=$((active + 1))
          fi
        done < "$file"

        printf "%s %s" "$active" "$total"
      }

      show_units() {
        local file="$1"
        local label
        local unit

        while IFS='|' read -r label unit; do
          if [[ -z "$label" || -z "$unit" ]]; then
            continue
          fi
          status_line "$label" "$unit"
        done < "$file"
      }

      now="$(date "+%a %b %d %H:%M %Z" 2>/dev/null || true)"
      if [[ -z "$now" ]]; then
        now="unknown time"
      fi

      kernel_label="$(uname -sr 2>/dev/null || true)"
      if [[ -z "$kernel_label" ]]; then
        kernel_label="unknown kernel"
      fi

      uptime_text="$(format_uptime)"
      if [[ -z "$uptime_text" ]]; then
        uptime_text="unknown"
      fi

      load1="unknown"
      load5="unknown"
      load15="unknown"
      if read -r load1 load5 load15 _ < /proc/loadavg; then
        :
      fi
      lan_ip="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
      last_login=""
      if [[ -n "''${USER:-}" ]]; then
        last_login_line=""
        if command -v lastlog2 >/dev/null 2>&1; then
          last_login_line="$(lastlog2 -u "$USER" 2>/dev/null | awk 'NR == 2 { print; exit }' || true)"
        elif command -v lastlog >/dev/null 2>&1; then
          last_login_line="$(lastlog -u "$USER" 2>/dev/null | awk 'NR == 2 { print; exit }' || true)"
        fi

        if [[ -n "$last_login_line" && "$last_login_line" != *"**Never logged in**"* ]]; then
          last_login_parts="$(printf "%s\n" "$last_login_line" | awk '{
            first_day = 0
            for (i = 3; i <= NF; i++) {
              if ($i ~ /^(Mon|Tue|Wed|Thu|Fri|Sat|Sun)$/) {
                first_day = i
                break
              }
            }
            if (first_day == 0) {
              exit
            }
            from = ""
            for (i = 3; i < first_day; i++) {
              from = from (from ? " " : "") $i
            }
            when = ""
            for (i = first_day; i <= NF; i++) {
              when = when (when ? " " : "") $i
            }
            printf "%s\037%s\n", from, when
          }')"
          last_login_from="''${last_login_parts%%$'\037'*}"
          last_login_raw="''${last_login_parts#*$'\037'}"
          last_login_when="$(date -d "$last_login_raw" "+%a %b %d %H:%M" 2>/dev/null || true)"
          if [[ -n "$last_login_when" ]]; then
            if [[ -n "$last_login_from" ]]; then
              last_login="Last login: $last_login_when from $last_login_from"
            else
              last_login="Last login: $last_login_when"
            fi
          fi
        fi
      fi

      mem_total="$(meminfo_kib MemTotal)"
      mem_available="$(meminfo_kib MemAvailable)"
      mem_used=$((mem_total - mem_available))

      swap_total="$(meminfo_kib SwapTotal)"
      swap_free="$(meminfo_kib SwapFree)"
      swap_used=$((swap_total - swap_free))
      if [[ "$swap_total" -gt 0 ]]; then
        swap="$(human_kib "$swap_used") / $(human_kib "$swap_total") ($(percent_used "$swap_used" "$swap_total")%)"
      else
        swap="disabled"
      fi

      root_usage="$(df -h -P / | awk 'NR == 2 { print $3 "/" $2 " (" $5 ")" }' || true)"
      if [[ -z "$root_usage" ]]; then
        root_usage="unknown"
      fi

      banner="$(toilet -f mono9 "$host_name" 2>/dev/null || true)"
      if [[ -n "$banner" ]]; then
        printf "%b%s%b\n" "$bold$blue" "$banner" "$reset"
      else
        printf "%b%s%b\n" "$bold$blue" "$host_name" "$reset"
      fi

      printf "%b%s%b · %s · %s\n" "$bold" "$os_label" "$reset" "$kernel_label" "$now"
      if [[ -n "$lan_ip" ]]; then
        printf "%b%s%b · %s · up %s · load %s %s %s\n" "$bold" "$host_name" "$reset" "$lan_ip" "$uptime_text" "$load1" "$load5" "$load15"
      else
        printf "%b%s%b · up %s · load %s %s %s\n" "$bold" "$host_name" "$reset" "$uptime_text" "$load1" "$load5" "$load15"
      fi
      if [[ -n "$last_login" ]]; then
        printf "%s\n" "$last_login"
      fi

      section "Resources"
      mem_bar "$mem_used" "$mem_total"
      kv "Swap" "$swap"
      kv "Root" "$root_usage"

      read -r host_active host_total <<< "$(unit_counts ${hostServiceFile})"
      section "Host Services ($host_active/$host_total up)"
      show_units ${hostServiceFile}

      read -r container_active container_total <<< "$(unit_counts ${containerServiceFile})"
      section "Containers ($container_active/$container_total up)"
      show_units ${containerServiceFile}

      printf "\n"
    '';
  };

  posixLoginHook = ''
    case "$-" in
      *i*)
        if [ -t 1 ] && [ -z "''${SNOWBOX_MOTD_SHOWN:-}" ]; then
          export SNOWBOX_MOTD_SHOWN=1
          ${lib.getExe snowboxMotd}
        fi
        ;;
    esac
  '';
in
{
  programs.rust-motd.enable = false;

  # The custom MOTD is printed by login-shell hooks, not PAM/sshd's motd path.
  security.pam.services.sshd.showMotd = lib.mkForce false;
  services.openssh.settings.PrintMotd = lib.mkForce false;

  environment.systemPackages = [
    snowboxMotd
  ];

  programs.bash.loginShellInit = posixLoginHook;
  programs.zsh.loginShellInit = ''
    if [[ -o interactive && -t 1 && -z "''${SNOWBOX_MOTD_SHOWN:-}" ]]; then
      export SNOWBOX_MOTD_SHOWN=1
      ${lib.getExe snowboxMotd}
    fi
  '';
  programs.fish.loginShellInit = ''
    if status is-interactive; and test -t 1; and not set -q SNOWBOX_MOTD_SHOWN
      set -gx SNOWBOX_MOTD_SHOWN 1
      ${lib.getExe snowboxMotd}
    end
  '';
}
