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
EOF
chmod 755 "$home/bootstrap.sh"
in-target chown "$user:$user" "/home/$user/bootstrap.sh"
