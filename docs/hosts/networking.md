# Networking and Tailscale

- Kura uses NetworkManager; `br0` obtains IPv4 configuration through
  DHCP because its host vars do not declare `network.hostCidr`.
- All flake-managed systems declare local hostname announcements:
  `yoru.local`, `kura.local` and `akuma.local`. NixOS hosts share
  `modules/nixos/hostname-announcement.nix` (Avahi address publishing, mDNS
  resolution and UDP 5353); yoru uses native Bonjour/mDNSResponder with its
  local hostname and computer name tied to its configured hostname.
- Physical NixOS hosts publish on their LAN bridge and Wi-Fi interface when
  present; akuma publishes on its attached guest network. Tailscale is excluded,
  and discovery is not reflected between networks. A NAT-isolated UTM guest
  needs bridged networking to be discoverable on the physical LAN. This is
  local-link discovery, not router DNS registration or subnet-routed mDNS.
- `NetworkManager-wait-online` is disabled in the shared physical-host module so
  idle secondary interfaces do not fail activation.
- Tailscale is declared on **yoru and kura**. Akuma is not enabled.
  Declaration alone does not enroll a machine in a tailnet.

Kura's optional Mullvad split tunnel requires a separately provisioned private
key at `/var/lib/wireguard/mullvad.key`. Its service is skipped when that file is
absent, so syncing the checkout does not fail activation or fabricate VPN
credentials. The split tunnel only routes its explicitly declared destinations,
not the home LAN or general internet traffic.

Yoru uses nix-darwin's Nix-managed launchd daemon and CLI, not a separate
Homebrew/App Store Tailscale app. The module supplies a `ts.net` MagicDNS
resolver; overriding all local DNS is left disabled.

Kura enables the NixOS daemon, opens its UDP transport port (default 41641)
and advertises the home LAN as a subnet router; yoru remains an ordinary client. These declarations do not configure
an exit node, enable Tailscale SSH or trust every port on the tailnet interface.

After syncing and activating each enabled host, authenticate it once using the
same account/tailnet as the existing devices:

```bash
sudo tailscale up
tailscale status
tailscale ip -4
```

Complete the browser login printed by `tailscale up`. Verify the machine appears
in the intended tailnet before treating it as enrolled. Do not store auth keys
in the repository or the Nix store. With MagicDNS enabled in the tailnet,
enrolled devices can use their assigned Tailscale DNS names; all flake-managed
systems separately declare `.local` hostname announcements on their local links.

### kura as the home-LAN subnet router

`hosts/kura/vars.nix` declares `network.tailscaleSubnetRoutes` as
`192.168.67.0/24`. The host enables Tailscale's server routing features for IP
forwarding and applies the advertisement through `extraSetFlags`. This lets
remote tailnet clients reach LAN IPs without installing Tailscale on every LAN
device or running it on the BPI-R3. Kura must remain online and connected to the
LAN; this is not an exit node and does not route general internet traffic.

After syncing the updated checkout to kura and activating its configuration:

```bash
# Apply the new settings unit even if tailscaled was already running at switch time.
sudo systemctl start tailscaled-set.service
sudo tailscale up --advertise-routes=192.168.67.0/24
tailscale status
```

There are three separate controls:

1. **Route approval:** in the [Tailscale admin console](https://login.tailscale.com/admin/machines),
   open kura's subnet/route settings and approve `192.168.67.0/24`. This approves
   the subnet route, not each LAN device individually.
2. **Access rules:** tailnet grants/ACLs decide which users or source devices may
   reach which destination IPs and ports. The subnet can be permitted as a whole
   or restricted to selected devices/services. Approval alone does not override
   access policy or the destination's own firewall. Review existing rules rather
   than assuming the tailnet is open to everyone.
3. **Client route acceptance:** iOS and macOS accept subnet routes by default;
   Linux clients that need remote LAN access require `sudo tailscale set --accept-routes`.
   Do not enable this on kura merely to advertise its directly connected LAN.

Default subnet SNAT is retained: LAN targets see connections as coming from kura,
so no return route or DHCP/gateway change is needed on the BPI-R3. Direct Tailscale
clients such as yoru can still be useful for their own device identities
and peer-to-peer access, but are not required just to make them reachable by LAN IP.

Test from the iPhone on cellular with Tailscale connected, using a known LAN
service's IP and port. Being on the same Wi-Fi is not proof that subnet routing
works. If the BPI-R3 already advertises this subnet, leave it available until
kura is approved and tested, then disable the old advertisement/client there;
this repository does not manage or remove the router's installation.

See Tailscale's [subnet-router guide](https://tailscale.com/docs/features/subnet-routers)
and [route-injection reference](https://tailscale.com/docs/reference/route-injection).

[Host index](README.md) · [Repository README](../../README.md)
