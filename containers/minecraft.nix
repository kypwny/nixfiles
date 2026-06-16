{ pkgs, nix-minecraft, ... }:

let
  containerName = "minecraft";
  fabricServerDir = "/opt/fabric-server";
in
{
  containers.${containerName} = {
    autoStart = true;
    privateNetwork = true;
    hostBridge = "br0";
    localAddress = "192.168.1.54/24";

    # nix-minecraft places per-server data under dataDir/<serverName>,
    # so mount the host directory at the server subdirectory.
    bindMounts."${fabricServerDir}/fabric" = {
      hostPath = "/home/ky/minecraft/fabric-server";
      isReadOnly = false;
    };

    config =
      { pkgs, ... }:
      {
        imports = [ nix-minecraft.nixosModules.minecraft-servers ];
        nixpkgs.overlays = [ nix-minecraft.overlay ];
        nixpkgs.config.allowUnfree = true;

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

        services.minecraft-servers = {
          enable = true;
          eula = true;
          dataDir = fabricServerDir;
          openFirewall = false;

          servers.fabric = {
            enable = true;
            package = pkgs.fabricServers.fabric-1_21_5;
            jvmOpts = "-Xms3072M -Xmx3072M -XX:+AlwaysPreTouch -XX:+DisableExplicitGC -XX:+ParallelRefProcEnabled -XX:+PerfDisableSharedMem -XX:+UnlockExperimentalVMOptions -XX:+UseG1GC -XX:G1HeapRegionSize=8M -XX:G1HeapWastePercent=5 -XX:G1MaxNewSizePercent=40 -XX:G1MixedGCCountTarget=4 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1NewSizePercent=30 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:G1ReservePercent=20 -XX:InitiatingHeapOccupancyPercent=15 -XX:MaxGCPauseMillis=200 -XX:MaxTenuringThreshold=1 -XX:SurvivorRatio=32 -Dusing.aikars.flags=https://mcflags.emc.gs -Daikars.new.flags=true -Djava.io.tmpdir=${fabricServerDir}/.java-tmp";

            extraStartPost = ''
              file=${fabricServerDir}/config/voicechat/voicechat-server.properties
              if [ -f "$file" ]; then
                ${pkgs.gnused}/bin/sed -i 's/^bind_address=.*/bind_address=192.168.1.54/' "$file"
              fi
            '';
          };
        };

        systemd.tmpfiles.rules = [
          "d ${fabricServerDir}/.java-tmp 0700 minecraft minecraft -"
        ];
      };
  };
}
