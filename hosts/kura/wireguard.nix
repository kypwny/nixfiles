{ ... }:

{
  # Mullvad split tunnel. The ISP blacklists tilde.horse (65.87.7.164) and
  # matrix.tilde.horse (66.78.40.150), so only traffic to those two addresses
  # is routed through the Mullvad WireGuard tunnel. Everything else — LAN,
  # Tailscale, Jellyfin, nix updates — keeps its direct br0 default route.
  #
  # SSH from yoru then bypasses the blacklist via `ssh -J kura.local tilde.horse`
  # (the ProxyJump blocks live in home/default.nix).
  #
  # The private key is NOT stored in the nix store: wg-quick reads it at
  # activation from /var/lib/wireguard/mullvad.key (root:root, 0600).
  networking.wg-quick.interfaces.mullvad = {
    address = [
      "10.73.99.85/32"
      "fc00:bbbb:bbbb:bb01::a:6354/128"
    ];
    privateKeyFile = "/var/lib/wireguard/mullvad.key";
    peers = [
      {
        # us-mia-wg-003 ("Smooth Squid") — keep in sync with the Mullvad
        # account; rotate by regenerating the device config and re-deploying
        # the key file.
        publicKey = "N/3F0QvCuiWWzCwaJmnPZO53LZrKn6sr7rItecrQSQY=";
        # Split tunnel: wg-quick installs exactly these routes via the
        # mullvad interface. Deliberately NOT 0.0.0.0/0.
        # If tilde.horse ever changes address, update these (dig +short).
        allowedIPs = [
          "65.87.7.164/32" # tilde.horse / git.tilde.horse
          "66.78.40.150/32" # matrix.tilde.horse
        ];
        endpoint = "45.134.142.193:51820";
      }
    ];
  };
}
