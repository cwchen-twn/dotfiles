#!/bin/sh
# preseed/late_command (inside the installer, target mounted at /target): leave a one-shot bootstrap script
# that applies the dotfiles on first login. It stays manual because it needs you for the Vaultwarden unlock
# and the sudo password.
set -u
user=$1
home=/target/home/$user

cat >"$home/bootstrap.sh" <<'EOF'
#!/bin/sh
# Run once after the first login: installs chezmoi and applies the dotfiles (asks what to install).
set -eu
src="$HOME/Documents/Gitea/cwchen-twn/dotfiles"
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin" \
    init --apply --source "$src" https://git.chenantunez.com/cwchen-twn/dotfiles.git
rm -f "$0"
cat <<'MSG'

Done. Next:
  1. Log out and back in, choosing "LXQt (labwc)": fish as login shell, docker/input groups, monitors, keys.
  2. register-ssh-key   (fish: logs in to gh/glab/tea and uploads this machine's SSH key)
  3. If anything above failed (e.g. GitHub rate limit): gh auth login, then chezmoi apply.
MSG
EOF
chmod 755 "$home/bootstrap.sh"
in-target chown "$user:$user" "/home/$user/bootstrap.sh"

# Login screen on Wayland from the first boot (#66): forky's desktop task brings no X server, and SDDM's default
# greeter needs one. The labwc role writes the same two files on the first chezmoi apply.
mkdir -p /target/etc/sddm.conf.d /target/etc/sddm/no-xsessions
cat >/target/etc/sddm.conf.d/10-wayland.conf <<'SDDM'
# Managed by ansible (dotfiles labwc role); first written by the installer.
[General]
DisplayServer=wayland

[Wayland]
CompositorCommand=weston --shell=kiosk --config=/etc/sddm/weston.ini

[X11]
SessionDir=/etc/sddm/no-xsessions
SDDM
{
    echo '# Managed by ansible (dotfiles labwc role): the compositor of the SDDM greeter.'
    echo '[core]'
    echo 'idle-time=0'
    # Retina MacBooks (as setup.yml's hidpi): the greeter at 2x.
    if grep -qE '^MacBookPro1[0-9],|^MacBook(8|9|10),' /sys/class/dmi/id/product_name 2>/dev/null; then
        printf '[output]\nname=eDP-1\nscale=2\n'
    fi
} >/target/etc/sddm/weston.ini

# Wi-Fi used during the install (preseeded or picked on the target) -> explicit NetworkManager profile.
# netcfg's handover doesn't connect on WPA2/WPA3 mixed-mode APs with brcmfmac (MacBook BCM43602);
# WPA2-PSK with PMF optional does.
ssid=$(debconf-get netcfg/wireless_essid 2>/dev/null || true)
psk=$(debconf-get netcfg/wireless_wpa 2>/dev/null || true)
if [ -n "$ssid" ] && [ -n "$psk" ] && [ -d /target/etc/NetworkManager ]; then
    nm=/target/etc/NetworkManager/system-connections
    mkdir -p "$nm"
    f="$nm/$(printf %s "$ssid" | tr -c 'A-Za-z0-9._-' _).nmconnection"
    cat >"$f" <<EOF
[connection]
id=$ssid
type=wifi
autoconnect=true
autoconnect-priority=10

[wifi]
mode=infrastructure
ssid=$ssid

[wifi-security]
key-mgmt=wpa-psk
psk=$psk
pmf=2

[ipv4]
method=auto

[ipv6]
method=auto
EOF
    chmod 600 "$f"
fi
