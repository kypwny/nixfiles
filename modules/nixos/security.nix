{ vars, ... }:
{
  security.sudo.extraRules = [
    {
      users = [ vars.user.name ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  security.unprivilegedUsernsClone = true;

  services.openssh = {
    enable = true;

    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      PubkeyAuthentication = true;
    };
  };

  programs.mosh = {
    enable = true;
    openFirewall = false;
  };

  # Mosh authenticates over SSH, then uses UDP ports in this range.
  networking.firewall.interfaces.${vars.network.bridge}.allowedUDPPortRanges = [
    {
      from = 60000;
      to = 61000;
    }
  ];
}
