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

# Run checks across all systems
check:
    nix flake check

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
