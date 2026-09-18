# Local fixes for upstream nixpkgs defects, applied to every host in the fleet.
{
  nixpkgs.overlays = [
    (
      final: prev:
      let
        # Both pynfsclient and bloodhound-py have defective metadata checks
        # in this nixpkgs pin (nixpkgs e2587ca, 2026-07-23).
        # - pynfsclient 1.0.6 wheel METADATA says 0.1.5
        # - bloodhound-py package name discovery fails in importlib.metadata
        # Both cause pythonMetadataCheckPhase to abort.
        #
        # Note: netexec's package.nix has its own internal python.override with
        # its own packageOverrides, which clobbers overrides on python312Packages.
        # By wrapping python312.override, we ensure our fixes compose properly.
        applyPythonPatches = super: {
          pynfsclient = super.pynfsclient.overridePythonAttrs (_: {
            dontCheckPythonMetadata = true;
          });
          bloodhound-py = super.bloodhound-py.overridePythonAttrs (_: {
            dontCheckPythonMetadata = true;
          });
        };

        pythonWithPatch = final.python312.override {
          packageOverrides = self: super: applyPythonPatches super;
        };

        pythonWrapper = pythonWithPatch // {
          override =
            args:
            let
              ourPO = self: super: applyPythonPatches super;
              theirPO = args.packageOverrides or (self: super: { });
            in
            pythonWithPatch.override (
              builtins.removeAttrs args [ "packageOverrides" ]
              // {
                packageOverrides = self: super: (ourPO self super) // (theirPO self (super // (ourPO self super)));
              }
            );
        };
      in
      {
        python312Packages = prev.python312Packages.override {
          overrides = self: super: applyPythonPatches super;
        };
        netexec = prev.netexec.override { python312 = pythonWrapper; };

        # mitmproxy 12.2.3 requires msgpack<=1.1.2,>=1.0.0, but nixpkgs upgraded
        # msgpack to 1.2.1, causing pythonRuntimeDepsCheckHook to fail.
        # Disable runtime deps check for mitmproxy.
        mitmproxy = prev.mitmproxy.overridePythonAttrs (_: {
          dontCheckRuntimeDeps = true;
        });
      }
    )
  ];
}
