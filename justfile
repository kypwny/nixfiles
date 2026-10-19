default:
    @just --list

# Switch system configuration (auto-detects NixOS vs Darwin)
switch:
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ "$(uname)" == "Darwin" ]]; then
        nh darwin switch .
    else
        nh os switch .
    fi

# Build system configuration (auto-detects NixOS vs Darwin)
build:
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ "$(uname)" == "Darwin" ]]; then
        nh darwin build .
    else
        nh os build .
    fi

# Evaluate every advertised platform; build checks only for the native platform
check:
    nix flake check --no-build --all-systems --no-write-lock-file
    nix flake check --no-write-lock-file

# Run the shell helper tests
test:
    python3 -m unittest discover -s tests -p 'test_*.py' -v

# Show the selected platform's included/omitted tool inventory
shells system=`nix eval --impure --raw --expr builtins.currentSystem`:
    nix eval --no-write-lock-file --json .#lib.toolInventory.{{system}}

# Format all code
fmt:
    nix fmt

# Lint nix code with statix and deadnix
lint:
    nix run nixpkgs#statix -- check .
    nix run nixpkgs#deadnix -- --fail .

# Scan for secrets with gitleaks
scan:
    nix run nixpkgs#gitleaks -- dir . --redact --verbose

# Update flake lock inputs
update:
    nix flake update
