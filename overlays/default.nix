# Pure package fixes shared by system modules and portable shells.
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
  applyPythonPatches = _pythonFinal: super: {
    pynfsclient = super.pynfsclient.overridePythonAttrs (_: {
      dontCheckPythonMetadata = true;
    });
    bloodhound-py = super.bloodhound-py.overridePythonAttrs (_: {
      dontCheckPythonMetadata = true;
    });
    psutil = super.psutil.overridePythonAttrs (old: {
      disabledTests = (old.disabledTests or [ ]) ++ [ "test_heap_info" ];
    });

    # The pinned AnyIO 4.14.2/Linux suite has four reproducible TLS fixture
    # failures plus intermittent asyncio/uvloop resource-leak failures. Skip
    # only the six observed pytest node IDs; runtime code is unchanged.
    anyio = super.anyio.overridePythonAttrs (old: {
      disabledTestPaths =
        (old.disabledTestPaths or [ ])
        ++ final.lib.optionals final.stdenv.hostPlatform.isLinux [
          "tests/streams/test_tls.py::test_tls_connectable[asyncio]"
          "tests/streams/test_tls.py::test_tls_connectable[asyncio+uvloop]"
          "tests/streams/test_tls.py::test_tls_connectable[asyncio+eager]"
          "tests/streams/test_tls.py::test_tls_connectable[trio]"
          "tests/test_itertools.py::TestCombinations::test_checkpoints_after_first_result[asyncio+uvloop]"
          "tests/test_from_thread.py::TestBlockingPortal::test_from_async[asyncio+uvloop-asyncio]"
        ];
    });

    # These both use mypy only for optional build/test machinery. On
    # akuma (8 GiB RAM), mypy's mypyc compilation reaches ~7 GiB and is
    # OOM-killed; the pure-Python charset detector and typeguard runtime
    # behavior are unchanged.
    charset-normalizer = super.charset-normalizer.override { withMypyc = false; };
    typeguard = super.typeguard.overridePythonAttrs (_: {
      # Nixpkgs builds an unused Sphinx documentation output, whose
      # type-hints extension pulls mypy even when checks are disabled.
      outputs = [ "out" ];
      "build-system" = [
        final.glibcLocales
        super.setuptools
        super.setuptools-scm
      ];
      nativeCheckInputs = [ ];
    });
    markdown-it-py = super.markdown-it-py.overridePythonAttrs (_: {
      # Its regression-test fixture pulls Pillow, Sphinx and another
      # Python/mypy stack. Runtime only needs mdurl.
      doCheck = false;
      nativeCheckInputs = [ ];
    });
    tqdm = super.tqdm.overridePythonAttrs (_: {
      # Its optional-feature tests pull NumPy, Pandas, Rich and tkinter;
      # none are needed by minikerberos at runtime.
      doCheck = false;
      nativeCheckInputs = [ ];
    });
    asn1tools = super.asn1tools.overridePythonAttrs (_: {
      # Its optional cache/shell extras are test fixtures, not runtime
      # requirements of aardwolf's ASN.1 encoder/decoder.
      doCheck = false;
      nativeCheckInputs = [ ];
    });
  };

  pythonWithPatch = final.python312.override {
    packageOverrides = applyPythonPatches;
  };

  pythonWrapper = pythonWithPatch // {
    override =
      args:
      let
        theirPO = args.packageOverrides or (_: _: { });
      in
      pythonWithPatch.override (
        builtins.removeAttrs args [ "packageOverrides" ]
        // {
          packageOverrides =
            self: super:
            (applyPythonPatches self super) // (theirPO self (super // (applyPythonPatches self super)));
        }
      );
  };
in
{
  python312Packages = prev.python312Packages.override {
    overrides = applyPythonPatches;
  };
  netexec = prev.netexec.override { python312 = pythonWrapper; };

  # mitmproxy 12.2.3 requires msgpack<=1.1.2,>=1.0.0, but nixpkgs upgraded
  # msgpack to 1.2.1, causing pythonRuntimeDepsCheckHook to fail.
  # Disable runtime deps check for mitmproxy.
  mitmproxy = prev.mitmproxy.overridePythonAttrs (_: {
    dontCheckRuntimeDeps = true;
  });

  # ltrace test suite fails in sandbox/VM environments; binary is fine.
  ltrace = prev.ltrace.overrideAttrs { doCheck = false; };

}
// prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
  # libtiff's bundled Sphinx manual is not required by any fleet runtime.
  # Skipping it prevents Pillow (needed by NetExec's RDP support) from
  # pulling a second Python/mypy toolchain into the akuma closure.
  # Linux only: on yoru it would change the hash of everything above libtiff
  # (fonts, cairo, gobject-introspection, gdk-pixbuf, pango, Pillow) and force
  # all of it to build locally instead of coming from cache.nixos.org.
  libtiff = prev.libtiff.overrideAttrs (old: {
    outputs = builtins.filter (output: output != "doc" && output != "man") old.outputs;
    nativeBuildInputs = builtins.filter (pkg: pkg != prev.sphinx) old.nativeBuildInputs;
    cmakeFlags = (old.cmakeFlags or [ ]) ++ [
      "-Dtiff-docs=OFF"
      "-Dtiff-tests=OFF"
    ];
    doCheck = false;
  });
}
