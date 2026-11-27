#!/bin/bash
# Managed by the dotfiles (ansible macbook role). Build and install applesmc-bclm for every kernel with headers that
# doesn't have it yet. Run by ansible and, after every apt run, by /etc/apt/apt.conf.d/90-applesmc-bclm: a kernel
# upgrade can trigger DKMS before linux-source of the same version is unpacked, so the build is retried once it is.
# Another kernel it can't build for keeps the in-tree applesmc and is only reported; the running kernel without the
# module is an error, with the end of DKMS's build log. Prints CHANGED on installs.
set -eu
m=applesmc-bclm
v=$(sed -n 's/^PACKAGE_VERSION="\(.*\)"/\1/p' "$(dirname "$(readlink -f "$0")")/dkms.conf")
running=$(uname -r)
dkms status -m $m -v "$v" | grep -q . || dkms add -m $m -v "$v" >/dev/null
for k in /lib/modules/*; do
    k=${k##*/}
    [ -e "/lib/modules/$k/build" ] || continue
    dkms status -m $m -v "$v" -k "$k" | grep -q installed && continue
    if out=$(dkms install -m $m -v "$v" -k "$k" 2>&1); then
        echo "CHANGED $k"
    elif [ "$k" = "$running" ]; then
        echo "applesmc-bclm: build failed for the running kernel $k" >&2
        echo "$out" | tail -n 15 >&2
        tail -n 15 "/var/lib/dkms/$m/$v/build/make.log" >&2 2>/dev/null || true
        exit 1
    else
        echo "applesmc-bclm: no build for $k (linux-source not this version, or the patch no longer applies)" >&2
    fi
done
