#!/usr/bin/env bash
# Intentionally not a deployment implementation.
set -euo pipefail
message='Kernel deployment is unsupported and quarantined.
This helper never builds, copies, SSHs, changes sysctls, or reboots.
Use a separately reviewed NixOS kernel configuration and normal deployment
procedure, or an isolated VM. kexec_load_disabled=1 cannot be reversed until
reboot; do not try to bypass that safety policy.'
case "${1:-}" in
  --help|-h|help) printf 'Usage: kernel-deploy.sh --help\n%s\n' "$message" ;;
  *) printf '%s\n' "$message" >&2; exit 2 ;;
esac
