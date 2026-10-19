#!/usr/bin/env bash
# Explicit device selection; never deploy a server or assume jailbreak credentials.
set -euo pipefail
HERE=$(cd -- "$(dirname -- "$0")" && pwd -P)
. "$HERE/common.sh"
case "${1:-}" in
  --help|help|'')
    printf '%s\n' 'Usage: ios-device.sh info UDID | ps UDID | trace UDID PATTERN | ssh UDID USER [LOCAL_PORT]'
    exit 0
    ;;
  info)
    [ "$#" -eq 2 ] || fail 'Usage: ios-device.sh info UDID'
    valid_name "$2"
    need ideviceinfo
    exec ideviceinfo -u "$2"
    ;;
  ps)
    [ "$#" -eq 2 ] || fail 'Usage: ios-device.sh ps UDID'
    valid_name "$2"
    need frida-ps
    exec frida-ps -D "$2"
    ;;
  trace)
    [ "$#" -eq 3 ] || fail 'Usage: ios-device.sh trace UDID INCLUDE_PATTERN'
    valid_name "$2"
    need frida-trace
    exec frida-trace -D "$2" -i "$3"
    ;;
  ssh)
    [ "$#" -ge 3 ] && [ "$#" -le 4 ] || fail 'Usage: ios-device.sh ssh UDID USER [LOCAL_PORT]'
    valid_name "$2"
    valid_name "$3"
    port=${4:-2222}
    valid_port "$port"
    need iproxy
    need ssh
    iproxy -u "$2" "$port" 22 &
    proxy_pid=$!
    cleanup() { kill "$proxy_pid" 2>/dev/null || true; wait "$proxy_pid" 2>/dev/null || true; }
    trap cleanup EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    # Allow the local forwarder to initialize; fail if it exits immediately.
    sleep 0.2
    kill -0 "$proxy_pid" 2>/dev/null || fail 'iproxy failed to start'
    ssh -p "$port" -o StrictHostKeyChecking=ask -o "HostKeyAlias=ios-$2" "$3@127.0.0.1"
    ;;
  *) fail 'Unknown operation; use ios-device.sh --help' ;;
esac
