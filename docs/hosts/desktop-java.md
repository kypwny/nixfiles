# Prism Launcher Java

Yoru declares nixpkgs JDK 21 for Prism Launcher. Home Manager links the macOS JDK bundle into
`~/Library/Java/JavaVirtualMachines/`, which the installed Prism Launcher scans
even when it is launched from Finder or Launchpad, and exports the launcher's
explicit `PRISMLAUNCHER_JAVA_PATHS` discovery variable.

After rebuilding a host, fully quit and reopen Prism Launcher, then use
**Settings → Java → Auto-detect**. It should list the declared JDK 21. This is
the current-release runtime; retain or add another JDK only when an older
Minecraft instance specifically requires one.

[Host index](README.md) · [Repository README](../../README.md)
