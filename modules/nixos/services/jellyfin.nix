{
  lib,
  pkgs,
  vars,
  ...
}:

let
  mediaMount = vars.paths.mediaMount;
  mediaRoot = "${mediaMount}/media";
  mediaDirs = [
    "movies"
    "tv"
    "music"
  ];
  caddyContainerAddress = vars.containers.asciiWebserver.address;
  networkXmlTemplate = pkgs.writeText "jellyfin-network.xml" ''
    <?xml version="1.0" encoding="utf-8"?>
    <NetworkConfiguration xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
      <BaseUrl>/jellyfin</BaseUrl>
      <KnownProxies>
        <string>${caddyContainerAddress}</string>
      </KnownProxies>
    </NetworkConfiguration>
  '';
in
{
  # The Sabrent/JMicron USB bridge showed transport resets under load. Disable
  # UAS for this bridge after the next reboot; BOT is slower but usually steadier.
  boot.kernelParams = [ "usb-storage.quirks=152d:a578:u" ];

  # Automount: the USB drive is only mounted while something is actively
  # reading it, so the bridge and drive can idle between accesses. The
  # generous device/mount timeouts give a spun-down drive time to spin up.
  # No bind export or NFS server here -- mpd on the other box reads via
  # an on-demand sshfs tunnel, which is what triggers this automount.
  fileSystems.${mediaMount} = {
    device = "/dev/disk/by-uuid/240ef879-c0d9-4d4b-ab0c-247f22cee6b2";
    fsType = "ext4";
    options = [
      "nofail"
      "noatime"
      "nosuid"
      "nodev"
      "errors=remount-ro"
      "x-systemd.automount"
      "x-systemd.idle-timeout=2min"
      "x-systemd.device-timeout=20s"
      "x-systemd.mount-timeout=30s"
    ];
  };

  services.udev.extraRules = ''
    ACTION=="add|change", SUBSYSTEM=="block", ENV{DEVTYPE}=="disk", ENV{ID_SERIAL}=="TOSHIBA_DT01ACA100_32C5G9GNS", RUN+="${pkgs.hdparm}/bin/hdparm -q -W0 /dev/%k"
  '';

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      intel-compute-runtime
      vpl-gpu-rt
    ];
  };

  services.jellyfin = {
    enable = true;
    openFirewall = false;
    forceEncodingConfig = true;

    hardwareAcceleration = {
      enable = true;
      type = "qsv";
      device = "/dev/dri/renderD128";
    };

    transcoding = {
      enableHardwareEncoding = true;
      enableIntelLowPowerEncoding = true;
      enableToneMapping = true;
      throttleTranscoding = true;
      maxConcurrentStreams = 2;

      hardwareDecodingCodecs = {
        h264 = true;
        hevc = true;
        hevc10bit = true;
        hevcRExt10bit = true;
        hevcRExt12bit = true;
        mpeg2 = true;
        vc1 = true;
        vp8 = true;
        vp9 = true;
        av1 = true;
      };

      hardwareEncodingCodecs.hevc = true;
    };
  };

  users.users.jellyfin.extraGroups = [
    "render"
    "video"
    "users"
  ];

  # Prepare media dirs once the automount has triggered. Decouple from the
  # mount unit itself (no RequiresMountsFor / requiredBy on jellyfin) so the
  # backing FS can idle-unmount while Jellyfin stays up.
  systemd.services.prepare-jellyfin-media-usb = {
    description = "Prepare Jellyfin media directories on the USB drive";
    requiredBy = [ "jellyfin.service" ];
    before = [ "jellyfin.service" ];
    serviceConfig.Type = "oneshot";
    # Mount-on-demand: touching the path triggers the automount, then we
    # create any missing media dirs.
    script = ''
      ${pkgs.coreutils}/bin/touch ${lib.escapeShellArg mediaRoot}
      ${lib.concatMapStringsSep "\n" (
        dir:
        "${pkgs.coreutils}/bin/install -d -o ${vars.user.name} -g ${vars.user.group} -m 0755 ${lib.escapeShellArg "${mediaRoot}/${dir}"}"
      ) mediaDirs}
    '';
  };

  systemd.services.jellyfin = {
    requires = [ "prepare-jellyfin-media-usb.service" ];
    after = [ "prepare-jellyfin-media-usb.service" ];
    environment.LIBVA_DRIVER_NAME = "iHD";
    # Let the automount idle-unmount the backing FS. Jellyfin reads the media
    # on demand; ReadOnlyPaths would pin the mount.
    serviceConfig.ReadOnlyPaths = lib.mkForce [ ];

    preStart = lib.mkBefore ''
      networkXml="/var/lib/jellyfin/config/network.xml"
      xmlstarlet=${pkgs.xmlstarlet}/bin/xmlstarlet

      if [[ ! -e "$networkXml" ]]; then
        cp ${networkXmlTemplate} "$networkXml"
        chmod u+w "$networkXml"
      else
              tmp="$networkXml.tmp"

              if grep -q '<BaseUrl' "$networkXml"; then
                "$xmlstarlet" ed -u '/NetworkConfiguration/BaseUrl' -v '/jellyfin' "$networkXml" >"$tmp"
              else
                "$xmlstarlet" ed -s '/NetworkConfiguration' -t elem -n BaseUrl -v '/jellyfin' "$networkXml" >"$tmp"
              fi
              mv "$tmp" "$networkXml"

              if ! grep -q '<KnownProxies' "$networkXml"; then
                "$xmlstarlet" ed -s '/NetworkConfiguration' -t elem -n KnownProxies -v "" "$networkXml" >"$tmp"
                mv "$tmp" "$networkXml"
              fi

              if ! grep -q '<string>${caddyContainerAddress}</string>' "$networkXml"; then
                "$xmlstarlet" ed -s '/NetworkConfiguration/KnownProxies' -t elem -n string -v '${caddyContainerAddress}' "$networkXml" >"$tmp"
                mv "$tmp" "$networkXml"
              fi
            fi
    '';
  };

  networking.firewall.interfaces.${vars.network.bridge}.allowedTCPPorts = [
    8096
  ];
}
