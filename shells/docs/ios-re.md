# iOS firmware and device research

Start with firmware/static inspection. A declared host tool does not imply a
compatible device, a jailbreak, trusted certificates or a working debugger.
Use an authorized research device and test accounts, not a daily-use phone.

## Host tools

```sh
cd ~/nixfiles
nix develop .#ios
ipsw --help
ipsw extract --help
ipsw kernel --help
```

Use `re` for Ghidra and general binary inspection, or `dynamic` for Frida. Check
`lib.toolInventory.<system>` before assuming bootchain tools are present. The
repository's custom palera1n output is platform-scoped; package availability is
not a statement of support for every device/OS combination.

Helpers under `shells/scripts/` are explicit entry points. Read their `--help`
and the underlying command help rather than copying the old device-specific
`ios-pull.sh` or `ios-device.sh` examples verbatim.

## Firmware to readable binaries

Select a specific device identifier and OS **build**, retain the download source
and hash, and work in a private directory. Signing status matters for restoring a
device; it is separate from whether you can inspect an already obtained artifact.

The upstream `ipsw` guide documents extraction and kernel inspection. Current
`ipsw extract --kernel` can produce a decompressed kernelcache; `kernel dec` is
for an appropriate still-wrapped/compressed input, not a mandatory second step
on every extracted file.[7]

Illustrative commands for a local IPSW, with actual output names selected after
extraction:

```sh
ipsw extract --kernel firmware.ipsw
ipsw kernel version path/to/extracted-kernelcache
ipsw kernel kexts path/to/extracted-kernelcache
ipsw kernel extract --help
```

Inspect the version's help for output-directory and extraction flags. Use the
real file format and CPU metadata when importing into Ghidra: Mach-O/fileset
loader when supported, raw binary only when genuinely necessary. An extracted
fileset KEXT can be a more manageable unit than the entire kernelcache.[7]
Do not assume every ARM64 kernel is arm64e/PAC-enabled or apply one device's
processor settings universally. Treat the decompiler as a hypothesis and check
instructions, relocations and references.

Dyld caches, entitlements and app binaries are separate artifacts with their own
format and extraction requirements. Firmware inspection is not proof that an
App Store app's executable is available as decrypted code. Do not conflate
kernelcache decompression with authorized app decryption.

## Device prerequisites

Before any bootchain changes, read the current upstream compatibility and device
instructions. The palera1n guide warns about data loss and increased exposure and
recommends a backup.[6] An old note's iPhone model, iOS version or successful CLI
launch is not evidence that your present device is compatible. Device erase,
DFU, passcode restrictions, rootless paths and signing are device/version-specific;
this guide does not automate them.

After establishing an appropriate research runtime, verify USB visibility and
pairing before assuming SSH or instrumentation will work:

```sh
ideviceinfo --help
iproxy --help
frida --version                    # in a shell containing Frida
frida-ps -U
```

USB forwarding is not SSH authentication. Use the device's actual port/account
and a provisioned credential/key; never assume a default root password. Match the
Frida device component to the **core** version reported by `frida --version`.
Rootless filesystem layouts and service management differ from old rootful
recipes. `ldid` entitlements do not magically authorize every operation or replace
Apple trust policy on a stock device.

## Proxy trust is not automatic

Jailbreaking does not automatically install a proxy CA or remove application TLS
pinning. A manually installed certificate profile needs explicit SSL/TLS trust
under **Settings → General → About → Certificate Trust Settings**, according to
Apple.[9] Verify the actual certificate fingerprint, restrict the experiment to
test traffic, then remove the profile/trust when done. Custom TLS implementations
and application pinning can still require separate, reviewed instrumentation.

Do not assume iOS is easier than Android for a particular app: the answer depends
on device support, app defenses, architecture and access to the relevant binary.
Likewise, a stock iPhone is not a generic live kernel-debug target. Device-side
Frida/debugserver workflows have different prerequisites from macOS KDP.

## Experimental bootchain work

PongoOS/source builds are a separate experiment with their own upstream build,
SDK and hardware requirements. Owning a supported boot-ROM-vulnerable device
does not guarantee arbitrary modern OS compatibility or a working boot chain.
Do not lower Mac security or put a phone into DFU just to enter this shell.

Curated from the original `ios-re.md` and workspace README. This documentation
change did not jailbreak a device, extract supplied firmware, verify a live
Frida session or exercise an on-device app-decryption workflow.

[Shells](../README.md) · [Android investigation](android-re.md)

## Sources

[6] https://docs.palera.in
[7] https://blacktop.github.io/ipsw/docs/guides/kernel
[9] https://support.apple.com/en-us/102390