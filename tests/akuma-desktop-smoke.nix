# Native aarch64 test: build on akuma, without activating its system.
{ flake }:
let
  host = flake.nixosConfigurations.akuma;
  p = host.pkgs;
  h = host.config.home-manager.users.ky;
  bitmap = "-inesw-Cozette-Medium-R-Normal--13-120-75-75-M-60-ISO10646-1";
in
p.runCommand "akuma-i3-smoke"
  {
    nativeBuildInputs = with p; [
      i3
      xorg-server
      xterm
      xrdb
      xlsfonts
      xwininfo
      xdotool
      dmenu
      fontconfig
      jq
      procps
      xorg.mkfontscale
    ];
  }
  ''
    set -euxo pipefail
    export HOME="$TMPDIR/home"
    export XDG_RUNTIME_DIR="$TMPDIR/runtime"
    mkdir -p "$HOME" "$XDG_RUNTIME_DIR" "$out"
    chmod 700 "$XDG_RUNTIME_DIR"
    export DISPLAY=:97
    export FONTCONFIG_FILE="$TMPDIR/fonts.conf"
    cat > "$FONTCONFIG_FILE" <<EOF
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
    <fontconfig>
      <dir>${p.cozette}/share/fonts</dir>
      <dir>${p.terminus_font}/share/fonts</dir>
      <dir>${p.dejavu_fonts}/share/fonts/truetype</dir>
      <cachedir>$TMPDIR/font-cache</cachedir>
    </fontconfig>
    EOF
    fontdir="$TMPDIR/x11-fonts"
    mkdir -p "$fontdir"
    cp ${p.cozette}/share/fonts/misc/*.bdf "$fontdir/"
    mkfontdir "$fontdir"
    test -f "$fontdir/fonts.dir"
    Xvfb "$DISPLAY" -screen 0 1280x800x24 -noreset -nolisten tcp -fp "$fontdir" >"$out/xvfb.log" 2>&1 &
    server=$!
    wm= term= menu=
    trap 'kill $menu $term $wm $server 2>/dev/null || true' EXIT
    for attempt in $(seq 1 50); do
      if xlsfonts -fn '${bitmap}' >"$out/font.txt" 2>/dev/null; then break; fi
      sleep 0.1
    done
    grep -Fix -- '${bitmap}' "$out/font.txt"
    xrdb -merge ${h.home.file.${h.xresources.path}.source}
    xrdb -query > "$out/xresources.txt"
    grep -F 'XTerm*faceName:' "$out/xresources.txt"
    i3 -C -c ${h.xdg.configFile."i3/config".source} >"$out/config-check.log" 2>&1
    i3 -c ${h.xdg.configFile."i3/config".source} >"$out/i3.log" 2>&1 &
    wm=$!
    for attempt in $(seq 1 50); do
      if i3-msg -t get_version >"$out/i3-version.json" 2>/dev/null; then break; fi
      sleep 0.1
    done
    jq -e '.major == 4' "$out/i3-version.json"
    xterm -title akuma-gui-smoke -e sh -c 'sleep 60' >"$out/xterm.log" 2>&1 &
    term=$!
    for attempt in $(seq 1 50); do
      i3-msg -t get_tree > "$out/tree.json"
      if jq -e '.. | objects | select(.name? == "akuma-gui-smoke")' "$out/tree.json" >/dev/null; then break; fi
      sleep 0.1
    done
    jq -e '.. | objects | select(.name? == "akuma-gui-smoke")' "$out/tree.json" >"$out/window.json"
    xwininfo -root -tree > "$out/x11-windows.txt"
    fc-match -f '%{family}: %{file}\n' 'Cozette' > "$out/fontconfig.txt"
    grep -F 'Cozette' "$out/fontconfig.txt"
    printf 'akuma-menu-ok\n' | dmenu -fn 'Cozette-10' >"$out/menu.txt" 2>"$out/menu.log" &
    menu=$!
    for attempt in $(seq 1 50); do
      if xdotool search --class dmenu >/dev/null 2>&1; then break; fi
      sleep 0.1
    done
    xdotool key Return
    wait "$menu"
    menu=
    grep -Fx akuma-menu-ok "$out/menu.txt"
    sleep 1
    ! grep -Ei 'could not (load|open).*font|failed.*font|error:|syntax error' "$out/i3.log" "$out/xterm.log" "$out/menu.log"
    ${p.firefox}/bin/firefox --version > "$out/firefox-version.txt"
    printf 'PASS: i3 config, native X11 window, bitmap font, launcher and Firefox executable\n' > "$out/result.txt"
  ''
