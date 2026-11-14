#!/bin/sh
# partman/early_command (busybox, inside the installer): install to the first disk that is not the USB stick we
# booted from, and wipe its old partition tables so a used drive (APFS, old GPT, LVM...) can't trigger prompts.
set -u

src=$(awk '$2 == "/cdrom" { print $1 }' /proc/mounts | head -n 1)
src=${src#/dev/}
if [ -n "$src" ] && [ -e "/sys/class/block/$src/partition" ]; then
    src=$(basename "$(dirname "$(readlink -f "/sys/class/block/$src")")")
fi

disk=
for d in $(list-devices disk); do
    [ "${d#/dev/}" = "$src" ] && continue
    disk=$d
    break
done

if [ -z "$disk" ]; then
    logger -t pick-disk "no internal disk found (boot media: $src); partman will ask"
    exit 0
fi
logger -t pick-disk "installing to $disk (boot media: $src)"

# Zero the primary and the backup GPT so partman sees a blank disk (a half-wiped GPT makes parted prompt).
name=${disk#/dev/}
sectors=$(cat "/sys/class/block/$name/size")
dd if=/dev/zero of="$disk" bs=1M count=16 2>/dev/null
dd if=/dev/zero of="$disk" bs=512 seek=$((sectors - 2048)) count=2048 2>/dev/null
sync

debconf-set partman-auto/disk "$disk"
debconf-set grub-installer/bootdev "$disk"
