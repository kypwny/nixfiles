# Android APK, ELF and API investigation

Start with the artifact, not a proxy. This guide concerns your own applications,
accounts and devices, or an explicitly authorized research scope. It contains no
target-specific findings, and none of the runtime examples below were exercised
against a supplied app or emulator during this documentation change.

## 1. Static triage on the Mac

```sh
cd ~/nixfiles
nix develop .#android-re
```

Use a private working directory outside this checkout. Preserve the original APK,
record its source/version and hash, and retain outputs with tool versions. The
following filenames are placeholders for local artifacts, not download targets:

```sh
file app.apk
shasum -a 256 app.apk                 # native macOS checksum utility
unzip -l app.apk                     # manifest, DEX, assets and lib/<ABI>/*.so
apkid app.apk                       # packer/obfuscator indicators, not a verdict
jadx -d decompiled app.apk
apktool d app.apk -o decoded         # not available in the ARM Linux shell
rg -n -i 'https?://|api[_-]?key|signature|hmac|bearer' decompiled decoded
```

Use JADX's manifest/resource view if APKTool is unavailable. Inspect the manifest,
minimum/target SDK, exported components, network security configuration, assets,
DEX entry points, JNI bindings and native ABIs. APKID indicators can narrow the
next step; packing/obfuscation does **not** make all static work useless. Strings,
resources, library metadata and loader behavior can remain informative. A
hardcoded-looking credential is a sensitive finding, not permission to use it.

For an extracted native library, LLVM can inspect ELF **without executing it on
macOS**:

```sh
unzip app.apk 'lib/*/*.so' -d extracted
file extracted/lib/arm64-v8a/libexample.so
llvm-readelf --file-header --program-headers --dynamic \
  extracted/lib/arm64-v8a/libexample.so
llvm-nm --dynamic extracted/lib/arm64-v8a/libexample.so
llvm-objdump --disassemble extracted/lib/arm64-v8a/libexample.so
```

Select the ABI/path that actually exists. Recover JNI exports, imports, embedded
configuration and request construction before choosing hooks. Use Ghidra's ELF
loader and the file's real architecture; do not force raw import to fix a parse
error. Android shared libraries depend on Android's loader/bionic and possibly
ART: a Linux guest cannot simply execute every Android ELF either. See
[Linux runtime on a Mac](linux-runtime-on-mac.md).

`d2j-dex2jar` is dex2jar's executable name. APKLeaks can be useful as a secondary
heuristic; confirm findings at call sites, never treat regex output as proof.
Repacking changes the signature and can change behavior. Do not replace your
only original artifact with an instrumented build.

## 2. Decide what needs a runtime

Use an Android emulator or an authorized test device when static evidence cannot
establish runtime behavior. For native Linux processes, use a Linux runtime;
Android app execution needs Android, not just Linux.

The shell supplies Android command tools, **not** an emulator, system image or
SDK license acceptance. Install the SDK separately and review its terms. On
Apple Silicon, prefer a matching ARM64 image if it supplies the app's ABI. Check
minimum SDK, image features and app dependencies before choosing an API level.
A root-capable image is a separate requirement from successful app installation;
verify `adb root` rather than assuming an image permits it.

```sh
adb devices -l
adb shell getprop ro.product.cpu.abilist
adb shell getprop ro.build.version.sdk
```

Pin one selected device with `adb -s SERIAL ...` if more than one is connected.
Do not infer Play Integrity support or app compatibility from successful boot.
Root/emulator detection can prevent an authorized test from progressing; a real
device is an alternative, not a guaranteed bypass.

## 3. Proxy routing and CA trust are separate

First check connectivity and proxy routing using a known test endpoint. Then
check certificate trust. Only then investigate pinning or a custom TLS stack.
In the standard Android Emulator, `10.0.2.2` aliases the host loopback interface;
it is not the proxy address of every physical device or VM.[8]

A disposable emulator with a local proxy listening on port 8080 can use:

```sh
adb shell settings put global http_proxy 10.0.2.2:8080
# Restore the prior setting after the experiment; if there was no proxy:
adb shell settings put global http_proxy :0
```

Some apps ignore this setting; proxy visibility is not proof of observing every
connection. Scope captures to test accounts, store them privately, and remove
installed test CAs when finished.

Apps targeting API 24+ do not trust user-added CAs **by default**, but can opt in
through their network security configuration. Apps targeting API 23 or lower
have a different default. For your own app, a debug-only trust configuration is
preferable to modifying the entire device.[2] Installing a system CA does not
remove application pinning or custom native TLS checks.

### Illustrative legacy system-CA path, not a tested recipe

The API-33-style writable-system workflow from the old notes is image-specific.
`adb root`, remount/verity policy, overlayfs, SELinux labels and reboot persistence
must all be checked. Newer releases may use Conscrypt/APEX CA locations and mount
namespaces, so a file copied to `/system` can be ignored. Do not choose an older
API merely to avoid understanding the app's actual runtime requirements.

If using a compatible disposable image, a DER-exported proxy CA must first be
converted to **PEM**, then named using the legacy subject hash:

```sh
openssl x509 -inform DER -in proxy-ca.der -outform PEM -out proxy-ca.pem
HASH="$(openssl x509 -in proxy-ca.pem -subject_hash_old -noout)"
openssl x509 -in proxy-ca.pem -noout -subject -fingerprint -sha256
# Only after checking root/remount support and avoiding an existing hash collision:
# adb push proxy-ca.pem "/system/etc/security/cacerts/${HASH}.0"
```

This conversion requires OpenSSL, available separately if not on PATH. The
commented push is illustrative: renaming a DER file to `.0` is not conversion;
copying PEM is not proof that the app trusts it. Validate trust in the selected
runtime, not just file presence. Snapshot or use a disposable image before
system-store experiments. Do not disable device security on a daily-use phone.

## 4. Frida only when it answers a specific question

Frida's rooted-device flow uses a server matching the device CPU, with privileged
execution; non-root workflows such as Gadget have different prerequisites.[1]
Do not hardcode a historical version or assume the tools-package version is the
core runtime version. Read it from `frida --version`.

**Illustrative ARM64 server setup** (requires `curl` and `xz`, a root-capable test
device, and review of the selected upstream release):

```sh
FRIDA_VERSION="$(frida --version)"
FRIDA_ARCH=arm64                    # choose from the device's actual ABI
SERVER_BASENAME="frida-server-${FRIDA_VERSION}-android-${FRIDA_ARCH}"
curl --fail --location --output "${SERVER_BASENAME}.xz" \
  "https://github.com/frida/frida/releases/download/${FRIDA_VERSION}/${SERVER_BASENAME}.xz"
unxz "${SERVER_BASENAME}.xz"
mv "${SERVER_BASENAME}" frida-server  # decompression retains the versioned basename
adb root                            # if unsupported, stop and use the device's reviewed root flow
adb push frida-server /data/local/tmp/frida-server
adb shell 'chmod 755 /data/local/tmp/frida-server'
adb shell '/data/local/tmp/frida-server >/data/local/tmp/frida-server.log 2>&1 &'
frida-ps -U
```

Select a single device; verify the server starts and the process list works before
loading hooks. Review every script you inject. A Java TLS hook is not a universal
bypass for Flutter, native C/C++, custom transports or anti-instrumentation.
Choose the actual request/signing/TLS boundary supported by the static findings.

Objection is omitted from standard shells. The
[shell guide](../README.md) documents a separate opt-in Linux command requiring
explicit SDK license consent; it is not tested here and does not fix Darwin.

## Record the result

Keep artifact hashes, ABI/API, tool versions, static call-site references,
observed requests, redacted test-account context and unresolved questions. Label
an endpoint found in strings differently from a request observed at runtime.
Do not call authentication or signing understood until the relevant flow is
verified. No APK, captures or target details are added to this repository.

This guide corrects the old `android-api-re.md` note's absolute packing claims,
CA encoding/trust assumptions and mismatched Frida download/push basename.

[Shells](../README.md) · [iOS research](ios-re.md)

## Sources

[1] https://frida.re/docs/android
[2] https://developer.android.com/privacy-and-security/security-config
[8] https://developer.android.com/studio/run/emulator-networking-address