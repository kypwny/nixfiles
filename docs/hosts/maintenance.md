# Host maintenance

Run these commands from the updated checkout on the target machine.

### via just

Enter `nix develop` first if `just` or `nh` is not on your PATH:

```bash
nix develop
just switch   # rebuild and switch; auto-detect NixOS vs Darwin
just build    # build without switching
just check    # run flake checks for the current platform
just fmt      # format Nix files
just lint     # statix and deadnix
just scan     # scan for secrets with gitleaks
just update   # update flake inputs
```

### direct

```bash
# macos (yoru)
sudo darwin-rebuild switch --flake .#yoru

# nixos: choose the machine's exact target
sudo nixos-rebuild switch --flake .#kura --accept-flake-config
sudo nixos-rebuild switch --flake .#akuma --accept-flake-config
```

`--accept-flake-config` authorizes the flake's configured binary caches.

On kura, an upgrade across a systemd major version may require
`nixos-rebuild boot` followed by a reboot instead of a live `switch` (see the
comment in `hosts/kura/default.nix`).

### verification before activation

```bash
nix fmt
nix eval --no-write-lock-file .#darwinConfigurations.yoru.config.system.build.toplevel.drvPath
nix eval --no-write-lock-file .#nixosConfigurations.kura.config.system.build.toplevel.drvPath
nix eval --no-write-lock-file .#nixosConfigurations.akuma.config.system.build.toplevel.drvPath
nix flake check --no-build --all-systems
```

Evaluation checks configuration resolution, not whether the generation builds
or is running. Build on a compatible platform before switching. Preserve
unrelated worktree edits, and update this README with affected behavior and
commands whenever configuration changes are completed.

[Host index](README.md) · [Repository README](../../README.md)
