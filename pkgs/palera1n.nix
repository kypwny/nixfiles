# palera1n — checkm8-based jailbreak for A11 (iPhone X) and earlier.
#
# Why this lives here instead of Homebrew/nixpkgs:
#   * no `palera1n` Homebrew cask exists
#   * no `palera1n` attribute in nixpkgs
#   * the `checkra1n` cask is disabled by Homebrew (fails the Gatekeeper check)
# Pinning the release asset keeps it reproducible and, unlike a hand-download
# into ~/Applications, it survives `homebrew.onActivation.cleanup = "zap"`.
#
# Tools are mark_license: upstream palera1n is MIT.
{
  lib,
  stdenv,
  fetchurl,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "palera1n";
  version = "2.4";

  src = fetchurl {
    url = "https://github.com/palera1n/palera1n/releases/download/v${finalAttrs.version}/palera1n-macos-arm64";
    hash = "sha256-lQw1e2rl3zYSj25Co8bTceVa62mlr83idvCWJ2IQ0Mk=";
  };

  # Single prebuilt Mach-O, nothing to unpack.
  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 "$src" "$out/bin/palera1n"
    runHook postInstall
  '';

  meta = {
    description = "Checkm8-based jailbreak for A11 and older iOS devices";
    longDescription = ''
      Rootless jailbreak for checkm8-vulnerable devices (A11 and earlier).
      The on-device companion binary is published alongside this one as
      palera1n-iphoneos-arm64; the host binary here runs the DFU/bootchain
      half from macOS.
    '';
    homepage = "https://palera.in";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [
      "aarch64-darwin"
      "x86_64-darwin"
    ];
    mainProgram = "palera1n";
  };
})
