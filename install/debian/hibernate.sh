#!/usr/bin/env bash
# Make hibernation work on Debian/Ubuntu (initramfs-tools + GRUB). Idempotent; prints CHANGED when it changed something.
#   - a swap partition at least as big as RAM exists: resume from it
#   - otherwise: create /swapfile (RAM + 2 GB, preferred via pri=10) and resume from it (resume_offset)
# Standalone: curl -fsSL https://git.chenantunez.com/cwchen-twn/dotfiles/raw/branch/main/install/debian/hibernate.sh | sudo bash
# Also run by the macbook Ansible role.
set -euo pipefail
[ "$(id -u)" = 0 ] || {
    echo "run as root (sudo)" >&2
    exit 1
}

ram_mb=$(awk '/^MemTotal/ { print int($2 / 1024) }' /proc/meminfo)
changed=0

# write FILE CONTENT: replace the file only when the content differs; returns 0 if it wrote
write() {
    [ "$(cat "$1" 2>/dev/null)" = "$2" ] && return 1
    mkdir -p "$(dirname "$1")"
    printf '%s\n' "$2" >"$1"
}

part=$(lsblk -bnpro NAME,FSTYPE,SIZE | awk -v min=$((ram_mb * 1048576)) '$2 == "swap" && $3 >= min { print $1; exit }')
if [ -n "$part" ]; then
    uuid=$(blkid -s UUID -o value "$part")
    cmdline=
    where="swap partition $part"
    # A /swapfile from an older setup is no longer needed for resume (zram + the partition cover swap): retire it.
    if [ -f /swapfile ] || grep -qE '^/swapfile\s' /etc/fstab; then
        swapoff /swapfile 2>/dev/null || true
        sed -i '\|^/swapfile[[:space:]]|d' /etc/fstab
        rm -f /swapfile
        changed=1
    fi
else
    want=$((ram_mb + 2048))
    if [ ! -f /swapfile ] || [ $(($(stat -c %s /swapfile) / 1048576)) -lt "$want" ]; then
        swapoff /swapfile 2>/dev/null || true
        rm -f /swapfile
        fallocate -l "${want}M" /swapfile
        chmod 600 /swapfile
        mkswap /swapfile >/dev/null
        changed=1
    fi
    grep -qE '^/swapfile\s' /etc/fstab || {
        echo '/swapfile none swap sw,pri=10 0 0' >>/etc/fstab
        changed=1
    }
    swapon --show=NAME --noheadings | grep -qx /swapfile || {
        swapon -p 10 /swapfile
        changed=1
    }
    uuid=$(findmnt -no UUID -T /swapfile)
    offset=$(filefrag -v /swapfile | awk '$1 == "0:" { sub(/\.\.$/, "", $4); print $4 }')
    cmdline="resume=UUID=$uuid resume_offset=$offset"
    where="/swapfile (${want} MB)"
fi

# Point the running kernel at it too, so hibernating works before the next reboot (offset first, then device).
if [ -n "$cmdline" ]; then
    dev=$(findmnt -no SOURCE -T /swapfile)
    echo "$offset" >/sys/power/resume_offset
else
    dev=$part
    echo 0 >/sys/power/resume_offset
fi
lsblk -dno MAJ:MIN "$dev" | tr -d ' ' >/sys/power/resume

initramfs_resume=/etc/initramfs-tools/conf.d/resume
if [ -z "$cmdline" ]; then
    if write "$initramfs_resume" "RESUME=UUID=$uuid"; then
        update-initramfs -u
        changed=1
    fi
elif [ "$(cat "$initramfs_resume" 2>/dev/null)" = "RESUME=UUID=$uuid" ]; then
    # Swap file: the initramfs takes resume=/resume_offset= from the kernel command line. RESUME in conf.d must
    # name a swap device, so drop a value pointing at the filesystem (left by an older version of this script).
    rm -f "$initramfs_resume"
    update-initramfs -u
    changed=1
fi
grubcfg=/etc/default/grub.d/hibernate.cfg
if [ -n "$cmdline" ]; then
    if write "$grubcfg" "GRUB_CMDLINE_LINUX_DEFAULT=\"\$GRUB_CMDLINE_LINUX_DEFAULT $cmdline\""; then
        update-grub
        changed=1
    fi
elif [ -f "$grubcfg" ]; then
    rm -f "$grubcfg"
    update-grub
    changed=1
fi

echo "hibernation resumes from $where (RAM ${ram_mb} MB)"
[ "$changed" = 0 ] || echo CHANGED
