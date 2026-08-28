{
  lib,
  pkgs,
  nix-minecraft,
  vars,
  ...
}:

let
  container = vars.containers.minecraft;
  containerName = container.name;
  fabricServerDir = "/opt/fabric-server";
  mkModrinthMod =
    path: url: sha512:
    lib.nameValuePair path (
      pkgs.fetchurl {
        inherit url sha512;
      }
    );
  mkCurseForgeMod =
    path: fileId: name: hash:
    lib.nameValuePair path (
      pkgs.fetchurl {
        url =
          "https://mediafilez.forgecdn.net/files/"
          + "${builtins.substring 0 4 (toString fileId)}/"
          + "${builtins.substring 4 100 (toString fileId)}/"
          + "${name}";
        inherit hash;
      }
    );
  mc2discordConfig = pkgs.writeText "mc2discord.toml" ''
    [General]
    token = "@discord_token@"

    [Channels]
      [[Channels.Channel]]
      id = @discord_channel_id@
      subscriptions = ["info", "chat", "command"]
      mode = "WEBHOOK"

    [Commands]
    prefix = "!"
    use_codeblocks = true

    [Style]
    webhook_display_name = "''${player_display_name}"
    webhook_avatar_api = "https://mineskin.eu/helm/''${player_uuid}/100"
  '';
  modSymlinks = builtins.listToAttrs [
    (mkModrinthMod "mods/Clumps-fabric-1.21.5-23.0.0.1.jar"
      "https://cdn.modrinth.com/data/Wnxd13zP/versions/nH8YfRWs/Clumps-fabric-1.21.5-23.0.0.1.jar"
      "08b9e5c849162f5f076f33c117f39d0931afc04f475241f33e9fa9984b48c8383517e73aa51f55c22a98b4e7da27045a98fad8d4abc289278dc0e9b13accddc5"
    )
    (mkModrinthMod "mods/Explorify%20v1.6.4%20f15-88.mod.jar"
      "https://cdn.modrinth.com/data/HSfsxuTo/versions/9vHj342y/Explorify%20v1.6.4%20f15-88.mod.jar"
      "601ee61e3619ab6a929ff06e4e3db6cc480d97a19e5716ac40a2a325d2d609b857a1ac17f2c0ed2b242e662b5486f4e0f59584fbd47acd481b318c45c244254b"
    )
    (mkModrinthMod "mods/NoChatReports-FABRIC-1.21.5-v2.12.0.jar"
      "https://cdn.modrinth.com/data/qQyHxfxd/versions/CHlHxkvf/NoChatReports-FABRIC-1.21.5-v2.12.0.jar"
      "c0825db25672cf8b50face51ec8a6bedb4be50b374a2537640a433c98817bc07c177485e93ab8cee9e3f7bfb1d2eb1460309e818b411764c92426b552487a9f7"
    )
    (mkModrinthMod "mods/RoughlyEnoughItems-19.0.809-fabric.jar"
      "https://cdn.modrinth.com/data/nfn13YXA/versions/WAWJTRYA/RoughlyEnoughItems-19.0.809-fabric.jar"
      "d5378f18bdd49cbe94b1741a271aef2d3eb36ba5350404a6737b6864fbe205048a4e30b2468b63abaa25aead0c7548f349bc37f497aaa8a2e368fc4846b2b834"
    )
    (mkModrinthMod "mods/architectury-16.1.4-fabric.jar"
      "https://cdn.modrinth.com/data/lhGA9TYQ/versions/ImZUcNzP/architectury-16.1.4-fabric.jar"
      "2edf94af0b6fc9e72e91b4a094e7168b4c2fedbdc0c0713b01d817e4294e297a75fdd8cd89e6e50a9a559d7bf0ad75fcb93d35e1b0beb62c9d1d814f94b53cdf"
    )
    (mkModrinthMod "mods/cloth-config-18.0.145-fabric.jar"
      "https://cdn.modrinth.com/data/9s6osm5g/versions/qA00xo1O/cloth-config-18.0.145-fabric.jar"
      "2752215fdc303598f0e98208a3ddae404c413aa3de22f5e2db2f2cc2c7813f08a1731da6778a6b9056a6ebe3b74919fce67abd14332269ad0a353bdc6e9e92c4"
    )
    (mkModrinthMod "mods/cozys-improved-cats-1.3.0-1.21.5.jar"
      "https://cdn.modrinth.com/data/5MaZBjPT/versions/psn7p52g/cozys-improved-cats-1.3.0-1.21.5.jar"
      "fb5595afda82d724d8018c0ab29faf3f758948d1f1ecd94389dea10d20fccdc9147a3bd1f0b8a5d767bcd5c14d6f5cea159e3ea4ffd96cc4b83933000bc5cde1"
    )
    (mkModrinthMod "mods/cozys-improved-wolves-1.4.0-1.21.5.jar"
      "https://cdn.modrinth.com/data/N4PW8UQo/versions/WfwRhzgO/cozys-improved-wolves-1.4.0-1.21.5.jar"
      "9e51471e336649f885c0ba3e97d3d6a6c3a0943fe4660c51f1d73c081652cbd89e813323c4a3676ad18f8a9d63b2e9101fd8c70bfb42e6e2365cea21dcc09d29"
    )
    (mkModrinthMod "mods/ep-msg-encryption-fabric-2.1.0-1.21.4.jar"
      "https://cdn.modrinth.com/data/r0uqICtg/versions/6JwXeLYG/ep-msg-encryption-fabric-2.1.0-1.21.4.jar"
      "cdd7e92803bdcf0df1e92206de2abd70df2a679da54380b888b429a321fa1a2f491c3242a3084d08399270d6b839dfe37ce417ce8d4a9f0b6baf42c4775a7e68"
    )
    (mkModrinthMod "mods/cristellib-fabric-2.0.2.jar"
      "https://cdn.modrinth.com/data/cl223EMc/versions/waCffck8/cristellib-fabric-2.0.2.jar"
      "bdb3f5f9c0528be8324cc5fc3cf90c695c15df970654c55e88d25ef8d98b44cdc2870d88bc6b6b075f16b2b7179cc5d08c3d5eb95c7174b0091a81074e09e757"
    )
    (mkModrinthMod "mods/fabric-api-0.128.2%2B1.21.5.jar"
      "https://cdn.modrinth.com/data/P7dR8mSH/versions/kKEGlsne/fabric-api-0.128.2%2B1.21.5.jar"
      "0e42b72d1a63a45c1b64cdabafd15f4d236bbda5521964d687afa1f833d4022f96c7ffab5dd4471aba0190be588f092d156bf14a50b794895fb3286ec899bcf7"
    )
    (mkModrinthMod "mods/fabric-language-kotlin-1.13.3%2Bkotlin.2.1.21.jar"
      "https://cdn.modrinth.com/data/Ha28R6CL/versions/iqWDz8qt/fabric-language-kotlin-1.13.3%2Bkotlin.2.1.21.jar"
      "805eb96067560fa8acc8fcc7dbfba4ad8eed1a2bc9b46566e184f122533fdff844288f3df635762e1af927a4efe8989e9f11007a24bcdc73a32fc2dbebd720c3"
    )
    (mkModrinthMod "mods/ferritecore-8.0.4-fabric.jar"
      "https://cdn.modrinth.com/data/uXXizFIs/versions/LdlksamY/ferritecore-8.0.4-fabric.jar"
      "8be6c49aa5900f434c082f505a48cf6bafc70bb43e9b9d4e0e42524605d2d22f968bc3a0c0048190a5296fd3cc696d8c3a7329dc8a022792f920e83ece47e5b6"
    )
    (mkModrinthMod "mods/jamlib-fabric-1.3.5%2B1.21.5.jar"
      "https://cdn.modrinth.com/data/IYY9Siz8/versions/MrRqh8ql/jamlib-fabric-1.3.5%2B1.21.5.jar"
      "74536d9f7eefa43d22d9737153548003c2b1d9dbbb9180490162336f3b68b273104f77241680f7f9a32808577abd87cbd2c53d3ea4a011ab6f928b3cb53acdd6"
    )
    (mkModrinthMod "mods/krypton-0.2.9.jar"
      "https://cdn.modrinth.com/data/fQEb0iXm/versions/neW85eWt/krypton-0.2.9.jar"
      "2e2304b1b17ecf95783aee92e26e54c9bfad325c7dfcd14deebf9891266eb2933db00ff77885caa083faa96f09c551eb56f93cf73b357789cb31edad4939ffeb"
    )
    (mkModrinthMod "mods/lithium-fabric-0.16.3%2Bmc1.21.5.jar"
      "https://cdn.modrinth.com/data/gvQqBUqZ/versions/xcELvp6R/lithium-fabric-0.16.3%2Bmc1.21.5.jar"
      "42d1538caa913bb35e76208efc14bce3e89fb01e8dbd7cf2a3b8576377d83d2d2f63a207cb7b6f081e20b00e5edff8d01e94a52d89e8c9ce9e3dfecc3fac4d78"
    )
    (mkModrinthMod "mods/mcw-doors-1.1.2-mc1.21.5fabric.jar"
      "https://cdn.modrinth.com/data/kNxa8z3e/versions/oz3NiZfi/mcw-doors-1.1.2-mc1.21.5fabric.jar"
      "71551afdea76f1269c0446f9ee60e4d298d0a15598b2ac4d0d13616646ff730fbd4dd3540315b8ee7f513df9d4258299c1d6577f3a9d43d5485855f94a490721"
    )
    (mkModrinthMod "mods/mcw-lights-1.1.5-mc1.21.5fabric.jar"
      "https://cdn.modrinth.com/data/w4an97C2/versions/HKfrvkA2/mcw-lights-1.1.5-mc1.21.5fabric.jar"
      "8072dd99d05968d9d89cfebe130c8fef0484c85c850bb28b3928b3d14df4296e174d79ea8ef051f5c67fefb4300ac593c8e18667143d0f7fc1fe5c57e65dd814"
    )
    (mkModrinthMod "mods/mcw-mcwwindows-2.4.2-mc1.21.5fabric.jar"
      "https://cdn.modrinth.com/data/C7I0BCni/versions/ijF1Ynpt/mcw-mcwwindows-2.4.2-mc1.21.5fabric.jar"
      "09abd704e90e9fdc5d340319d61c7a1af2f681d14d66683863a15f8b1dd91d58e42fcb6129fbdc1a9d0a8528263d49db02b5d41cb723c19dde5db6242a23b0a5"
    )
    (mkModrinthMod "mods/mcw-trapdoors-1.1.5-mc1.21.5fabric.jar"
      "https://cdn.modrinth.com/data/n2fvCDlM/versions/ZHEGOd6E/mcw-trapdoors-1.1.5-mc1.21.5fabric.jar"
      "be95fba7f2b4780e57684cde5dba6790dda07d39a0093559a39fc30abd172002f9aaafd966e2c8ae5b01caf66a06821bb29701ef03f05c394c717d8fb8a17147"
    )
    (mkModrinthMod "mods/radio-2.0+1.21.5.fabric.jar"
      "https://cdn.modrinth.com/data/Ab2GBNpI/versions/AgvGcf5l/radio-2.0%2B1.21.5.fabric.jar"
      "ad7e3d47de24dc9bb5904105a810688b4eef1fe0b70f3564a13e0f053402190c9f9fd6c0a96e67802bd2d39220fb4f6938357bf2bed85c3bb53c0e040d8adea3"
    )
    (mkModrinthMod "mods/rightclickharvest-fabric-4.6.0%2B1.21.5.jar"
      "https://cdn.modrinth.com/data/Cnejf5xM/versions/3vRrVKTA/rightclickharvest-fabric-4.6.0%2B1.21.5.jar"
      "03345fc3ce515e9cf7061388c1dd7b05c73634a98fc6b1d277c53448942e2f67a062b062d5956e914195828a7542817535d1af5ce692181fce03b4a366a89f8d"
    )
    (mkCurseForgeMod "mods/framework.jar" 6531441 "framework-fabric-1.21.5-0.11.5.jar"
      "sha256-P2pKOAxewmq6G6ihYWtNdUQVcOx3lKRyXlnImk8TPRM="
    )
    (mkModrinthMod "mods/mc2discord-fabric-1.21.5-4.2.6.jar"
      "https://cdn.modrinth.com/data/Cfbcv7uF/versions/1MS7WOKF/mc2discord-fabric-1.21.5-4.2.6.jar"
      "5e55be5ceb6affd56a3b0da1bfc7d429f9f7de41a326dc32c771eb51d8ccfeed001aa1d6a7fd3e2c9b696f07da816749c9295ea94a22a5597897760a49bcd775"
    )
    (mkCurseForgeMod "mods/refurbished_furniture-fabric-1.21.5-1.0.16.jar" 6623972
      "refurbished_furniture-fabric-1.21.5-1.0.16.jar"
      "sha256-+NjkDXPKjGalCbo/LC5Cnot6yyOKH4ijQ1Sl9DtNABU="
    )
    (mkModrinthMod "mods/tgbridge-0.9.5-fabric-obf.jar"
      "https://cdn.modrinth.com/data/QI59B2cO/versions/cbEcbBog/tgbridge-0.9.5-fabric-obf.jar"
      "64e67c9a7a1bae81c8ae9fc3601b8e907c6c946dc25a2e918e46d9426210a9a55a2ff09c29b2b7dd15de7900c27b89a5d98fd0bdfb128d875c91d49b5a3e345b"
    )
    (mkModrinthMod "mods/toomanypaintings-25.10.20-1.21.2-fabric.jar"
      "https://cdn.modrinth.com/data/T8Fpxcl7/versions/Tep6Op9S/toomanypaintings-25.10.20-1.21.2-fabric.jar"
      "321bd9a416b4758e073fb11caf9a691a59e15f6c0f363d6c9ebb9dfa4c998fb23ff2936886b4a021798a4a424eff76f4990e1447cedd199b1086b1dbd352cfa2"
    )
    (mkModrinthMod "mods/voicechat-fabric-1.21.5-2.6.11.jar"
      "https://cdn.modrinth.com/data/9eGKb6K1/versions/KvgDWblM/voicechat-fabric-1.21.5-2.6.11.jar"
      "1562c4f97e7b47d6a5a59604c6aa5abe1df0d00f50ca5e7f1068d1334558400c2f902df333c988db582c529a76ed631a2eb88aad8d6732ad11e8d2fd45c290ea"
    )
    (mkModrinthMod "mods/xaerominimap-fabric-1.21.5-25.3.5.jar"
      "https://cdn.modrinth.com/data/1bokaNcj/versions/taFSM8PW/xaerominimap-fabric-1.21.5-25.3.5.jar"
      "57c1835e0ef4c1820ee6e115e5d96ce4db74369510dd087a12f615c958b69fa36dc6c4711e63d7d036faa77fd8a853d6558fa655f2a24556b433a523fa4b1204"
    )
  ];
in
{
  containers.${containerName} = {
    autoStart = false;
    privateNetwork = true;
    hostBridge = vars.network.bridge;
    localAddress = container.cidr;

    # nix-minecraft places per-server data under dataDir/<serverName>,
    # so mount the host directory at the server subdirectory.
    bindMounts."${fabricServerDir}/fabric" = {
      hostPath = vars.paths.minecraftData;
      isReadOnly = false;
    };
    bindMounts."/srv/secrets" = {
      hostPath = vars.paths.minecraftSecrets;
      isReadOnly = true;
    };

    config =
      { pkgs, ... }:
      {
        imports = [ nix-minecraft.nixosModules.minecraft-servers ];
        nixpkgs.overlays = [ nix-minecraft.overlay ];
        nixpkgs.config.allowUnfree = true;

        networking = {
          hostName = containerName;
          defaultGateway = vars.network.gateway;
          useHostResolvConf = false;
          nameservers = vars.network.containerNameservers;
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
          environmentFile = "/srv/secrets/minecraft.env";
          openFirewall = false;

          servers.fabric = {
            enable = true;
            package = pkgs.fabricServers.fabric-1_21_5;
            # Most active server mods are pinned to exact upstream artifacts.
            # Framework and Refurbished Furniture are fetched from CurseForge
            # because the current Fabric 1.21.5 jars are not distributed on
            # Modrinth.
            symlinks = modSymlinks;
            whitelist = {
              Nameless = "5ac2f2cc-9138-41ff-a6cc-2fb55ed2ce68";
              MxEnder = "77402752-1b37-4ab9-b874-3edfb8341877";
            };
            files = {
              "config/mc2discord.toml" = mc2discordConfig;
              "config/voicechat/voicechat-server.properties".value = {
                bind_address = container.address;
              };
            };
            serverProperties = {
              accepts-transfers = false;
              allow-flight = false;
              allow-nether = true;
              broadcast-console-to-ops = true;
              broadcast-rcon-to-ops = true;
              bug-report-link = "";
              difficulty = "normal";
              enable-code-of-conduct = false;
              enable-command-block = false;
              enable-jmx-monitoring = false;
              enable-query = false;
              enable-rcon = false;
              enable-status = true;
              enforce-secure-profile = true;
              enforce-whitelist = false;
              entity-broadcast-range-percentage = 100;
              force-gamemode = false;
              function-permission-level = 2;
              gamemode = "survival";
              generate-structures = true;
              generator-settings = "{}";
              hardcore = false;
              hide-online-players = false;
              initial-disabled-packs = "";
              initial-enabled-packs = "vanilla";
              level-name = "world";
              level-seed = 46182117;
              level-type = "minecraft\\:normal";
              log-ips = true;
              max-chained-neighbor-updates = 1000000;
              max-players = 2;
              max-tick-time = 60000;
              max-world-size = 29999984;
              motd = "§f§kA Minecraft Server§r\\n§7§kHere is another line";
              network-compression-threshold = 256;
              online-mode = true;
              op-permission-level = 4;
              pause-when-empty-seconds = 60;
              player-idle-timeout = 0;
              prevent-proxy-connections = false;
              pvp = true;
              "query.port" = 25565;
              rate-limit = 0;
              "rcon.password" = "";
              "rcon.port" = 25575;
              region-file-compression = "deflate";
              require-resource-pack = false;
              resource-pack = "";
              resource-pack-id = "";
              resource-pack-prompt = "";
              resource-pack-sha1 = "";
              server-ip = container.address;
              server-port = 25565;
              simulation-distance = 10;
              spawn-monsters = true;
              spawn-protection = 0;
              status-heartbeat-interval = 0;
              sync-chunk-writes = true;
              text-filtering-config = "";
              text-filtering-version = 0;
              use-native-transport = true;
              view-distance = 10;
              white-list = true;
            };
            jvmOpts = "-Xms3072M -Xmx3072M -XX:+AlwaysPreTouch -XX:+DisableExplicitGC -XX:+ParallelRefProcEnabled -XX:+PerfDisableSharedMem -XX:+UnlockExperimentalVMOptions -XX:+UseG1GC -XX:G1HeapRegionSize=8M -XX:G1HeapWastePercent=5 -XX:G1MaxNewSizePercent=40 -XX:G1MixedGCCountTarget=4 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1NewSizePercent=30 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:G1ReservePercent=20 -XX:InitiatingHeapOccupancyPercent=15 -XX:MaxGCPauseMillis=200 -XX:MaxTenuringThreshold=1 -XX:SurvivorRatio=32 -Dusing.aikars.flags=https://mcflags.emc.gs -Daikars.new.flags=true -Djava.io.tmpdir=${fabricServerDir}/.java-tmp";

          };
        };

        systemd.tmpfiles.rules = [
          "d ${fabricServerDir}/.java-tmp 0700 minecraft minecraft -"
        ];
        system.stateVersion = vars.host.stateVersion;
      };
  };
}
