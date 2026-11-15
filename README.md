# dotfiles

Personal dotfiles for Debian/Ubuntu/Lubuntu and macOS, managed with [chezmoi](https://www.chezmoi.io/).
chezmoi deploys the configs, [Ansible](ansible/) installs system packages (apt/Homebrew), and
[mise](https://mise.jdx.dev/) manages CLI tools and language runtimes.

Primary repo: https://git.chenantunez.com/cwchen-twn/dotfiles (mirrored to GitHub).

## New machine

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin init --apply \
    --source ~/Documents/Gitea/cwchen-twn/dotfiles https://git.chenantunez.com/cwchen-twn/dotfiles.git
```

`init` asks once per machine for the git identity, the SSH key name, and checklists of what to install:

| Category | Items |
|---|---|
| devops | kubernetes (kubectl, helm, kubectx), terraform, docker, tailscale |
| runtimes | node (+pnpm), go, java (+maven, gradle), rust, bun, python (uv) |
| desktop | brave, vscode, alacritty, picom, libinput-gestures, shutter, libreoffice, balena-etcher, calibre, obsidian, dbeaver, fcitx5 |
| extras | postgres, openvpn3, openfortivpn, nordvpn, nvidia-cuda, claude-code |

Core tools are always installed: git, gh, glab, tea, fish, tmux, neovim, lazygit, ripgrep, fd, jq, sops, age, gitleaks, rtk, codebase-memory-mcp and the Bitwarden CLI.
The JetBrainsMono Nerd Font is installed when any desktop app is selected.

Change the selection later with `chezmoi init --prompt` (or `chezmoi edit-config`), then `chezmoi apply`.
Deselecting something stops managing it; it does not uninstall it.

Bootstrap order (`home/.chezmoiscripts/`): install ansible, install mise, fetch the age key from Vaultwarden, apply the dotfiles,
then run the Ansible playbook, `mise install`, fisher, the ssh-agent unit, and the Claude plugins/MCP servers. Finally, create this machine's SSH key if it's missing.

## Fresh Debian install from USB (laptops)

`install/debian/` builds an unattended Debian netinst ISO: Debian stable + LXQt, no disk encryption, GPT/EFI/ext4.

```sh
install/debian/build-iso.sh --write /dev/sdX   # asks hostname, user, timezone, Wi-Fi, password; writes the stick
```

Boot the target from the stick (Mac: hold Option, pick "EFI Boot"). The default boot entry
**wipes the first non-USB disk** and installs without questions (~15 min, needs the Wi-Fi from the build).
After the first login run `~/bootstrap.sh`, which is the chezmoi one-liner above.

- `preseed.cfg.tmpl`: the installer answers. Secrets are filled in at build time and only live in the ISO (`~/.cache/debian-iso/`, mode 600).
- `pick-disk.sh`: picks the internal disk and zeroes its old partition tables (used drives, APFS, LVM).
- `late.sh`: drops `~/bootstrap.sh` and writes a NetworkManager profile for the install's Wi-Fi (WPA2-PSK, PMF optional:
  NetworkManager's automatic choice of WPA3-SAE fails on WPA2/WPA3 mixed APs with the MacBook's Broadcom chip).
- On MacBooks the `macbook` Ansible role runs automatically (DMI product name): Broadcom Wi-Fi firmware, `mbpfan`, `tlp`,
  F1-F12 as function keys, the FaceTime HD camera (`facetimehd` driver via DKMS + firmware extracted from Apple's update),
  and hibernation (`install/debian/hibernate.sh`: resumes from a swap partition >= RAM, else creates a RAM + 2 GB swap file).
- The build asks for the swap partition size (default 16 GB; >= RAM to hibernate).
- Leave the Wi-Fi SSID empty to pick the network and type the passphrase on the target instead (the installer may then
  also ask to retry mounting the stick: answer Yes).

## Where things come from

| Source | Tools |
|---|---|
| apt / Homebrew (Ansible) | shell + base CLI, docker, tailscale, GUI apps, postgres, VPNs, CUDA |
| mise (`~/.config/mise/config.toml`) | node, pnpm, go, java, maven, gradle, kubectl, helm, kubectx, terraform, lazygit, neovim, glab, tea, sops, age, rtk, ... |
| own installers | rustup (`~/.cargo`), bun (`~/.bun`), uv and claude (`~/.local/bin`) |

Rule: nothing is copied into `/usr/local/bin` or `/opt` by hand. Anything not covered above goes in `~/.local/bin`.

## Secrets

The repo is public. Secrets are never committed in plain text:

- Whole files (e.g. `~/.ssh/config.d/work`) are age-encrypted chezmoi files (`encrypted_*.age`).
- The age identity lives in the personal Vaultwarden (`vw.chenantunez.com`, item `chezmoi-age-key`). It is fetched once to
  `~/.config/chezmoi/key.txt`; use `bwp` (fish function) for the personal vault.
- SSH private keys are per machine and never synced. Each new key is registered with GitHub, GitLab and Gitea.
- Git HTTPS credentials come from `gh`, `glab` and `tea` credential helpers, not from `~/.git-credentials`.
- `pre-commit install` enables gitleaks and an internal-IP check.

## Daily use

```sh
chezmoi edit ~/.config/fish/config.fish   # edit source, apply on save with --apply
chezmoi re-add                             # pull changes made directly in $HOME back into the source
chezmoi diff && chezmoi apply
mise up                                    # upgrade tools
chezmoi cd && git commit -am "..." && git push
```

## Layout

```
home/       chezmoi source state (.chezmoiroot)
ansible/    playbook + roles run by home/.chezmoiscripts/run_onchange_after_10-ansible.sh.tmpl
install/    unattended OS installers (Debian preseed ISO)
```
