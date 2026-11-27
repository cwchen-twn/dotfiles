#!/bin/sh
# DKMS PRE_BUILD for applesmc-bclm: extract the kernel's own applesmc.c from Debian's linux-source-X.Y and patch it.
# $1: the kernel being built, e.g. 7.3.5+deb14-amd64. The source package must be the same upstream version.
set -eu
kver=$1
upstream=${kver%%[+-]*}
series=$(echo "$upstream" | cut -d. -f1,2)
pkg=linux-source-$series
have=$(dpkg-query -W -f '${Version}' "$pkg" 2>/dev/null || true)
case $have in
    "$upstream"-*) ;;
    *)
        echo "applesmc-bclm: $pkg is '${have:-not installed}', kernel $kver needs $upstream" >&2
        exit 1
        ;;
esac
tar -xJf "/usr/src/$pkg.tar.xz" --strip-components=3 "$pkg/drivers/hwmon/applesmc.c"
patch --no-backup-if-mismatch applesmc.c charge-limit.patch
