{
  imports = [
    ./nix-settings.nix
    ./packages.nix
  ];

  catppuccin = {
    enable = true;
    autoEnable = true;
    flavor = "mocha";
    accent = "blue";
  };
}
