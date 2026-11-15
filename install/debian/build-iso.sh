#!/usr/bin/env bash
# Build an unattended Debian netinst ISO (LXQt, preseeded) and optionally write it to a USB stick.
#
#   install/debian/build-iso.sh                 # build only -> ~/.cache/debian-iso/debian-preseed.iso
#   install/debian/build-iso.sh --write /dev/sdX
#
# Asks for hostname, user, timezone, keymap, Wi-Fi and the login password. Any answer can be given up front as an
# env var (HOSTNAME_NEW USERNAME_NEW FULLNAME TIMEZONE KEYMAP WIFI_SSID WIFI_PASS PASSHASH) for unattended builds.
# Secrets only end up in the generated ISO (mode 600), never in the repo.
set -euo pipefail
shopt -u patsub_replacement 2>/dev/null || true   # keep '&' literal in ${var//pat/repl}

here=$(cd "$(dirname "$0")" && pwd)
cache=${XDG_CACHE_HOME:-$HOME/.cache}/debian-iso
mirror=https://cdimage.debian.org/debian-cd/current/amd64/iso-cd
out=$cache/debian-preseed.iso
write_dev=

while [ $# -gt 0 ]; do
    case $1 in
        --write) write_dev=${2:?--write needs a device, e.g. /dev/sdb}; shift 2 ;;
        --out) out=$2; shift 2 ;;
        -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done

for cmd in curl xorriso openssl sha256sum; do
    command -v "$cmd" >/dev/null || { echo "missing $cmd (apt install $cmd)" >&2; exit 1; }
done

ask() { # ask VAR "prompt" default
    local var=$1 prompt=$2 def=${3-} val
    [ -n "${!var-}" ] && return
    read -rp "$prompt${def:+ [$def]}: " val
    printf -v "$var" '%s' "${val:-$def}"
}
ask_secret() { # ask_secret VAR "prompt"
    local var=$1 prompt=$2 a b
    [ -n "${!var-}" ] && return
    while :; do
        read -rsp "$prompt: " a; echo
        read -rsp "$prompt (again): " b; echo
        [ "$a" = "$b" ] && [ -n "$a" ] && break
        echo "empty or mismatch, try again"
    done
    printf -v "$var" '%s' "$a"
}

ask HOSTNAME_NEW "Hostname" mbp2015
ask USERNAME_NEW "Username" "$USER"
ask FULLNAME "Full name" "$(getent passwd "$USER" | cut -d: -f5 | cut -d, -f1)"
ask TIMEZONE "Timezone" "$(timedatectl show -p Timezone --value 2>/dev/null || echo UTC)"
ask KEYMAP "Keyboard layout (xkb)" us
ask WIFI_SSID "Wi-Fi SSID (empty: choose the network on the target during install)"
[ -z "$WIFI_SSID" ] || ask_secret WIFI_PASS "Wi-Fi password"
if [ -z "${PASSHASH-}" ]; then
    ask_secret USER_PASS "Login password for $USERNAME_NEW"
    PASSHASH=$(openssl passwd -6 -stdin <<<"$USER_PASS")
    unset USER_PASS
fi

# --- latest netinst, verified against Debian's SHA256SUMS
mkdir -p "$cache"
sums=$(curl -fsSL "$mirror/SHA256SUMS")
iso=$(awk '$2 ~ /^debian-[0-9.]+-amd64-netinst\.iso$/ { print $2 }' <<<"$sums")
if [ ! -f "$cache/$iso" ]; then
    echo "downloading $iso"
    curl -fL --progress-bar -o "$cache/$iso.part" "$mirror/$iso"
    mv "$cache/$iso.part" "$cache/$iso"
fi
(cd "$cache" && grep " $iso\$" <<<"$sums" | sha256sum -c --quiet) || { echo "checksum mismatch: $cache/$iso" >&2; exit 1; }

# --- render the preseed and a grub.cfg whose default entry runs it
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
umask 077

cfg=$(<"$here/preseed.cfg.tmpl")
# Without Wi-Fi answers, drop them and lower the priority to "high" so the installer asks for the network
# (netcfg's ESSID/passphrase questions are high priority; everything else is preseeded).
priority=critical
if [ -z "$WIFI_SSID" ]; then
    cfg=$(grep -v '^d-i netcfg/wireless_' <<<"$cfg")
    WIFI_PASS=
    priority=high
fi
for v in HOSTNAME_NEW:HOSTNAME USERNAME_NEW:USERNAME FULLNAME TIMEZONE KEYMAP WIFI_SSID WIFI_PASS PASSHASH; do
    src=${v%%:*} key=${v#*:}
    cfg=${cfg//@@$key@@/${!src}}
done
printf '%s\n' "$cfg" > "$work/preseed.cfg"
if grep -q '@@[A-Z_]*@@' "$work/preseed.cfg"; then echo "unrendered placeholder in preseed" >&2; exit 1; fi

xorriso -osirrox on -indev "$cache/$iso" -extract /boot/grub/grub.cfg "$work/grub.orig" >/dev/null 2>&1
chmod u+w "$work/grub.orig"
{
    echo 'set default=0'
    echo 'set timeout=5'
    sed '/^menuentry --hotkey=g/,$d' "$work/grub.orig"
    cat <<EOF
menuentry --hotkey=u 'Auto install (WIPES internal disk)' {
    set background_color=black
    linux    /install.amd/vmlinuz auto=true priority=$priority file=/cdrom/preseed/preseed.cfg locale=en_US.UTF-8 keymap=$KEYMAP hostname=$HOSTNAME_NEW --- quiet
    initrd   /install.amd/initrd.gz
}
EOF
    sed -n '/^menuentry --hotkey=g/,$p' "$work/grub.orig"
} > "$work/grub.cfg"

rm -f "$out"
xorriso -indev "$cache/$iso" -outdev "$out" -boot_image any replay \
    -map "$work/preseed.cfg" /preseed/preseed.cfg \
    -map "$here/pick-disk.sh" /preseed/pick-disk.sh \
    -map "$here/late.sh" /preseed/late.sh \
    -map "$work/grub.cfg" /boot/grub/grub.cfg >/dev/null 2>&1
chmod 600 "$out"
echo "built $out (from $iso; contains your password hash${WIFI_SSID:+ and Wi-Fi password}, keep it private)"

# --- write to USB
[ -n "$write_dev" ] || exit 0
[ -b "$write_dev" ] || { echo "$write_dev is not a block device" >&2; exit 1; }
[ "$(lsblk -dno TYPE "$write_dev")" = disk ] || { echo "$write_dev is not a whole disk" >&2; exit 1; }
[ "$(lsblk -dno TRAN "$write_dev")" = usb ] || { echo "$write_dev is not a USB disk, refusing" >&2; exit 1; }
lsblk -o NAME,SIZE,TRAN,MODEL,MOUNTPOINTS "$write_dev"
read -rp "ERASE everything on $write_dev? type the device name to confirm: " confirm
[ "$confirm" = "$write_dev" ] || { echo "aborted"; exit 1; }
for part in $(lsblk -lnpo NAME "$write_dev" | tail -n +2); do
    udisksctl unmount -b "$part" >/dev/null 2>&1 || sudo umount "$part" 2>/dev/null || true
done
sudo dd if="$out" of="$write_dev" bs=4M conv=fsync oflag=direct status=progress
sync
echo "done: boot the Mac holding the Option key and pick 'EFI Boot'"
