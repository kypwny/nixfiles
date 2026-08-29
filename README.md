# nixfiles

personal nixos and nix-darwin configurations managed via flakes and home-manager.

## hosts

- **snowbox**: nixos server (x86_64-linux)
- **yoru**: macbook pro (aarch64-darwin)

## structure

- `hosts/`: host-specific configurations
- `modules/`: shared, nixos, and darwin system modules
- `home/`: home-manager user environments and dotfiles
- `lib/`: system generation helpers

## usage

### macos (yoru)

```bash
nix run nix-darwin -- switch --flake .#yoru
```

### nixos (snowbox)

```bash
sudo nixos-rebuild switch --flake .#snowbox
```
