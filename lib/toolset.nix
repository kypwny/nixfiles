# Categorized research toolset — the "tansu" collection.
#
# Shape borrowed from redcode-labs/RedNix: define the tools once, derive
# everything else from that definition (RedNix does it in `packages.nix` +
# `shells/default.nix`, and reuses the same shape for its container).
# One definition, three consumers here:
#
#   * flake.nix                   -> devShells `.#all`, `.#re`, `.#kernel`, …
#                                    one plainly-named shell per category
#   * modules/darwin/research.nix -> yoru's environment.systemPackages
#   * hosts/navi/kernel-dev.nix   -> navi's kernel-side packages
#
# Difference from RedNix: it pins supportedSystems to ["x86_64-linux"], so its
# categories can list Linux-only tools freely. This fleet is mixed
# (aarch64-darwin + x86_64-linux), so every category is filtered through
# lib.meta.availableOn. That reads only `meta`, never the derivation, so a tool
# the current host cannot build is dropped before instantiation instead of
# aborting evaluation of the whole shell. A hand-written list is exactly how
# `ubootTools` broke the first version of the tansu shell on darwin.
{
  pkgs,
  lib,
  outputs ? null,
}:

let
  inherit (pkgs.stdenv) hostPlatform;

  # Packages whose own meta claims they are available here, but which still fail
  # to build on darwin. Named explicitly so the exception is visible rather than
  # a mystery. All build on Linux (i.e. aku/navi):
  #   mitmproxy — fails to build on aarch64-darwin (a python dependency is not
  #               available there).
  #   objection — the frida-based mobile toolkit; no darwin build. venv-install
  #               it on the Mac if needed.
  #   netexec   — meta.broken = isDarwin upstream, so it is only ever meant for
  #               Linux hosts. Note: on Linux its pynfsclient dependency has a
  #               METADATA version bug; fixed fleet-wide by
  #               modules/shared/overlays.nix, not blocked here.
  # Verified by building the entire darwin set with `nix build --keep-going`.
  hostBlocked = lib.optionals pkgs.stdenv.isDarwin [
    "mitmproxy"
    "netexec"
    "objection"
  ];

  # Drop anything this host can't build: wrong platform (Linux-only tools on
  # darwin and vice versa), marked broken, or on the block-list above. Reading
  # `meta` never instantiates the derivation, so this is safe to run over a list
  # containing packages the host cannot build — which is the whole point.
  avail = builtins.filter (
    p:
    lib.meta.availableOn hostPlatform p
    && !(p.meta.broken or false)
    && !(builtins.elem (p.pname or p.name or "") hostBlocked)
  );

  # Binaries with no nixpkgs attribute; pinned in pkgs/ and exposed as
  # flake `packages.<system>.<name>`. palera1n is darwin-only, so on Linux this
  # list is empty and `avail` never sees it.
  pinned =
    if outputs != null && outputs ? packages then
      avail [ outputs.packages.${hostPlatform.system}.palera1n ]
    else
      [ ];

  categories = {
    # GNU tools the Linux kernel's Kbuild invokes by name. macOS ships BSD
    # equivalents that misparse kernel makefiles. Deliberately NOT part of
    # systemPackages: shadowing BSD sed/coreutils system-wide is a bad trade,
    # so these stay inside the tansu shells.
    host-tools = avail (
      with pkgs;
      [
        gnumake
        gnused
        gnugrep
        gawk
        gnupatch
        gnutar
        findutils
        coreutils
        gzip
        bzip2
        xz
        zstd
        lz4
        cpio
        bc
        flex
        bison
        perl
        python3
        rsync
        file
        which
        ccache
      ]
    );

    # static analysis / reversing.
    # cutter (the rizin GUI) is deliberately absent: on darwin it drags in
    # qtwebengine-6.11.1 built from source — hours of compilation, for a GUI
    # wrapper around rizin, which is already here. `nix shell nixpkgs#cutter`
    # if you ever want it without putting it in every switch.
    re = avail (
      with pkgs;
      [
        ghidra
        radare2
        rizin
        binwalk
        imhex
        capstone
        jadx
        libplist
      ]
    );

    # dynamic instrumentation + hardware debug
    dynamic = avail (
      with pkgs;
      [
        frida-tools
        python3Packages.pwntools
        gdb
        openocd # JTAG via the CH347
        socat
        libusb1
      ]
    );

    # iOS / bootchain. Everything here works on macOS; palera1n is pinned.
    ios =
      avail (
        with pkgs;
        [
          ldid
          ipsw
          libimobiledevice
        ]
      )
      ++ pinned;

    # Android tooling for mobile API work: the static half plus the adb side.
    # The emulator itself is not here — Google's SDK does not nix-package usefully
    # (system images are vendor downloads), so it comes from the
    # android-commandlinetools cask. See ~/tansu/notes/android-api-re.md.
    android = avail (
      with pkgs;
      [
        android-tools # adb, fastboot
        apktool # decode/rebuild resources + smali
        apksigner # sign a repackaged APK
        dex2jar
        apkid # packer/obfuscator detection — run this FIRST
        apkleaks # hunt hardcoded endpoints, keys, secrets
        jadx # decompile to Java (also in `re`)
        scrcpy # mirror a physical device over adb
        jdk # raw jar/bytecode work; apktool and jadx ship their own JRE
        objection # filtered on darwin — see hostBlocked
      ]
    );

    # cross toolchain. Kept out of `system`: installing nix's clang/ld.lld into
    # systemPackages shadows Apple's clang on PATH, which would break Xcode and
    # every iOS/macOS build. It lives in the shells instead.
    # `clang` is listed separately on purpose: pkgs.llvm ships the llvm-* tools
    # (llvm-objcopy/ar/nm/objdump) but NOT a clang binary.
    toolchain = avail (
      with pkgs;
      [
        clang
        llvm
        lld
        clang-tools
        ccache
      ]
    );

    # kernel-side: board tooling + source navigation.
    # ubootTools and pahole have no darwin build, so they appear only on Linux.
    kernel = avail (
      with pkgs;
      [
        dtc
        ubootTools # mkimage
        pahole # BTF
        qemu
        universal-ctags
        cscope
        bear
      ]
    );

    # tracing / observability (mostly Linux; on darwin use dtrace/ktrace/kdebug).
    # perf is deliberately absent: it must match the running kernel, so each host
    # adds its own (navi uses linuxPackages_latest.perf, matching kernel.nix).
    tracing = avail (
      with pkgs;
      [
        bpftrace
        sysdig
        trace-cmd
        bcc
        strace
        ltrace
        tcpdump
        wireshark-cli
      ]
    );

    # offensive tooling. Most of this is Linux-only: it lands on navi, not yoru.
    # Burp Suite is already a cask; this is the CLI side.
    #
    # This is also the HackTheBox shell: `nix develop .#offsec` gives you the
    # plumbing (openvpn/tmux/rlwrap), the web fuzzers, and the Windows/AD staples
    # (samba's smbclient, evil-winrm, kerbrute, certipy, pypykatz, bloodhound).
    offsec = avail (
      with pkgs;
      [
        nmap
        masscan
        rustscan
        sqlmap
        ffuf
        feroxbuster
        gobuster
        nuclei
        nikto
        whatweb
        gowitness
        hydra
        john
        hashcat
        exploitdb
        aircrack-ng
        bettercap
        mitmproxy
        proxychains-ng
        netcat-gnu
        python3Packages.impacket
        seclists
        # rockyou is NOT inside the SecLists package (upstream strips it); it is a
        # separate derivation here. Exported as $ROCKYOU by the shell.
        rockyou
        # wordlists package is completely broken upstream across Python 3.14 (wfuzz imports removed pkg_resources).
        # seclists and rockyou provide everything needed.
        smbmap
        enum4linux
        responder
        metasploit
        # BloodHound. Two of the three pieces, deliberately:
        #   bloodhound     legacy app — x86_64-linux only, so navi only
        #   bloodhound-ce  the CE server — linux-only, so aku/navi
        #   bloodhound-py  EXCLUDED: it is packaging-broken in this nixpkgs pin —
        #                  it fails its own `importlib.metadata` check on every
        #                  platform, so it would break aku's first build. Collect
        #                  with `nxc ldap --bloodhound` on Linux, or venv-pip
        #                  bloodhound on the Mac if you must.
        bloodhound
        bloodhound-ce
        # --- HTB / AD workflow ---
        openvpn # the lab VPN (5.5) — the part that most guides assume you have
        tmux # persistent sessions across a long box
        rlwrap # arrow keys in a reverse-shell listener
        samba # smbclient, for SMB enumeration and file pulls
        evil-winrm # WinRM shells on Windows boxes
        kerbrute # user enumeration and password spraying over Kerberos
        certipy # ADCS abuse, which is most modern HTB AD chains
        python3Packages.pypykatz # parse lsass dumps without Windows
        netexec # filtered out on darwin — see hostBlocked
      ]
    );
  };
in
categories
// {
  # <elf.h> as an isolated include directory.
  #
  # macOS ships no elf.h, but the Linux kernel's host tools (scripts/sorttable,
  # scripts/elf-parse, scripts/basic/fixdep) include it. glibc's elf.h is
  # self-contained — it includes only <stdint.h> — so extracting that one header
  # is safe. Pointing HOSTCFLAGS at glibc's whole include dir instead hijacks host
  # compiles: <sys/types.h> resolves to glibc, which then demands gnu/stubs-32.h.
  #
  # Exported by the shells as KBUILD_ELF_INCLUDE and consumed by kbuild.sh.
  elfHeaders = pkgs.runCommand "elf-headers" { } ''
    mkdir -p $out/include
    cp ${pkgs.pkgsCross.gnu64.glibc.dev}/include/elf.h $out/include/elf.h
  '';

  # Everything, deduplicated: libplist and tcpdump appear in several categories.
  all = lib.unique (lib.flatten (lib.attrValues categories));

  # What belongs in systemPackages: no host-tools (they must not shadow the BSD
  # userland outside a build shell) and no toolchain (must not shadow Apple's
  # clang). Both stay available inside `nix develop .#tansu`.
  system = lib.unique (
    lib.flatten [
      categories.re
      categories.dynamic
      categories.ios
      categories.kernel
    ]
  );
}
