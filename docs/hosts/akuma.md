# akuma: NixOS guest

`nixosConfigurations.akuma` is the `aarch64-linux` UTM toolbench. Its VM profile
does not inherit physical-host bridges, containers or host-key-based sops
configuration. `aku` is the historical name, not a current flake target.

## Current declaration

- Host module: `hosts/akuma/default.nix`; guest policy: `modules/vm/default.nix`.
- UEFI/systemd-boot, virtio devices, ext4 root at `/dev/vda2`, vfat ESP at
  `/dev/vda1`, no disk swap partition; zram is separate.
- SSH is the primary control plane: public-key authentication, no root login,
  password/keyboard-interactive SSH authentication disabled, firewall TCP 22.
- The admin user has passwordless sudo as declared by the VM profile.
- The console declares LightDM's mini greeter and i3/XTerm. It is not autologin;
  an authorized SSH key is not a local-console password. Do not assume that a
  graphical password prompt proves password-based SSH is enabled.
- Tool availability varies by platform. JADX's heavy closure is omitted from the
  system baseline and can be requested with `nix develop .#android` on demand.

Declarations are not boot or runtime evidence. Do not change `stateVersion` to
match a newer installer ISO release.

## One-time bootstrap

Use an ARM64 NixOS installer and a UTM virtualization backend compatible with
it. Verify its published checksum and architecture; inspect the backend's
console/serial requirements and leave enough host RAM. The old `utm-vms.md`
Kali recommendation is an alternative VM, not this managed NixOS host.

**Destructive step:** the declaration expects one guest virtio disk with the
partition layout below. Verify `lsblk -f`, capacity and device identity inside
the live installer. Do not run this against a host disk or an existing guest
whose data you intend to keep.

```sh
# Run only in the selected guest's live installer after verifying /dev/vda.
sudo -i
parted /dev/vda -- mklabel gpt
parted /dev/vda -- mkpart ESP fat32 1MiB 512MiB
parted /dev/vda -- set 1 esp on
parted /dev/vda -- mkpart root ext4 512MiB 100%
mkfs.fat -F 32 /dev/vda1
mkfs.ext4 /dev/vda2
mount /dev/vda2 /mnt
mkdir -p /mnt/boot
mount /dev/vda1 /mnt/boot
```

Transfer a reviewed checkout using the guest's actual network/share mechanism;
do not serve the entire home directory or embed private keys in a tarball.
Choose a writable installer working directory and run from that checkout:

```sh
nixos-install --flake .#akuma --no-root-passwd
```

Before reboot, verify the mounted layout and declared user/key, the successful
install output and the expected SSH access path. The live installer's user and
SSH policy are not those of the staged `akuma` configuration. Keep a working
console for recovery. No install or boot is claimed by this guide.

## First boot and maintenance

Discover the address from UTM/the guest; do not reuse the notes' historical IP.
Use the configured SSH alias/key only after verifying it against the declared
public key. For this profile's existing key-based access:

```sh
ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519 akuma
# In the guest:
hostnamectl --static
readlink /run/current-system
systemctl is-active sshd
sudo -n true
cd ~/nixfiles
sudo nixos-rebuild switch --flake .#akuma --accept-flake-config
```

The alias must resolve to the current guest; if it does not, use the discovered
address explicitly and correct the alias later. Do not guess credentials or
assume a locally remembered key matches a freshly reinstalled guest.

[Maintenance](maintenance.md) separates evaluation, build and activation.
[Networking](networking.md) explains why `.local` discovery across NAT is not
promised. A remote builder or nested KVM boot loop is opt-in; inspect actual
capabilities before declaring either configured.

Guest setup instructions follow the current host names and declarations.
Existing external workspaces are not modified.

[Host index](README.md) · [Linux runtime guide](../../shells/docs/linux-runtime-on-mac.md)
