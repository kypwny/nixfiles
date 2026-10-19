#!/usr/bin/env bash
# Firmware download only; no device access or implicit latest-artifact selection.
set -euo pipefail
HERE=$(cd -- "$(dirname -- "$0")" && pwd -P)
. "$HERE/common.sh"
usage() {
  printf '%s\n' 'Usage: ios-pull.sh MODEL VERSION [OUTPUT_ROOT]' \
    'MODEL is an explicit iPhone/iPad/iPod identifier (e.g. iPhone15,2).' \
    'VERSION is an explicit OS version (e.g. 17.0 or 17.0.1).' \
    "Default root: \${RESEARCH_WORKSPACE:-\$HOME/workspace}/ios/MODEL/VERSION." \
    'Downloads into a fresh run directory and records manifest.json with hashes.' \
    'No extraction, restore, jailbreak, or attached-device discovery.'
}
if [ "${1:-}" = --help ]; then usage; exit 0; fi
[ "$#" -ge 2 ] && [ "$#" -le 3 ] || fail 'Usage: ios-pull.sh MODEL VERSION [OUTPUT_ROOT]'
MODEL=$1
VERSION=$2
[[ $MODEL =~ ^(iPhone|iPad|iPod)[0-9]+,[0-9]+$ ]] || fail "invalid model: $MODEL"
[[ $VERSION =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]] || fail "invalid version: $VERSION"
RAW_ROOT=${3-${RESEARCH_WORKSPACE:-$HOME/workspace}/ios/$MODEL/$VERSION}
[ -n "$RAW_ROOT" ] || fail 'invalid empty output root'
ROOT=$(safe_path "$RAW_ROOT")
python3 - "$RAW_ROOT" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1]).expanduser().absolute()
if any(p.is_symlink() for p in (path, *path.parents)):
    sys.exit('refusing symlink output path: ' + str(path))
PY
need ipsw
mkdir -p -- "$ROOT"
OUT=$(mktemp -d "$ROOT/run.XXXXXXXX")
ipsw download ipsw --device "$MODEL" --version "$VERSION" --output "$OUT" --confirm
python3 - "$OUT" "$MODEL" "$VERSION" <<'PY'
import hashlib, json, pathlib, sys
root = pathlib.Path(sys.argv[1])
artifacts = []
if any(path.is_symlink() for path in root.rglob('*')):
    sys.exit('refusing symlink artifact in fresh output')
for path in sorted(root.rglob('*.ipsw')):
    if path.is_file():
        digest = hashlib.sha256()
        with path.open('rb') as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b''):
                digest.update(chunk)
        artifacts.append({'file': str(path.relative_to(root)), 'sha256': digest.hexdigest()})
if not artifacts:
    sys.exit('no IPSW downloaded into fresh output; refusing unrelated artifacts')
with (root / 'manifest.json').open('x') as stream:
    json.dump({'model': sys.argv[2], 'version': sys.argv[3], 'artifacts': artifacts}, stream, indent=2)
    stream.write('\n')
PY
printf '%s\n' "$OUT"
