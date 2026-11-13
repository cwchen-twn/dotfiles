# dotfiles

Personal dotfiles for Debian/Ubuntu/Lubuntu and macOS, managed with [chezmoi](https://www.chezmoi.io/).
chezmoi deploys the configs, [Ansible](ansible/) installs system packages (apt/Homebrew), and
[mise](https://mise.jdx.dev/) manages CLI tools and language runtimes.

Primary repo: https://git.chenantunez.com/cwchen-twn/dotfiles (mirrored to GitHub).

## New machine

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin init --apply https://git.chenantunez.com/cwchen-twn/dotfiles.git
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
```
