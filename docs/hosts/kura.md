# kura

`nixosConfigurations.kura` is the `x86_64-linux` server/internal-services host.
Host-specific values are in `hosts/kura/vars.nix`; the host module is
`hosts/kura/default.nix` with shared physical-host/server modules.

- [Maintenance](maintenance.md) preserves the systemd-major-upgrade warning:
  `nixos-rebuild boot` plus a reboot may be needed instead of live switching.
- [Networking and Tailscale](networking.md) preserves DHCP/hostname announcements,
  optional private Mullvad key provisioning and the home-LAN subnet-router setup.

Route advertisement, admin approval, grants/ACLs, client route acceptance and an
off-LAN test are separate requirements. Do not assume syncing or switching the
configuration enrolled kura or made the routed subnet reachable.

[Host index](README.md) · [Repository README](../../README.md)
