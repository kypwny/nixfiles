#!/usr/bin/env bash
# Explicit opt-in lab operations; shell entry never invokes this helper.
set -euo pipefail
HERE=$(cd -- "$(dirname -- "$0")" && pwd -P)
. "$HERE/common.sh"
HTB_ROOT=${HTB_ROOT:-${RESEARCH_WORKSPACE:-$HOME/workspace}/htb}
case "${1:-}" in
  --help|help|'')
    printf '%s\n' 'Usage: htb.sh new NAME RHOST LHOST | scan RHOST OUTPUT_DIR | vpn PROFILE.ovpn | down | shell LHOST PORT'
    exit 0
    ;;
  new)
    [ "$#" -eq 4 ] || { printf 'Usage: htb.sh new NAME RHOST LHOST\n' >&2; exit 2; }
    valid_name "$2"
    valid_ip "$3"
    valid_ip "$4"
    HTB_ROOT=$(safe_path "$HTB_ROOT")
    directory=$(safe_path "$HTB_ROOT/$2")
    for child in scans loot payloads env.sh notes.md; do
      safe_path "$directory/$child" >/dev/null
    done
    mkdir -p "$directory/scans" "$directory/loot" "$directory/payloads"
    if [ ! -e "$directory/env.sh" ] && [ ! -L "$directory/env.sh" ]; then
      (
        set -C
        {
          printf 'export RHOST=%q\nexport LHOST=%q\nexport HTB_MACHINE=%q\n' "$3" "$4" "$2"
          # Preserve the variable reference for the generated environment script.
          # shellcheck disable=SC2016
          printf 'export HTB_WORKSPACE=%q\ncd -- "$HTB_WORKSPACE"\n' "$directory"
        } > "$directory/env.sh"
      )
    fi
    if [ ! -e "$directory/notes.md" ] && [ ! -L "$directory/notes.md" ]; then
      (set -C; printf '# %s\n\n- IP: %s\n\n## Recon\n\n## Lessons\n' "$2" "$3" > "$directory/notes.md")
    fi
    printf 'Workspace: %s\nSource env.sh to set explicit RHOST and LHOST.\n' "$directory"
    ;;
  scan)
    [ "$#" -eq 3 ] || fail 'Usage: htb.sh scan RHOST OUTPUT_DIR (authorized targets only)'
    valid_ip "$2"
    output=$(safe_path "$3")
    need nmap
    mkdir -p "$output"
    run=$(mktemp -d "$output/scan.XXXXXX")
    nmap -Pn -sT -p- -oA "$run/alltcp" "$2"
    ports=$(python3 - "$run/alltcp.nmap" <<'PY'
import pathlib, re, sys
text = pathlib.Path(sys.argv[1]).read_text()
print(','.join(re.findall(r'^([0-9]+)/tcp\s+open\s', text, re.M)))
PY
)
    if [ -n "$ports" ]; then
      nmap -Pn -sT -sV -sC -p "$ports" -oA "$run/detail" "$2"
    fi
    printf 'Scan results: %s\n' "$run"
    ;;
  vpn)
    [ "$#" -eq 2 ] || fail 'Usage: htb.sh vpn PROFILE.ovpn (foreground; Ctrl-C to stop)'
    need openvpn
    need sudo
    [ -f "$2" ] || fail "No VPN profile: $2"
    # Relative profiles must not become OpenVPN option names.
    config=$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$2")
    HTB_ROOT=$(safe_path "$HTB_ROOT")
    pidfile=$(safe_path "$HTB_ROOT/.vpn.pid")
    metadata=$(safe_path "$HTB_ROOT/.vpn.command")
    [[ $config != *$'\n'* && $pidfile != *$'\n'* ]] || fail 'invalid newline in VPN paths'
    [ ! -e "$pidfile" ] && [ ! -L "$pidfile" ] || fail "VPN pidfile exists; inspect it before another connection: $pidfile"
    [ ! -e "$metadata" ] && [ ! -L "$metadata" ] || fail "VPN state exists; inspect/remove stale state before another connection: $metadata"
    umask 077
    mkdir -p "$HTB_ROOT"
    executable=$(command -v openvpn)
    (set -C; printf '%s --config %s --writepid %s\n' "$executable" "$config" "$pidfile" > "$metadata")
    printf 'Foreground VPN; use Ctrl-C or validated htb.sh down from another terminal.\n'
    sudo "$executable" --config "$config" --writepid "$pidfile"
    ;;
  down)
    [ "$#" -eq 1 ] || fail 'Usage: htb.sh down'
    HTB_ROOT=$(safe_path "$HTB_ROOT")
    pidfile=$(safe_path "$HTB_ROOT/.vpn.pid")
    metadata=$(safe_path "$HTB_ROOT/.vpn.command")
    [ -f "$pidfile" ] && [ -f "$metadata" ] && [ ! -L "$pidfile" ] && [ ! -L "$metadata" ] || fail 'refusing shutdown: no owned VPN state'
    IFS= read -r pid < "$pidfile" || fail 'refusing shutdown: unreadable PID'
    [[ $pid =~ ^[0-9]{2,9}$ ]] && [ "$((10#$pid))" -gt 1 ] || fail 'refusing shutdown: invalid PID'
    IFS= read -r expected < "$metadata" || fail 'refusing shutdown: unreadable command'
    [[ $expected == *" --writepid $pidfile" ]] || fail 'refusing shutdown: invalid ownership marker'
    actual=$(ps -p "$pid" -o command=) || fail 'refusing shutdown: process no longer exists (inspect stale state)'
    uid=$(ps -p "$pid" -o uid=) || fail 'refusing shutdown: cannot inspect process owner'
    [ "$actual" = "$expected" ] && [[ $uid =~ ^[[:space:]]*0[[:space:]]*$ ]] || fail 'refusing shutdown: PID does not match owned root VPN process'
    need sudo
    sudo /bin/kill -TERM "$pid"
    rm -f "$pidfile" "$metadata"
    printf 'Sent TERM to the validated VPN process only.\n'
    ;;
  shell)
    [ "$#" -eq 3 ] || fail 'Usage: htb.sh shell LHOST PORT'
    valid_ip "$2"
    valid_port "$3"
    need rlwrap
    need ncat
    exec rlwrap -cAr "$(command -v ncat)" --listen "$2" "$3"
    ;;
  *) printf 'Usage: htb.sh new NAME RHOST LHOST\n' >&2; exit 2 ;;
esac
