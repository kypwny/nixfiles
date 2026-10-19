# Experimental macOS kernel work

Start with source reading, panic analysis and supported user-space observability.
A Nix research shell does not provide full Xcode, an internal SDK, a matching
Kernel Debug Kit, a debuggee or permission to modify macOS security policy.

## Record the target before installing tooling

Read-only discovery on the intended Mac:

```sh
sw_vers
uname -m
sysctl kern.version
xcode-select -p
```

Select an XNU source revision and KDK matching the **OS build and architecture**,
not the lexicographically last installed kit. Install Apple-gated downloads
interactively; do not put Apple credentials in Nix, scripts or this repository.
A KDK can help symbolication/debugging but is not a blanket guarantee that the
public XNU release builds with a retail SDK on your machine.

The public XNU README describes SDK/architecture/kernel variants and includes
examples using `macosx.internal`. Its build requirements and boot examples must
be interpreted for the source revision and target platform; historical kernel
cache commands are not a modern Apple Silicon installation procedure.[5]

Keep XNU source, output and panic data in an external private workspace. Use the
upstream build instructions for the chosen release, record missing prerequisites
and keep failures rather than replacing them with "everything works once Xcode
is installed" claims. [`kbuild.sh`](../scripts/kbuild.sh) is for experimental
Linux work, not an XNU build/deploy tool.

## Safer observation first

Use relevant Apple tools such as Instruments, `sample`, `spindump` and available
system logs before considering live kernel debugging. Probe coverage and access
are limited by OS version, entitlements and security policy; do not promise
unrestricted DTrace or kdebug on a stock system. Treat panic reports as sensitive
because they may contain device identifiers and application context.

A kernel debugger can stop or panic its target. It needs a distinct debuggee and
compatible symbols, transport and platform support. A macOS VM may be useful for
some experiments, but KDP behavior, virtual devices and debugging transport must
be validated for that backend; "UTM is installed" is not proof. The XNU README
itself notes hardware-dependent transport support.[5]

## Security changes are not setup defaults

Do not copy the old `macos-kernel-dev.md` NVRAM, watchdog, `csrutil`, `bputil` or
kernel-extension recipes into your daily workstation. Reduced Security,
Permissive Security and SIP are distinct controls, not synonyms. What is required
for one legacy kext is not necessarily required or sufficient for a debugger.

Any security reduction belongs in a separately approved, version-specific plan
for a recoverable test machine: backups, Recovery access, recorded prior settings,
explicit affected boot volume, rollback steps and a post-experiment policy check.
This guide intentionally does not include a turnkey security-disable command.
Prefer DriverKit/System Extensions where suitable rather than assuming a legacy
kernel extension is the only driver path.

No Xcode/KDK installation, XNU build, KDP attachment, security reduction or kext
load was performed for this documentation change. The original note's specific
SoC, OS version, kernel filename and claims of automatic success are historical,
not current host measurements.

[Shells](../README.md) · [Linux kernel work](kernel-work.md) ·
[iOS research](ios-re.md)

## Sources

[5] https://github.com/apple-oss-distributions/xnu