# Personal host notes

| Host | Platform | Profile/role | Guide |
| --- | --- | --- | --- |
| yoru | aarch64-darwin | Mac workstation | [yoru](yoru.md) |
| kura | x86_64-linux | Physical NixOS server | [kura](kura.md) |
| akuma | aarch64-linux | NixOS VM toolbench | [akuma](akuma.md) |

Akuma was `aku`. Preserve intentional legacy labels and backup paths.
Kura uses
the server module profile; akuma uses the separate guest profile and does not
inherit its bridges, containers or host-key-based sops setup.

- [Maintenance](maintenance.md): just/direct builds and activation, cache
  approval, evaluation and systemd-upgrade caveats.
- [Networking and Tailscale](networking.md): hostname announcements, enrollment,
  private VPN state and kura's subnet-router workflow.
- [Prism Launcher Java](desktop-java.md): yoru JDK discovery.

These instructions were preserved from the original root README rather than
removed. They describe current declarations and operator steps, not a guarantee
that the current checkout is activated or that a machine is enrolled. Run
repository-relative commands from `~/nixfiles` even when reading this directory.
General, non-personal research workflows live under [shells](../../shells/README.md).

[Repository README](../../README.md) · [Layout](../layout.md)
