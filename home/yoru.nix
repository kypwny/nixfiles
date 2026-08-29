{ pkgs, ... }:
let
  dino-unwrapped = pkgs.dino.overrideAttrs (_: {
    doCheck = false;
  });

  dino-app = pkgs.stdenv.mkDerivation {
    pname = "dino-app";
    version = dino-unwrapped.version;

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

      cat << 'EOF' > $out/Applications/Dino.app/Contents/MacOS/Dino
      #!/bin/sh
      exec ${dino-unwrapped}/bin/dino "$@"
      EOF
      chmod +x $out/Applications/Dino.app/Contents/MacOS/Dino
    '';
  };
in
{
  imports = [
    ./default.nix
  ];

  # macOS-specific home-manager additions
  home.packages = [
    dino-app
  ];
}
