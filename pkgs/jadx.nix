# Upstream's hash-pinned Java distribution, without nixpkgs' optional Quark stack.
# Standard decompilation/GUI work is retained; Quark analysis remains opt-in via nixpkgs#jadx.
{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  unzip,
  jre,
  coreutils,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "jadx";
  version = "1.5.6";
  src = fetchurl {
    url = "https://github.com/skylot/jadx/releases/download/v${finalAttrs.version}/jadx-${finalAttrs.version}.zip";
    hash = "sha256-VF6ivpwkJRG8FFdVz0vaJIWt5Clm4Jb4tNPaKiMOiXQ=";
  };
  sourceRoot = ".";
  nativeBuildInputs = [
    makeWrapper
    unzip
  ];
  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/jadx $out/bin
    cp -R bin lib LICENSE README.md $out/share/jadx/
    for program in jadx jadx-gui; do
      chmod +x $out/share/jadx/bin/$program
      makeWrapper $out/share/jadx/bin/$program $out/bin/$program \
        --set JAVA_HOME ${jre} \
        --prefix PATH : ${
          lib.makeBinPath [
            jre
            coreutils
          ]
        }
    done
    runHook postInstall
  '';
  passthru.quarkIntegration = false;
  meta = {
    description = "JADX upstream distribution without optional Quark analytics dependencies";
    homepage = "https://github.com/skylot/jadx";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.binaryBytecode ];
    platforms = lib.platforms.unix;
    mainProgram = "jadx";
  };
})
