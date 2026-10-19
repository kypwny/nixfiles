let
  identity = import ../identity.nix;
  username = identity.user.name;
in
{
  nixos = {
    kura = {
      hostname = "kura";
      inherit username;
      system = "x86_64-linux";
      profile = "server";
    };
    # UTM guest: do not inherit physical-host bridges, secrets or containers.
    akuma = {
      hostname = "akuma";
      inherit username;
      system = "aarch64-linux";
      profile = "vm";
    };
  };
  darwin.yoru = {
    hostname = "yoru";
    inherit username;
    system = "aarch64-darwin";
  };
}
