#!/usr/bin/env bash
# Experimental Linux build only. Never configure, install, deploy, or reboot.
set -euo pipefail
HERE=$(cd -- "$(dirname -- "$0")" && pwd -P)
. "$HERE/common.sh"
usage() {
  printf '%s\n' 'Usage: kbuild.sh [--darwin-experimental] [--arch x86_64|arm64]' \
    '                 [--cross-compile PREFIX] [--jobs N]' \
    '                 [--target vmlinux|bzImage|Image|modules] KDIR O' \
    'KDIR and O must be separate external directories; O/.config must exist.' \
    'Default: ARCH=x86_64, LLVM=1, matching Linux cross prefix, jobs=1, vmlinux.' \
    'Darwin requires explicit --darwin-experimental; full builds may still fail.' \
    'Darwin only: KBUILD_ELF_INCLUDE may point to isolated elf.h headers.' \
    'Symlinked paths and pre-existing symlink children in O are refused.' \
    'No automatic configuration, install, deployment, or host privilege changes.'
}
if [ "${1:-}" = --help ]; then usage; exit 0; fi
BUILD_ARCH=x86_64
PREFIX=
BUILD_JOBS=1
TARGET=vmlinux
DARWIN_EXPERIMENTAL=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --darwin-experimental) DARWIN_EXPERIMENTAL=1; shift ;;
    --jobs|--arch|--cross-compile|--target)
      [ "$#" -ge 2 ] || fail "missing $1 value"
      case "$1" in
        --jobs) BUILD_JOBS=$2 ;;
        --arch) BUILD_ARCH=$2 ;;
        --cross-compile) PREFIX=$2; [ -n "$PREFIX" ] || fail 'invalid empty cross prefix' ;;
        --target) TARGET=$2 ;;
      esac
      shift 2
      ;;
    --) shift; break ;;
    -*) fail "unknown option: $1" ;;
    *) break ;;
  esac
done
[ "$#" -eq 2 ] || fail 'Usage: kbuild.sh [OPTIONS] KDIR O'
[[ $BUILD_JOBS =~ ^[1-9][0-9]*$ ]] || fail "invalid jobs: $BUILD_JOBS"
case "$BUILD_ARCH" in
  x86_64)
    PREFIX=${PREFIX:-x86_64-linux-gnu-}
    [[ $PREFIX =~ ^x86_64(-[A-Za-z0-9_]+)?-linux-(gnu|musl)-$ ]] || fail 'cross prefix must match x86_64 Linux'
    ;;
  arm64)
    PREFIX=${PREFIX:-aarch64-linux-gnu-}
    [[ $PREFIX =~ ^aarch64(-[A-Za-z0-9_]+)?-linux-(gnu|musl)-$ ]] || fail 'cross prefix must match aarch64 Linux'
    ;;
  *) fail "unsupported architecture: $BUILD_ARCH" ;;
esac
case "$TARGET" in
  vmlinux|modules) ;;
  bzImage) [ "$BUILD_ARCH" = x86_64 ] || fail 'bzImage requires x86_64' ;;
  Image) [ "$BUILD_ARCH" = arm64 ] || fail 'Image requires arm64' ;;
  *) fail "unsupported build target: $TARGET (no configuration or install targets)" ;;
esac
[ -n "$1" ] && [ -n "$2" ] || fail 'invalid empty KDIR or O'
SOURCE=$(safe_path "$1")
OUTPUT=$(safe_path "$2")
python3 - "$1" "$2" <<'PY'
import os, pathlib, sys
paths = [pathlib.Path(value).expanduser().absolute() for value in sys.argv[1:]]
for path in paths:
    if any(p.is_symlink() for p in (path, *path.parents)):
        sys.exit('refusing symlink source/output path: ' + str(path))
source, output = [p.resolve() for p in paths]
if source == output or source in output.parents or output in source.parents:
    sys.exit('refusing overlapping source and output directories')
for path in (source / 'Makefile', output / '.config'):
    if path.is_symlink():
        sys.exit('refusing symlink build input: ' + str(path))
if any(path.is_symlink() for path in output.rglob('*')):
    sys.exit('refusing symlink inside build output directory')
PY
[ -f "$SOURCE/Makefile" ] || fail 'KDIR must contain a Makefile'
[ -f "$OUTPUT/.config" ] || fail 'O/.config must already exist; no automatic configuration'
python3 - "$OUTPUT/.config" "$BUILD_ARCH" <<'PY'
import pathlib, sys
lines = set(pathlib.Path(sys.argv[1]).read_text().splitlines())
symbol, other = ('CONFIG_X86_64=y', 'CONFIG_ARM64=y') if sys.argv[2] == 'x86_64' else ('CONFIG_ARM64=y', 'CONFIG_X86_64=y')
if symbol not in lines or other in lines:
    sys.exit('existing O/.config architecture does not match --arch; refusing automatic reconfiguration')
PY
need make
need uname
HOST=$(uname -s)
set -- make -C "$SOURCE" "O=$OUTPUT" "ARCH=$BUILD_ARCH" LLVM=1 "CROSS_COMPILE=$PREFIX"
case "$HOST" in
  Darwin)
    [ "$DARWIN_EXPERIMENTAL" -eq 1 ] || fail 'Darwin builds require --darwin-experimental; prefer a Linux host/VM'
    printf '%s\n' 'Experimental Darwin build: host tools may still fail; no full-build support implied.' >&2
    set -- "$@" HOSTLD=/usr/bin/ld HOSTAR=/usr/bin/ar HOSTNM=/usr/bin/nm HOSTRANLIB=/usr/bin/ranlib
    if [ -n "${KBUILD_ELF_INCLUDE:-}" ]; then
      [ -f "$KBUILD_ELF_INCLUDE/elf.h" ] || fail 'KBUILD_ELF_INCLUDE must contain an isolated elf.h'
      # Shell-escape the include flag: make expands HOSTCFLAGS in a shell command.
      printf -v INCLUDE_FLAG '%q' "-I$KBUILD_ELF_INCLUDE"
      set -- "$@" "HOSTCFLAGS=${HOSTCFLAGS:-} $INCLUDE_FLAG"
    fi
    ;;
  Linux) ;;
  *) fail "unsupported build host: $HOST" ;;
esac
exec "$@" "-j$BUILD_JOBS" "$TARGET"
