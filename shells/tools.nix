# One research catalog for devShells and optional host installation policies.
# Metadata filtering is not a build guarantee; transitive exceptions are explicit.
{
  pkgs,
  lib ? pkgs.lib,
}:
let
  inherit (pkgs.stdenv) hostPlatform;
  offsecPython = pkgs.python3.withPackages (
    ps: with ps; [
      requests
      cryptography
      pwntools
    ]
  );
  customPackages = import ../pkgs { inherit pkgs; };
  blocked = {
    # The Linux package pulls an Android SDK requiring a separate license opt-in.
    # Darwin also has unsupported dependencies. Do not accept agreements silently.
    objection = "Optional Android SDK license/dependency requirements; see shells/docs/android-re.md.";
  }
  // lib.optionalAttrs hostPlatform.isDarwin {
    mitmproxy = "Known unsupported Darwin Python dependency in this pin; use a Linux runtime.";
    netexec = "Upstream marks NetExec broken on Darwin; use a Linux runtime.";
  }
  // lib.optionalAttrs (hostPlatform.system == "aarch64-linux") {
    apktool = "APKTool wraps AAPT2, whose prebuilt Linux binary is x86_64-only in this pin.";
  };
  packageName = p: p.pname or (lib.getName p);
  exclusion =
    p:
    let
      name = packageName p;
    in
    if builtins.hasAttr name blocked then
      blocked.${name}
    else if !(lib.meta.availableOn hostPlatform p) then
      "Not supported on ${hostPlatform.system} by upstream package metadata."
    else if p.meta.broken or false then
      "Marked broken by upstream package metadata."
    else
      null;
  available = packages: lib.unique (builtins.filter (p: exclusion p == null) packages);
  raw = with pkgs; {
    # GNU userland and compiler tools stay in shells, never globally shadowing macOS.
    host-tools = [
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
    ];
    # Cutter deliberately stays opt-in: its QtWebEngine closure is expensive on Darwin.
    re = [
      ghidra
      radare2
      rizin
      binwalk
      imhex
      capstone
      unicorn
      jadx
      libplist
    ];
    dynamic = [
      frida-tools
      python3Packages.pwntools
      gdb
      openocd
      socat
      libusb1
    ];
    ios = [
      ldid
      ipsw
      libimobiledevice
      libusbmuxd # iproxy for the explicitly invoked device SSH helper.
      python3 # Path validation and firmware manifests in the curated helpers.
    ]
    ++ lib.optional (customPackages ? palera1n) customPackages.palera1n;
    # The emulator/system images are separately installed vendor runtime components.
    android = [
      android-tools
      apktool
      apksigner
      dex2jar
      apkid
      apkleaks
      jadx
      scrcpy
      jdk
      objection
    ];
    # llvm contains llvm-* utilities, not clang itself.
    toolchain = [
      clang
      llvm
      lld
      clang-tools
      ccache
    ];
    kernel = [
      dtc
      ubootTools
      pahole
      qemu
      universal-ctags
      cscope
      bear
    ];
    # perf must be chosen by the host, rather than this portable catalog.
    tracing = [
      bpftrace
      sysdig
      trace-cmd
      bcc
      strace
      ltrace
      tcpdump
      wireshark-cli
    ];
    offsec = [
      gnupg
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
      rockyou
      smbmap
      enum4linux
      responder
      metasploit
      bloodhound-ce
      openvpn
      tmux
      rlwrap
      samba
      evil-winrm
      kerbrute
      certipy
      python3Packages.pypykatz
      offsecPython
      jdk
      curl
      jq
      netexec
    ];
  };
  rawShells = raw // {
    # Filter before derivation equality/deduplication: equality can force outPath
    # and instantiate unsupported or license-gated packages.
    all = lib.flatten (lib.attrValues raw);
    # Focused CLI APK/ELF work. Heavy GUIs, Quark, device mirroring and hardware
    # debug remain in the broad categories; the JVM distribution is hash-pinned.
    android-re =
      (with pkgs; [
        android-tools
        apktool
        apksigner
        dex2jar
        apkid
        frida-tools
        radare2
        rizin
        llvm
        ripgrep
        file
        unzip
        jq
      ])
      ++ [ customPackages.jadx ];
  };
  categories = lib.mapAttrs (_: available) rawShells;
in
{
  inherit categories offsecPython;
  manifest = lib.mapAttrs (_: packages: {
    included = map packageName (available packages);
    omitted = lib.unique (
      map (p: {
        name = packageName p;
        reason = exclusion p;
      }) (builtins.filter (p: exclusion p != null) packages)
    );
  }) rawShells;

  # Existing host policy retained separately from portable shell selection.
  system = lib.unique (categories.re ++ categories.dynamic ++ categories.ios ++ categories.kernel);

  # Isolate elf.h: adding glibc's full include directory breaks native Darwin tools.
  elfHeaders = pkgs.runCommand "elf-headers" { } ''
    mkdir -p $out/include
    cp ${pkgs.pkgsCross.gnu64.glibc.dev}/include/elf.h $out/include/elf.h
  '';
}
