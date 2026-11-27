#!/bin/bash
# Managed by the dotfiles (ansible macbook role). Build and install applesmc-bclm for every kernel with headers that
# doesn't have it yet. Run by ansible and, after every apt run, by /etc/apt/apt.conf.d/90-applesmc-bclm: a kernel
# upgrade can trigger DKMS before linux-source of the same version is unpacked, so the build is retried once it is.
# A kernel it can't build for keeps the in-tree applesmc; that is reported, never an error. Prints CHANGED on installs.
set -eu
m=applesmc-bclm
v=$(sed -n 's/^PACKAGE_VERSION="\(.*\)"/\1/p' "$(dirname "$(readlink -f "$0")")/dkms.conf")
dkms status -m $m -v "$v" | grep -q . || dkms add -m $m -v "$v" >/dev/null
for k in /lib/modules/*; do
    k=${k##*/}
    [ -e "/lib/modules/$k/build" ] || continue
    dkms status -m $m -v "$v" -k "$k" | grep -q installed && continue
    if dkms install -m $m -v "$v" -k "$k" >/dev/null 2>&1; then
        echo "CHANGED $k"
    else
        echo "applesmc-bclm: no build for $k (linux-source not this version yet, or the patch no longer applies)" >&2
    fi
done
