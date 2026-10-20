{
  config,
  pkgs,
  identity,
  lib,
  ...
}:
let
  secretiveAgent = "${config.home.homeDirectory}/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh";

  # Upstream nixpkgs marked dino broken on aarch64-darwin
  dino-unwrapped = pkgs.dino.overrideAttrs (old: {
    doCheck = false;
    meta = (old.meta or { }) // {
      broken = false;
    };
  });

  dino-app = pkgs.stdenv.mkDerivation {
    pname = "dino-app";
    inherit (dino-unwrapped) version;

    nativeBuildInputs = [
      pkgs.imagemagick
      pkgs.libicns
    ];

    phases = [ "installPhase" ];

    installPhase = ''
      mkdir -p $out/Applications/Dino.app/Contents/MacOS
      mkdir -p $out/Applications/Dino.app/Contents/Resources

      magick -background none ${dino-unwrapped}/share/icons/hicolor/scalable/apps/im.dino.Dino.svg \
        -define icon:auto-resize=16,32,64,128,256,512,1024 \
        icon.png
      png2icns $out/Applications/Dino.app/Contents/Resources/Dino.icns icon.png

      cat << 'EOF' > $out/Applications/Dino.app/Contents/Info.plist
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>CFBundleExecutable</key>
        <string>Dino</string>
        <key>CFBundleIconFile</key>
        <string>Dino</string>
        <key>CFBundleIdentifier</key>
        <string>im.dino.Dino</string>
        <key>CFBundleName</key>
        <string>Dino</string>
        <key>CFBundlePackageType</key>
        <string>APPL</string>
        <key>CFBundleShortVersionString</key>
        <string>${dino-unwrapped.version}</string>
        <key>LSMinimumSystemVersion</key>
        <string>11.0</string>
        <key>NSHighResolutionCapable</key>
        <true/>
      </dict>
      </plist>
      EOF

      cat << EOF > $out/Applications/Dino.app/Contents/MacOS/Dino
      #!/bin/sh
      export XDG_DATA_DIRS="${pkgs.adwaita-icon-theme}/share:\$XDG_DATA_DIRS"
      exec ${dino-unwrapped}/bin/dino "\$@"
      EOF
      chmod +x $out/Applications/Dino.app/Contents/MacOS/Dino
    '';
  };
in
{
  imports = [
    ./default.nix
    ./ghostty.nix
  ];

  # macOS-specific home-manager additions
  home.packages = [
    dino-app
    pkgs.secretive
    pkgs.hcli
    pkgs.linecast
    # Prism Launcher uses this JDK for current Minecraft releases.
    pkgs.jdk21
  ];

  # Prism 11 scans ~/Library/Java/JavaVirtualMachines for JDK bundles.  Link
  # nixpkgs' macOS bundle there so Finder/Launchpad launches discover it too;
  # shell-only JAVA_HOME/PATH configuration would not reach those GUI launches.
  # A home.file key cannot retain Nix store context; only the derived bundle name
  # drops it, while the source stays a store path and therefore remains GC-rooted.
  home.file."Library/Java/JavaVirtualMachines/${builtins.baseNameOf (builtins.unsafeDiscardStringContext pkgs.jdk21.bundle)}".source =
    pkgs.jdk21.bundle;

  home.sessionVariables.PRISMLAUNCHER_JAVA_PATHS = "${pkgs.jdk21}/bin/java";

  # Secretive (Secure Enclave) SSH key named `yoru`, created in Secretive.app.
  # The private half never leaves the enclave; only the public half is declared
  # here (identity.sshKeys.yoruEcdsa).
  home.file.".ssh/yoru.pub".text = "${identity.sshKeys.yoruEcdsa}\n";

  # The Secure Enclave key is for machines on the tailnet (today: kura), the
  # Forgejo at git.tilde.horse, which only trusts this key, and plate (OpenBSD,
  # root, no file-key fallback). Everything else (GitHub, tilde.horse, other
  # root hosts) keeps its file keys from home/default.nix.
  # On kura ~/.ssh/ky stays second as a fallback, because an enclave key cannot
  # be backed up and dies with this Mac.
  programs.ssh.settings.kura = {
    identityAgent = secretiveAgent;
    identityFile = lib.mkForce [
      "~/.ssh/yoru.pub"
      "~/.ssh/ky"
    ];
  };
  programs.ssh.settings."git.tilde.horse" = {
    identityAgent = secretiveAgent;
    identityFile = lib.mkForce "~/.ssh/yoru.pub";
  };
  # plate.odin.slowservers.net. Its authorized_keys (managed by hand, not by
  # this flake) holds yoruEcdsa and yoruLogin only.
  programs.ssh.settings.plate = {
    hostname = "142.249.45.39";
    user = "root";
    identitiesOnly = true;
    identityAgent = secretiveAgent;
    identityFile = "~/.ssh/yoru.pub";
  };

  # Sign git commits with the Secure Enclave key. ssh-keygen only consults
  # $SSH_AUTH_SOCK (the Apple-launched agent), which cannot see Secretive keys,
  # so git signs through a wrapper that points it at Secretive's socket.
  # Verification trusts both keys via ~/.ssh/allowed_signers (home/default.nix).
  programs.git.settings.user = lib.mkForce (identity.git // { signingkey = "~/.ssh/yoru.pub"; });
  programs.git.settings.gpg.ssh.program =
    lib.mkForce "${pkgs.writeShellScriptBin "ssh-keygen-secretive" ''
      export SSH_AUTH_SOCK="$HOME/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh"
      exec /usr/bin/ssh-keygen "$@"
    ''}/bin/ssh-keygen-secretive";

  # Keep GnuPG policy declarative while leaving the mutable keyring in ~/.gnupg.
  # The copied config files are replaced by Home Manager with equivalent settings.
  programs.gpg = {
    enable = true;
    settings = {
      auto-key-locate = "local";
      cert-digest-algo = "SHA512";
      default-key = "ky@tilde.horse";
      default-preference-list = "SHA512 SHA384 SHA256 SHA224 AES256 AES192 AES CAST5 BZIP2 ZLIB ZIP Uncompressed";
      display-charset = "utf-8";
      fixed-list-mode = true;
      keyid-format = "0xlong";
      keyserver = "hkps://keys.openpgp.org";
      list-options = "show-uid-validity";
      no-comments = true;
      no-emit-version = true;
      no-symkey-cache = true;
      personal-cipher-preferences = "AES256 AES192 AES";
      personal-compress-preferences = "ZLIB BZIP2 ZIP Uncompressed";
      personal-digest-preferences = "SHA512 SHA384 SHA256 SHA224";
      require-cross-certification = true;
      s2k-cipher-algo = "AES256";
      s2k-digest-algo = "SHA512";
      verify-options = "show-uid-validity";
      with-fingerprint = true;
    };
    dirmngrSettings = {
      keyserver = "hkps://keys.openpgp.org";
    };
  };

  # Replace the copied text configs with the declarative equivalents above;
  # leave private keys, public keyring and trust database untouched.
  home.file."${config.home.homeDirectory}/.gnupg/gpg.conf".force = true;
  home.file."${config.home.homeDirectory}/.gnupg/dirmngr.conf".force = true;

  targets.darwin.defaults."com.brave.Browser" = {
    # Brave features
    BraveRewardsDisabled = true;
    BraveAIChatEnabled = false;

    # Password management (using Proton Pass)
    PasswordManagerEnabled = false;
    PasswordLeakDetectionEnabled = false;

    # Autofill
    AutoFillEnabled = false;
    AutofillAddressEnabled = false;
    AutofillCreditCardEnabled = false;
    PaymentMethodQueryEnabled = false;
  };
}
