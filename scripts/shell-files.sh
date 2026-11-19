#!/bin/sh
# List the sh/bash scripts to lint, found by content rather than name (bin scripts have no extension):
# a sh/bash shebang, or a `# shellcheck shell=` directive in the first two lines (e.g. ~/.profile).
#   scripts/shell-files.sh            tracked files, minus chezmoi templates (they are linted once rendered)
#   scripts/shell-files.sh <dir>      every file under <dir> (the rendered templates in build/rendered)
set -eu

is_shell() {
    head -n 2 "$1" 2>/dev/null | grep -qE '^#!.*[/ ](ba|da)?sh( |$)|^# shellcheck shell='
}

if [ $# -gt 0 ]; then
    find "$1" -type f
else
    git ls-files | grep -v '\.tmpl$'
fi | while IFS= read -r f; do
    if [ -f "$f" ] && is_shell "$f"; then printf '%s\n' "$f"; fi
done
