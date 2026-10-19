# Evaluation-only contracts: force shell derivations without building their tools.
{
  pkgs,
  catalog,
  shells,
}:
let
  inherit (pkgs) lib;
  system = pkgs.stdenv.hostPlatform.system;
  expected = [
    "all"
    "android"
    "android-re"
    "default"
    "dynamic"
    "host-tools"
    "ios"
    "kernel"
    "offsec"
    "re"
    "toolchain"
    "tracing"
  ];
  names = packages: map (p: p.pname or p.name) packages;
  androidNames = names catalog.categories.android;
  analysisNames = names shells.android-re.nativeBuildInputs;
  derivations = lib.mapAttrs (_: shell: shell.drvPath) shells;
  supportedPackages = import ../pkgs { inherit pkgs; };
in
assert builtins.attrNames shells == lib.sort builtins.lessThan expected;
assert builtins.all (
  shell:
  lib.hasInfix "export RESEARCH_WORKSPACE=" shell.shellHook
  && lib.hasInfix "$HOME/workspace" shell.shellHook
) (builtins.attrValues (lib.filterAttrs (name: _: name != "default") shells));
assert builtins.all (name: builtins.elem name analysisNames) [
  "jadx"
  "frida-tools"
  "llvm"
  "ripgrep"
  "file"
];
assert !(builtins.elem "objection" androidNames);
assert builtins.elem "gnupg" (names catalog.categories.offsec);
assert builtins.all (name: builtins.elem name (names catalog.categories.ios)) [
  "python3"
  "libusbmuxd"
];
# Focused CLI analysis must not pull the optional Quark analytics integration.
assert builtins.all (
  p: (p.pname or "") != "jadx" || !(p.quarkIntegration or true)
) shells.android-re.nativeBuildInputs;
assert system != "aarch64-linux" || !(builtins.elem "apktool" androidNames);
assert system == "aarch64-darwin" || !(supportedPackages ? palera1n);
assert builtins.all (record: record.reason != "") catalog.manifest.android.omitted;
assert builtins.all (
  shell:
  let
    paths = map (p: p.drvPath) shell.nativeBuildInputs;
  in
  paths == lib.unique paths
) (builtins.attrValues shells);
builtins.deepSeq derivations {
  inherit system derivations;
  inherit (catalog) manifest;
}
