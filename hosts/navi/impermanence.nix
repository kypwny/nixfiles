# Impermanence for navi: btrfs root rollback + /persist state.
# Layout and technique follow notashelf.dev/posts/impermanence:
#   - systemd stage-1 rolls the `root` subvolume back to the `root-blank`
#     snapshot taken at install time, every boot
#   - everything worth keeping lives in /persist (or /home, /var/log, /nix)
{ inputs, ... }:
{
  imports = [
    inputs.impermanence.nixosModules.impermanence
  ];

  # systemd in stage 1 — required for the rollback service
  boot.initrd.systemd.enable = true;

  boot.initrd.systemd.services.rollback = {
    description = "Rollback BTRFS root subvolume to a pristine state";
    wantedBy = [ "initrd.target" ];
    # The rollback mounts /dev/mapper/enc itself, so it must run after the
    # cryptsetup unit for that mapper has unlocked it.
    after = [ "systemd-cryptsetup@enc.service" ];
    before = [ "sysroot.mount" ];
    unitConfig.DefaultDependencies = "no";
    serviceConfig.Type = "oneshot";
    script = ''
      mkdir -p /mnt

      # We first mount the BTRFS root to /mnt so we can manipulate subvolumes.
      mount -o subvol=/ /dev/mapper/enc /mnt

      # /root is already populated with nested subvolumes (var/lib/portables,
      # var/lib/machines), which makes `btrfs subvolume delete` fail — so we
      # remove them first.
      btrfs subvolume list -o /mnt/root |
        cut -f9 -d' ' |
        while read subvolume; do
          echo "deleting /$subvolume subvolume..."
          btrfs subvolume delete "/mnt/$subvolume"
        done &&

      echo "deleting /root subvolume..." &&
      btrfs subvolume delete /mnt/root

      echo "restoring blank /root subvolume..."
      btrfs subvolume snapshot /mnt/root-blank /mnt/root

      umount /mnt
    '';
  };

  # State that survives the boot-time root wipe.
  # NOTE: /home is a persistent btrfs subvolume and needs no entry here.
  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      "/etc/NetworkManager/system-connections"
      "/etc/nix" # nix.conf, signing keys
      "/var/db/sudo" # sudo lecture timestamps
      "/var/lib/systemd" # random-seed, timer state
      "/var/lib/nixos" # uid/gid persistence
      "/var/lib/docker" # navi runs docker containers
      "/var/lib/libvirt" # VM images
      "/var/lib/waydroid" # android container images
      "/var/lib/bluetooth"
    ];
    files = [
      "/etc/machine-id"
      # SSH host keys: without these every reboot re-generates them and
      # sops secrets keyed to host SSH keys (see modules/nixos) break.
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
    ];
  };
}
