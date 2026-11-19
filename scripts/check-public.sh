#!/bin/sh
# This repo is public: fail if a tracked file contains a private-network IP or a work domain.
# Encrypted files are exempt (they are ciphertext); so is this script, which holds the patterns.
set -eu

pattern='192\.168\.[0-9]+\.[0-9]+|\.gov\.py'
if git ls-files -z | grep -zv -e '\.age$' -e '^scripts/check-public\.sh$' \
    | xargs -0 grep -nIE "$pattern" --; then
    echo "check-public: internal IPs or work domains found (above)" >&2
    exit 1
fi
