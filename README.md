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

### via just

```bash
just switch   # rebuilds and switches system config
just build    # builds system config
just check    # run flake checks
just fmt      # format nix files
just update   # update flake inputs
```

### direct

```bash
# macos (yoru)
nix run nix-darwin -- switch --flake .#yoru

# nixos (snowbox)
sudo nixos-rebuild switch --flake .#snowbox
```
