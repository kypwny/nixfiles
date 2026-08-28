{ pkgs, vars, ... }:
{
  users.groups.${vars.user.group}.gid = vars.user.gid;

  users.users.${vars.user.name} = {
    isNormalUser = true;
    uid = vars.user.uid;
    shell = pkgs.fish;
    extraGroups = [
      "wheel"
    ];
    openssh.authorizedKeys.keys = vars.user.authorizedKeys;
  };
}
