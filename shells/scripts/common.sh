#!/usr/bin/env bash
# Shared validation only; sourcing this library has no external side effects.
fail() { printf '%s\n' "$*" >&2; exit 2; }
need() { command -v "$1" >/dev/null 2>&1 || fail "Missing dependency: $1 (enter the matching nix devShell)."; }
valid_name() { [[ $1 =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]] && [ "${#1}" -le 64 ] || fail "invalid name: $1"; }
valid_port() {
  [[ $1 =~ ^[0-9]{1,5}$ ]] || fail "invalid port: $1"
  [ "$((10#$1))" -ge 1 ] && [ "$((10#$1))" -le 65535 ] || fail "invalid port: $1"
}
valid_ip() {
  need python3
  python3 - "$1" <<'PY' || fail "invalid IPv4 address: $1"
import ipaddress, sys
try:
    ipaddress.IPv4Address(sys.argv[1])
except ValueError:
    sys.exit(1)
PY
}
# Resolve before mkdir, including symlinked parents. All callers validate each
# output child too, so pre-existing child symlinks cannot redirect writes.
safe_path() {
  need python3
  python3 - "$1" "$HERE/../.." <<'PY'
import os, sys
path = os.path.realpath(os.path.expanduser(sys.argv[1]))
roots = [os.path.realpath(sys.argv[2]), '/nix/store', os.path.realpath('/nix/store')]
if any(path == root or path.startswith(root + os.sep) for root in roots):
    print('refusing workspace inside repository or Nix store: ' + path, file=sys.stderr)
    sys.exit(2)
print(path)
PY
}
