# Authorized security labs

Use these tools only for your own systems, a lab, or a documented engagement
scope. A shell makes tools available; it does not authorize network activity.
No target, VPN credential or personal address is embedded in this guide.

```sh
cd ~/nixfiles
nix develop .#offsec
```

Inspect the platform inventory before assuming a tool is available. Darwin is
not equivalent to the Linux tool set; a [Linux guest](linux-runtime-on-mac.md) is
often the appropriate runtime for Linux-only tooling, VPN interfaces and tracing.

## Explicit workflow

1. Record the authorized target set, time window and allowed techniques. Do not
   scan a subnet merely because a VPN route exists.
2. Inspect [`htb.sh`](../scripts/htb.sh) using `--help`. Choose workspace and action
   explicitly; shell entry never connects a VPN or starts a scan.
3. Provision the VPN profile privately in the environment running the tools.
   Profiles and credentials stay out of Git and the Nix store. Connecting and
   changing routes are deliberate actions, not prerequisites silently performed
   by the shell.
4. Verify VPN interface, route and DNS inside that environment. The Mac's route
   table does not prove a guest is connected. Do not assume an interface is
   always named `tun0` or reuse an old note's target address.
5. Store notes, captures and outputs in the external workspace, then disconnect
   the VPN and clean up listeners when finished.

The `offsec` and `all` shells expose packaged wordlist data through `SECLISTS`
and `ROCKYOU`. Inspect the paths before use; do not claim a wordlist or package
name is an executable. Avoid putting passwords into shell history or command
arguments when the chosen tool offers a safer credential prompt/file mechanism.

A declared package is not an installed server/service: GUI analysis systems can
need their own database, authentication and runtime configuration. Neither shell
entry nor these docs provision them. Do not silently weaken host firewall or
SSH policy to make a lab helper work.

This guide curates the authorized-lab context in the workspace README and VM
notes; it does not import private `~/htb` content or claim a VPN session, tool
build or completed target investigation was verified here.

[Shells](../README.md) · [Akuma](../../docs/hosts/akuma.md)
