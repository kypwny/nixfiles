# NixOS Config Layout

This repo is organized around one active host, `kura`, with shared values
kept close to that host.

## Entry Points

- `flake.nix` defines `nixosConfigurations.kura`.
- `hosts/kura/default.nix` is the main host module imported by the flake.
- `configuration.nix` is a compatibility shim that imports `hosts/kura`.
- `hosts/kura/hardware-configuration.nix` is generated; move or import it,
  but avoid hand-editing its hardware scan output.

## Shared Values

Put host-local constants in `hosts/kura/vars.nix` when multiple modules need
them. This includes the admin user, LAN bridge, gateway, host and container IPs,
common container DNS, state version, and external host paths.

Keep service-specific details inside the service module when only one module
uses them. Examples include Minecraft mods, Jellyfin codec settings, and I2P
tunnel options.

## Modules

- `modules/base/` holds host-wide settings: boot, networking, Nix policy,
  programs, security, SOPS, state version, and users.
- `modules/services/` holds host services such as Hermes, Jellyfin, and MOTD.
- `modules/containers/` holds NixOS containers and any assets they own.

## Validation

Run validation from the repo root:

```bash
nix flake check
sudo nixos-rebuild build --flake .#kura
```

Use `switch` only after inspecting the diff and confirming the build.
