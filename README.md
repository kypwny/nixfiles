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
