# Upstream build breakages that block navi's closure, patched narrowly so the
# rest of the package set still comes from cache.nixos.org. Re-check each entry
# on nixpkgs bumps and delete it once the upstream package builds again.
_: {
  nixpkgs.overlays = [
    (_final: prev: {
      # The test suite fails in the sandbox (15 unexpected failures) and
      # Hydra has no cached build either; the binary itself is fine.
      ltrace = prev.ltrace.overrideAttrs { doCheck = false; };

      # move-transition builds with -Werror and obs-studio 32.x marked
      # obs_properties_add_button deprecated. NIX_CFLAGS_COMPILE is appended
      # after the project's own flags, so the downgrade wins.
      obs-studio-plugins = prev.obs-studio-plugins // {
        obs-move-transition = prev.obs-studio-plugins.obs-move-transition.overrideAttrs (old: {
          env = (old.env or { }) // {
            NIX_CFLAGS_COMPILE = "${old.env.NIX_CFLAGS_COMPILE or ""} -Wno-error=deprecated-declarations";
          };
        });
      };
    })
  ];
}
