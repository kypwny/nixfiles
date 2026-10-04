# nixfiles

personal nixos and nix-darwin configurations managed via flakes and home-manager.

## hosts

- **yoru**: macbook pro (aarch64-darwin) - primary workstation & dev environment
- **kura**: nixos server (x86_64-linux) - home/internal services
- **navi**: nixos desktop (x86_64-linux) - custom kernel, VFIO passthrough & fuzzing
- **aku**: nixos guest VM (aarch64-linux) - UTM/Apple Virtualization security arsenal & linux toolbench

## structure

- `hosts/`: host-specific configurations (`yoru`, `kura`, `navi`, `aku`)
- `modules/`: shared, nixos, darwin, and vm system modules
- `home/`: home-manager user environments and dotfiles
- `lib/`: system generation helpers and categorized `toolset.nix`
- `pkgs/`: custom pinned derivations (e.g., `palera1n`)

## devshells

Categorized devShells defined via `lib/toolset.nix` (RedNix-inspired):

- `nix develop .#all`: full tool suite filtered for current platform
- `nix develop .#re`: reverse engineering & binary analysis (ghidra, radare2, rizin, binwalk, jadx)
- `nix develop .#ios`: iOS research & bootchain (ipsw, ldid, frida-tools, palera1n)
- `nix develop .#android`: mobile API testing (adb, apktool, apksigner, apkid, apkleaks, jadx, scrcpy)
- `nix develop .#kernel`: kernel development & navigation (dtc, qemu, llvm, ctags, cscope, bear)
- `nix develop .#offsec`: penetration testing & security tools (nmap, ffuf, certipy, impacket, hashcat)

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
sudo darwin-rebuild switch --flake .#yoru

# nixos (kura / navi / aku)
sudo nixos-rebuild switch --flake .#<hostname>
```

## navi: Gentoo to NixOS (btrfs, impermanent root)

Layout is defined in `hosts/navi/hardware-configuration.nix` (devices are found
by LABEL) and `hosts/navi/impermanence.nix` (root is rolled back to
`root-blank` every boot).

### 1. Try the dotfiles first (on the running Gentoo box)

`home/navi.nix` pulls the Hyprland setup from `home/dots/`. Evaluate and build
the user environment without touching the system:

```bash
nix build .#nixosConfigurations.navi.config.home-manager.users.ky.home.activationPackage
```

`hy3` and Hyprland come pinned from the flake's nixpkgs (0.56.x), so the
Gentoo-built hy3 under `~/.local/share/hyprpm` is not reusable.

### 2. Back up before wiping /dev/sda

`/dev/nvme0n1p1` (`extrastorage`, xfs) is not touched. Everything on
`secure-root` is. Copy off, at minimum: `~/.gnupg` (the `secret-key-*.asc`
exports and `private-keys-v1.d`), `~/.ssh`, `~/.password-store`, and the
contents of `/home/ky` you want to keep (159G as measured). Store the copy on
`extrastorage`.

### 3. Partition (from a NixOS installer)

```bash
# /dev/sda: 1G ESP, 8G swap, rest LUKS
mkfs.vfat -F32 -n BOOT /dev/sda1
mkswap -L SWAP /dev/sda2
cryptsetup luksFormat --type luks2 --label navi-crypt /dev/sda3
cryptsetup open /dev/disk/by-label/navi-crypt enc
mkfs.btrfs -L NIXOS /dev/mapper/enc
mount /dev/mapper/enc /mnt
for s in root nix persist log home; do btrfs subvolume create /mnt/$s; done
btrfs subvolume snapshot -r /mnt/root /mnt/root-blank   # must stay empty
umount /mnt
```

Mount `root` at `/mnt`, then `nix`, `persist`, `log`, `home`, and `/boot`
with the options from `hardware-configuration.nix`.

### 4. Seed the secrets that must exist before first boot

```bash
# login password: reuse the hash from the old system's /etc/shadow
install -d -m 700 /mnt/persist/secrets
install -m 600 /path/to/ky.passwd /mnt/persist/secrets/ky.passwd

# host SSH key (sops-nix decrypts with it, see modules/nixos/sops.nix)
install -d -m 755 /mnt/persist/etc/ssh
ssh-keygen -t ed25519 -N '' -f /mnt/persist/etc/ssh/ssh_host_ed25519_key
```

Users are declarative on navi (`users.mutableUsers = false`), so the password
in `/persist/secrets/ky.passwd` is the only login credential; `passwd` will
not persist.

### 5. Install

```bash
nixos-install --flake .#navi --no-root-passwd
```
