#!/bin/sh
# preseed/late_command (inside the installer, target mounted at /target): leave a one-shot bootstrap script
# that applies the dotfiles on first login. It stays manual because it needs you for the Vaultwarden unlock
# and the sudo password.
set -u
user=$1
home=/target/home/$user

cat > "$home/bootstrap.sh" <<'EOF'
#!/bin/sh
# Run once after the first login: installs chezmoi and applies the dotfiles (asks what to install).
set -eu
src="$HOME/Documents/Gitea/cwchen-twn/dotfiles"
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin" \
    init --apply --source "$src" https://git.chenantunez.com/cwchen-twn/dotfiles.git
rm -f "$0"
cat <<'MSG'

Done. Next:
  1. Log out and back in: fish as login shell, docker/input groups, LXQt HiDPI and favorites.
  2. register-ssh-key   (fish: logs in to gh/glab/tea and uploads this machine's SSH key)
  3. If anything above failed (e.g. GitHub rate limit): gh auth login, then chezmoi apply.
MSG
EOF
chmod 755 "$home/bootstrap.sh"
in-target chown "$user:$user" "/home/$user/bootstrap.sh"

# Wi-Fi used during the install (preseeded or picked on the target) -> explicit NetworkManager profile.
# netcfg's handover doesn't connect on WPA2/WPA3 mixed-mode APs with brcmfmac (MacBook BCM43602);
# WPA2-PSK with PMF optional does.
ssid=$(debconf-get netcfg/wireless_essid 2>/dev/null || true)
psk=$(debconf-get netcfg/wireless_wpa 2>/dev/null || true)
if [ -n "$ssid" ] && [ -n "$psk" ] && [ -d /target/etc/NetworkManager ]; then
    nm=/target/etc/NetworkManager/system-connections
    mkdir -p "$nm"
    f="$nm/$(printf %s "$ssid" | tr -c 'A-Za-z0-9._-' _).nmconnection"
    cat > "$f" <<EOF
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
