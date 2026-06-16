{ config, hermes-agent, pkgs, ... }:

{
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.validateSopsFiles = false;
  sops.secrets."hermes-env" = {
    sopsFile = builtins.toPath "/home/ky/.config/sops-nix/hermes.env";
    format = "dotenv";
  };

  services.hermes-agent = {
    enable = true;
    package = hermes-agent.packages.${pkgs.system}.full;
    extraPackages = [ pkgs.nodejs ];
    settings.model = {
      base_url = "https://openrouter.ai/api/v1";
      default = "xiaomi/mimo-v2.5";
    };
    settings.stt = {
      enabled = true;
      provider = "local";
      local.model = "base";
    };
    settings.tools.terminal.security_mode = "unrestricted";
    environmentFiles = [ config.sops.secrets."hermes-env".path ];
    addToSystemPackages = false;
  };
}
