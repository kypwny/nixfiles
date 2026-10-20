# nix eval --impure --json --expr 'import ./tests/host-identity.nix { flake = builtins.getFlake "path:/Users/ky/nixfiles"; }'
{
  flake,
  repo ? ../.,
}:
let
  inventory =
    if builtins.pathExists (repo + "/hosts/default.nix") then
      import (repo + "/hosts/default.nix")
    else
      throw "host-identity: central host inventory is missing";
  expected = {
    nixos = {
      kura = {
        hostname = "kura";
        username = "ky";
        system = "x86_64-linux";
        profile = "server";
      };
      akuma = {
        hostname = "akuma";
        username = "ky";
        system = "aarch64-linux";
        profile = "vm";
      };
    };
    darwin.yoru = {
      hostname = "yoru";
      username = "ky";
      system = "aarch64-darwin";
    };
  };
  identity = import (repo + "/identity.nix");
  keys = {
    unicorn = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDw0aRfa+YINgWJP7FKsRZ+swvPOLE5cc94ZyijkZFoX unicorn";
    pwny = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILrGOBlnxXx7U52BuS+M2swzKufwu1A76RyjfHK8w48A pwny";
    yoruEcdsa = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBKqitIfqaJ3cCYvqBrCn5AjkYOlkdw+706foxEHnwL/mP38nS59v6vJV3LIAojEgDzlUF6c2z+FFMsMoMvSmE3c= yoru@secretive.yoru.local";
  };
  membership = {
    kura = [
      keys.unicorn
      keys.pwny
      keys.yoruEcdsa
    ];
    akuma = [ keys.pwny ];
    yoru = [ keys.yoruEcdsa ];
  };
  researchOnly = [
    "radare2"
    "rizin"
    "binwalk"
    "capstone"
    "unicorn"
    "jadx"
    "frida-tools"
    "gdb"
    "openocd"
    "socat"
    "ldid"
    "ipsw"
    "palera1n"
    "dtc"
    "universal-ctags"
    "cscope"
    "bear"
    "qemu"
  ];
  allHosts = flake.nixosConfigurations // flake.darwinConfigurations;
  renamedLinux = flake.lib.mkNixos (inventory.nixos.kura // { username = "identity-test"; });
  renamedDarwin = flake.lib.mkDarwin (inventory.darwin.yoru // { username = "identity-test"; });
  mismatch = flake.lib.mkNixos (
    inventory.nixos.kura
    // {
      extraModules = [ ({ lib, ... }: { home-manager.users.ky.home.username = lib.mkForce "not-ky"; }) ];
    }
  );
in
assert inventory == expected;
{
  inventory = true;
  invalidProfileRejected =
    assert
      !(builtins.tryEval (flake.lib.mkNixos (inventory.nixos.kura // { profile = "typo"; }))).success;
    true;
  identityPropagation =
    assert renamedLinux.config.users.users.identity-test.name == "identity-test";
    assert renamedLinux.config.users.users.identity-test.uid == identity.user.uid;
    assert !(renamedLinux.config.users.users ? ky);
    assert renamedLinux.config.home-manager.users.identity-test.home.username == "identity-test";
    assert renamedDarwin.config.users.users.identity-test.home == "/Users/identity-test";
    assert
      renamedDarwin.config.home-manager.users.identity-test.home.homeDirectory == "/Users/identity-test";
    true;
  mismatchRejected =
    assert builtins.any (a: !a.assertion) mismatch.config.assertions;
    true;
  publicIdentity =
    assert identity.sshKeys == keys;
    assert
      identity.git == {
        name = "ky";
        email = "ky@tilde.horse";
        signingkey = "~/.ssh/ky.pub";
      };
    true;
  hosts = builtins.mapAttrs (
    name: host:
    let
      c = host.config;
      h = c.home-manager.users.ky;
      u = c.users.users.ky;
      darwin = name == "yoru";
    in
    assert c.networking.hostName == name;
    assert
      host.pkgs.stdenv.hostPlatform.system
      == (if darwin then inventory.darwin.${name}.system else inventory.nixos.${name}.system);
    assert u.name == h.home.username;
    assert u.home == h.home.homeDirectory;
    assert u.openssh.authorizedKeys.keys == membership.${name};
    assert
      !darwin
      || !(builtins.elem "qemu" (map (package: package.pname or "") c.environment.systemPackages));
    assert
      (
        darwin && !(builtins.elem "kitty" (map (package: package.pname or "") c.environment.systemPackages))
      )
      || (
        !darwin && builtins.elem "kitty" (map (package: package.pname or "") c.environment.systemPackages)
      );
    assert
      !darwin || builtins.elem "ghidra" (map (package: package.pname or "") c.environment.systemPackages);
    assert
      !darwin
      || builtins.elem "qemu" (
        map (package: package.pname or "") flake.devShells.aarch64-darwin.kernel.nativeBuildInputs
      );
    assert
      !darwin || builtins.elem "imhex" (map (package: package.pname or "") c.environment.systemPackages);
    assert !darwin || !(builtins.any (cask: cask.name == "imhex") c.homebrew.casks);
    assert !darwin || builtins.elem "imhex" flake.lib.toolInventory.aarch64-darwin.re.included;
    assert
      !darwin
      || builtins.all (
        name: !(builtins.elem name (map (package: package.pname or "") c.environment.systemPackages))
      ) researchOnly;
    assert
      !darwin
      || builtins.elem "ghidra" (
        map (package: package.pname or "") flake.devShells.aarch64-darwin.re.nativeBuildInputs
      );
    assert
      !darwin
      || builtins.elem "qemu" (
        map (package: package.pname or "") flake.devShells.aarch64-darwin.kernel.nativeBuildInputs
      );
    assert c.system.stateVersion == (if darwin then 5 else "26.05");
    assert h.home.stateVersion == "26.05";
    assert
      h.programs.git.settings.user
      == (if darwin then identity.git // { signingkey = "~/.ssh/yoru.pub"; } else identity.git);
    assert
      h.home.file.".ssh/allowed_signers".text
      == "${identity.allowedSigner}\n${identity.git.email} ${identity.sshKeys.yoruEcdsa}\n";
    assert (
      if darwin then
        host.pkgs.lib.hasSuffix "/bin/ssh-keygen-secretive" h.programs.git.settings.gpg.ssh.program
      else
        h.programs.git.settings.gpg.ssh.program == "ssh-keygen"
    );
    # yoru turns Apple's all-interfaces sshd off and runs a tailnet-only one.
    assert
      if darwin then
        c.services.openssh.enable == false
        && builtins.elem "ListenAddress=100.102.52.1" c.launchd.daemons.sshd-tailnet.serviceConfig.ProgramArguments
      else
        c.services.openssh.enable;
    assert
      darwin
      || (
        !c.services.openssh.settings.PasswordAuthentication
        && !c.services.openssh.settings.KbdInteractiveAuthentication
        && c.services.openssh.settings.PermitRootLogin == "no"
      );
    assert darwin || u.uid == identity.user.uid;
    {
      identityMatches = true;
      keyMembershipPreserved = true;
      stateVersionsPreserved = true;
      sshSecurityPreserved = true;
    }
  ) allHosts;
}
