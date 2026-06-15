{ pkgs, ... }:

let
  containerName = "minecraft";
  fabricServerDir = "/opt/fabric-server";

  minecraftWrapper = pkgs.writeShellScriptBin "minecraft-server" ''
    exec ${pkgs.jdk21_headless}/bin/java "$@" -jar server.jar --nogui
  '';
in
{
  containers.${containerName} = {
    autoStart = true;
    privateNetwork = true;
    hostBridge = "br0";
    localAddress = "192.168.1.54/24";

    bindMounts.${fabricServerDir} = {
      hostPath = "/home/ky/minecraft/fabric-server";
      isReadOnly = false;
    };

    config =
      { pkgs, ... }:
      {
        users.users.minecraft = {
          isSystemUser = true;
          uid = 1000;
          group = "minecraft";
          home = fabricServerDir;
          createHome = true;
        };
        users.groups.minecraft.gid = 1000;

        networking = {
          hostName = containerName;
          defaultGateway = "192.168.1.1";
          useHostResolvConf = false;
          nameservers = [
            "1.1.1.1"
            "9.9.9.9"
          ];
          firewall = {
            enable = true;
            allowedTCPPorts = [ 25565 ];
            allowedUDPPorts = [ 24454 ];
          };
        };

        services.minecraft-server = {
          enable = true;
          eula = true;
          dataDir = fabricServerDir;
          package = minecraftWrapper;
          jvmOpts = "-Xms3072M -Xmx3072M -XX:+AlwaysPreTouch -XX:+DisableExplicitGC -XX:+ParallelRefProcEnabled -XX:+PerfDisableSharedMem -XX:+UnlockExperimentalVMOptions -XX:+UseG1GC -XX:G1HeapRegionSize=8M -XX:G1HeapWastePercent=5 -XX:G1MaxNewSizePercent=40 -XX:G1MixedGCCountTarget=4 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1NewSizePercent=30 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:G1ReservePercent=20 -XX:InitiatingHeapOccupancyPercent=15 -XX:MaxGCPauseMillis=200 -XX:MaxTenuringThreshold=1 -XX:SurvivorRatio=32 -Dusing.aikars.flags=https://mcflags.emc.gs -Daikars.new.flags=true -Djava.io.tmpdir=/opt/fabric-server/.java-tmp";
          openFirewall = false;
        };

        systemd.tmpfiles.rules = [
          "d /opt/fabric-server/.java-tmp 0700 minecraft minecraft -"
        ];

        systemd.services.fix-voicechat-bind-address = {
          description = "Fix Simple Voice Chat bind address";
          before = [ "minecraft-server.service" ];
          requiredBy = [ "minecraft-server.service" ];
          serviceConfig = {
            Type = "oneshot";
          };
          script = ''
            file=${fabricServerDir}/config/voicechat/voicechat-server.properties
            if [ -f "$file" ]; then
              ${pkgs.gnused}/bin/sed -i 's/^bind_address=.*/bind_address=192.168.1.54/' "$file"
            fi
          '';
        };
      };
  };
}
