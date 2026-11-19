#!/bin/sh
# Render every chezmoi template under home/ into build/rendered/<path without .tmpl>, with the fixture config
# (ci/chezmoi.toml: every option selected), so template errors fail here and the output can be linted.
# .chezmoi.toml.tmpl is skipped: it only prompts, and ci/chezmoi.toml mirrors its [data].
set -eu

out=build/rendered
rm -rf "$out"
mkdir -p "$out"
status=0
# git pathspec: * also matches /, so this is every template at any depth
for t in $(git ls-files 'home/*.tmpl'); do
    [ "$t" = home/.chezmoi.toml.tmpl ] && continue
    dest="$out/${t#home/}"
    dest="${dest%.tmpl}"
    mkdir -p "$(dirname "$dest")"
    if ! chezmoi --source home --config ci/chezmoi.toml --persistent-state build/chezmoistate.boltdb \
        execute-template <"$t" >"$dest"; then
        echo "render failed: $t" >&2
        status=1
    fi
done
exit "$status"
