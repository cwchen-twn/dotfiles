#!/bin/sh
# Build the whole source state for a fresh machine with every option selected (ci/chezmoi.toml) and apply it
# as a dry run into an empty directory. Catches broken templates, .chezmoiignore and attribute mistakes.
# Encrypted files (no key in CI), externals (network) and scripts (never run here) are left out.
set -eu

dest=$(mktemp -d)
log=$(mktemp)
trap 'rm -rf "$dest" "$log"' EXIT
mkdir -p build
status=0
chezmoi --source home --config ci/chezmoi.toml --persistent-state build/chezmoistate.boltdb \
    --destination "$dest" --no-tty \
    apply --dry-run --exclude encrypted,externals,scripts >"$log" 2>&1 || status=$?
# the fixture is not generated from .chezmoi.toml.tmpl, so chezmoi always warns about that: drop the line
grep -v 'config file template has changed' "$log" >&2 || true
exit "$status"
