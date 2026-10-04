{
  lib,
  pkgs,
  vars,
  ...
}:
let
  # Hosts that set vars.user.hashedPasswordFile get fully declarative users:
  # /etc/shadow is rebuilt from config on every activation, which is what an
  # impermanent root needs (an imperative `passwd` would be wiped on reboot).
  # Hosts without it (kura) keep mutable users and are unaffected.
  declarativePassword = vars.user ? hashedPasswordFile;
in
{
  users.mutableUsers = !declarativePassword;

  users.groups.${vars.user.group}.gid = vars.user.gid;

  users.users.${vars.user.name} = {
    isNormalUser = true;
    uid = vars.user.uid;
    shell = pkgs.fish;
    extraGroups = [
      "wheel"
    ];
    openssh.authorizedKeys.keys = vars.user.authorizedKeys;
  }
  // lib.optionalAttrs declarativePassword {
    inherit (vars.user) hashedPasswordFile;
  };
}
