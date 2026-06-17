{ pkgs, ... }:

{
  programs.rust-motd = {
    enable = true;
    enableMotdInSSHD = true;
    refreshInterval = "*/5";

    order = [
      "global"
      "banner"
      "uptime"
      "load_avg"
      "memory"
      "filesystems"
      "service_status"
    ];

    settings = {
      banner = {
        command = "${pkgs.figlet}/bin/figlet -f slant blackbox";
        color = "green";
      };

      uptime = {
        prefix = "Uptime";
      };

      load_avg = {
        format = "Load 1/5/15 min: {one:.02}, {five:.02}, {fifteen:.02}";
      };

      memory = {
        swap_pos = "beside";
      };

      filesystems = {
        root = "/";
      };

      service_status = {
        SSH = "sshd";
        Hermes = "hermes-agent";
        Personal = "container@personal-webserver";
        Minecraft = "container@minecraft";
        ASCII = "container@ascii-webserver";
      };
    };
  };
}
