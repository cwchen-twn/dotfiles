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
| desktop | brave, vscode, alacritty, libinput-gestures, shutter, libreoffice, balena-etcher, calibre, obsidian, dbeaver, fcitx5 |
| extras | postgres, openvpn (2.x), openfortivpn, nordvpn, nvidia-cuda, claude-code |

Core tools are always installed: git, gh, glab, tea, fish, tmux, neovim, lazygit, ripgrep, fd, fzf, jq, sops, age, gitleaks, rtk, codebase-memory-mcp and the Bitwarden CLI.
System info / monitoring: fastfetch, btop, duf, gdu (mise); inxi (`sysinfo`), lm-sensors, smartmontools, iotop-c, nethogs,
nvtop, s-tui, acpi, speedtest-cli (apt); `batinfo`, `battery` (TLP health) and `sudo intel_gpu_top` on MacBooks.
The JetBrainsMono Nerd Font is installed when any desktop app is selected.

Network toolbox (apt unless noted; `myip` and `ports` are fish functions):

| Area | Tools |
|---|---|
| DNS | dig, nslookup, host (bind9-dnsutils), whois, doggo (mise) |
| Reachability / path | mtr, traceroute, arping, gping (mise) |
| Scanning / discovery | nmap (+ ncat), arp-scan (`sudo arp-scan -l`, in /usr/sbin), netcat |
| HTTP / TLS / APIs | xh, grpcurl, websocat (mise), testssl (Debian's name for testssl.sh), sslscan |
| Mail | swaks |
| Capture | tcpdump, tshark, ngrep (with sudo) |
| Bandwidth | iperf3, iftop, nload, nethogs, speedtest-cli |
| Wi-Fi / links | wavemon, iw, ethtool, nmcli |
| Addressing / sockets | ipcalc, socat, `myip` (public IPv4/IPv6 + local), `ports` (listeners + processes) |

Change the selection later with `chezmoi init --prompt` (or `chezmoi edit-config`), then `chezmoi apply`.
Deselecting something stops managing it; it does not uninstall it.

Bootstrap order (`home/.chezmoiscripts/`): install ansible, install mise, fetch the age key from Vaultwarden, log in to GitHub
(`gh`, optional: Ansible and mise download ~20 release binaries through the GitHub API, which allows only 60 anonymous
requests/h; with the login they use `gh auth token`), apply the dotfiles,
then run the Ansible playbook, `mise install`, fisher, the ssh-agent unit, and the Claude plugins/MCP servers. Finally, create this machine's SSH key if it's missing.

Afterwards: log out and back in (login shell, groups, desktop settings), then run `register-ssh-key` (fish). It logs in to
`gh`, `glab` and `tea` where needed and uploads the key. If you skipped the GitHub login and a step hit the rate limit:
`gh auth login`, then `chezmoi apply` (re-runs only what changed or failed).

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
  hibernation (`install/debian/hibernate.sh`: resumes from a swap partition >= RAM, else creates a RAM + 2 GB swap file),
  a quieter `mbpfan` curve, a macOS-like touchpad (tap to click, natural scrolling, two-finger right-click:
  `/etc/X11/xorg.conf.d/50-macbook-touchpad.conf`), and the keyboard backlight (Fn+F5/F6 via `brightnessctl`, off after
  60 s idle via `~/.local/bin/kbd-backlight-idle`, `KBD_IDLE_SECS` to change).
- FaceTime camera in browsers/Meet: facetimehd reports its sizes as a range, which Chromium's camera code skips (also
  through PipeWire), so Brave/Chrome see no camera. Before a call run `camera-on` and pick "FaceTime HD (relay)": a
  v4l2loopback camera (`/dev/video10`, fixed 1280x720) fed by ffmpeg. `camera-off` afterwards (the LED goes off).
- The build asks for the swap partition size (default 16 GB; >= RAM to hibernate).
- The `lxqt` Ansible role sets only specific keys in `~/.config/lxqt/*.conf` (LXQt rewrites those files, so chezmoi doesn't
  own them): on Retina MacBooks 2x scaling (`Xft.dpi: 192` in `~/.Xresources`, which Qt, Brave, GTK via `GDK_SCALE` and
  Alacritty all follow); system-wide dark mode (LXQt theme/palette, GTK, freedesktop color-scheme); Brave as default browser; Alacritty as terminal
  (Ctrl+Alt+T); panel quick launch + menu favorites (file manager, Brave, Alacritty, VS Code, Obsidian, DBeaver, as selected).
  Also 4 workspaces in a row for the gestures.
- Retina boot and login (macbook role): GRUB console font at 36 px, console in Terminus 16x32, SDDM greeter at 2x.
- Boot look (`boottheme` role, desktop machines): GRUB menu, Plymouth splash and SDDM login share one
  [sddm-astronaut](https://github.com/Keyitdev/sddm-astronaut-theme) preset (default `black_hole`, GPL-3.0, pinned
  commit). The login uses the theme itself (preset selected via `Themes/astronaut.conf.user`); the GRUB and Plymouth
  themes are generated from the preset's wallpaper and palette, sized for the screen. Switch with `boottheme_preset` and
  the colors in `ansible/roles/boottheme/defaults/main.yml`. Preview the login without logging out:
  `sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/sddm-astronaut-theme`. More themes: gnome-look.org (GRUB
  Themes), store.kde.org (SDDM Login Themes, Qt6 only), r/unixporn.
- fcitx5 (desktop app): US keyboard + Chewing (`~/.config/fcitx5/profile`, chezmoi; stop fcitx5 before editing it by
  hand, it saves its profile on exit). Ctrl+Space toggles, Shift_L switches temporarily. CJK font: `fonts-noto-cjk`.
- Brave: fixed defaults are managed policies (`/etc/brave/policies/managed/dotfiles.json`: no Rewards/Wallet/VPN/News/Leo,
  no password manager, Bitwarden extension forced). Bookmarks, extensions and settings travel with Brave Sync;
  the profile directory is deliberately not in this repo.
- Three-finger drag (MacBooks): [linux-3-finger-drag](https://github.com/lmr97/linux-3-finger-drag), built by the macbook
  role into `~/.cargo/bin` (needs the rust runtime), run by the `three-finger-drag` systemd user unit. Xorg's libinput
  driver can't do it natively; the program grabs the touchpad and mirrors everything else to a clone.
- `libinput-gestures` (desktop app, autostarted; `~/.config/libinput-gestures.conf`): 4 fingers left/right switch workspace,
  up shows the desktop, down opens the menu; pinch zooms (3 fingers are taken by the drag, as on macOS).
- Leave the Wi-Fi SSID empty to pick the network and type the passphrase on the target instead (the installer may then
  also ask to retry mounting the stick: answer Yes).

## Where things come from

| Source | Tools |
|---|---|
| apt / Homebrew (Ansible) | shell + base CLI, docker, tailscale, GUI apps, postgres, VPNs, CUDA |
| mise (`~/.config/mise/config.toml`) | node, pnpm, go, java, maven, gradle, kubectl, helm, kubectx, terraform, lazygit, neovim, glab, tea, sops, age, rtk, ... |
| own installers | rustup (`~/.cargo`), bun (`~/.bun`), uv and claude (`~/.local/bin`) |

Rule: nothing is copied into `/usr/local/bin` or `/opt` by hand. Anything not covered above goes in `~/.local/bin`.

## Performance (8 GB machines)

- Memory: zram swap (zstd, half of RAM up to 4 GB, priority over the disk swap), `vm.swappiness=180`, and `earlyoom`
  (kills the heaviest browser tab before the machine freezes; never Xorg/SDDM/the session). Check: `zramctl`,
  `systemctl status earlyoom`.
- On demand instead of at boot: Docker (`docker.socket`: the first `docker` command starts it; containers don't
  auto-start at boot), VPNs (see [VPNs](#vpns); NordVPN's socket unit can't start it lazily), PostgreSQL (`pgstart` / `pgstop`). ModemManager, cups-browsed and
  NetworkManager-wait-online are off; printing still works through `cups.socket`.
- Brave: Memory Saver on (balanced), no background mode, Dark Reader installed by policy (`brave://policy`).
- MacBook: turbo boost only on AC (`/etc/tlp.d/50-dotfiles.conf`).

## What this repo manages, and how to list it

| What | Command |
|---|---|
| mise tools and versions | `mise ls --current`; missing: `mise ls --missing`; updates: `mise outdated`, `mise up` |
| files deployed by chezmoi | `chezmoi managed`; drift: `chezmoi status`, `chezmoi diff` |
| this machine's selections | `chezmoi data \| jq '{devops,runtimes,desktop,extras}'` (change: `chezmoi init --prompt`) |
| apt / Homebrew packages | `ansible/roles/*/tasks/main.yml`: base (core + monitoring), desktop (`apt_map`), devops, runtimes, macbook, vpn, nvidia, postgres; `ansible-playbook ansible/setup.yml --list-tasks` |
| what apt installed by hand | `apt-mark showmanual` |
| Claude Code plugins / MCP | `claude plugin list`, `claude mcp list` |
| Neovim plugins / LSP tools | `:Lazy`, `:Mason` (lockfile: `~/.config/nvim/lazy-lock.json`) |
| Neovim keymaps | `nvim-keys` (cheat sheet generated from the live config), `:Cheatsheet`, or press Space and wait |

## Secrets

The repo is public. Secrets are never committed in plain text:

- Whole files (e.g. `~/.ssh/config.d/work`) are age-encrypted chezmoi files (`encrypted_*.age`).
- The age identity lives in the personal Vaultwarden (`vw.chenantunez.com`, item `chezmoi-age-key`). It is fetched once to
  `~/.config/chezmoi/key.txt`; use `bwp` (fish function) for the personal vault.
- SSH private keys are per machine and never synced. Each new key is registered with GitHub, GitLab and Gitea.
- Git HTTPS credentials come from `gh`, `glab` and `tea` credential helpers, not from `~/.git-credentials`.
- `pre-commit install` enables gitleaks and an internal-IP check.

## Kubernetes access

Each cluster has a `cwchen-admin` ServiceAccount (kube-system) bound to `cluster-admin`, with a manually created
token Secret: it never expires and is revoked by deleting the Secret or the binding. No copied
`admin.conf`/`k3s.yaml` certs (one-year expiry, shared identity, can't be revoked); those stay on the control nodes as break-glass.

- `KUBECONFIG=~/.kube/config:~/.kube/clusters.yaml`. `clusters.yaml` is age-encrypted in chezmoi (clusters, CA, tokens);
  `~/.kube/config` is unmanaged and only holds current-context (kubectx writes there), so `chezmoi diff` stays clean.
- New cluster or rotation: `kube-admin-sa <context>` (applies the SA/Secret/binding using the context's current
  credentials and writes the token user into `clusters.yaml`), then `chezmoi add --encrypt ~/.kube/clusters.yaml`.
- Revoke: `kubectl -n kube-system delete secret cwchen-admin-token`.
- Reaching the API servers: the work clusters over the HIS VPN (`hisvpn`), the personal one over Tailscale only.

## VPNs

All on demand (nothing connects at boot); profiles are age-encrypted in chezmoi and installed root-only to `/etc` by
`run_onchange_after_55-vpn-configs` for the distro's systemd template units.

| VPN | Client (extra) | Start / stop | Unit |
|---|---|---|---|
| HIS | OpenVPN 2.x (`openvpn`) | `hisvpn` / `hisvpnstop` | `openvpn-client@dgtic` (`/etc/openvpn/client/dgtic.{conf,auth}`) |
| MITIC | openfortivpn (`openfortivpn`) | `miticvpn` / `miticvpnstop` | `openfortivpn@mitic` (`/etc/openfortivpn/mitic.conf`) |
| NordVPN | nordvpn (`nordvpn`) | `nordvpnstart` / `nordvpnstop`, then `nordvpn connect` | `nordvpnd` |

`vpns` shows the state of each (plus Tailscale). OpenVPN 2.x rather than OpenVPN 3: it reads the saved login file,
handles the HIS server's CBC + comp-lzo, and runs as a plain systemd unit. On macOS, import the profile into Tunnelblick.

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
