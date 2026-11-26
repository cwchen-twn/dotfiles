# dotfiles

Personal dotfiles for Debian/Ubuntu/Lubuntu and macOS, managed with [chezmoi](https://www.chezmoi.io/).
chezmoi deploys the configs, [Ansible](ansible/) installs system packages (apt/Homebrew), and
[mise](https://mise.jdx.dev/) manages CLI tools and language runtimes.

Primary repo: <https://git.chenantunez.com/cwchen-twn/dotfiles> (mirrored to GitHub).

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
| desktop | brave, vscode, alacritty, libinput-gestures, libreoffice, balena-etcher, calibre, obsidian, dbeaver, fcitx5 |
| extras | postgres, openvpn (2.x), openfortivpn, nordvpn, nvidia-cuda, claude-code |

Core tools are always installed: git, gh, glab, tea, fish, tmux, neovim, lazygit, ripgrep, fd, fzf, jq, sops, age,
gitleaks, rtk, codebase-memory-mcp and the Bitwarden CLI. System info / monitoring: fastfetch, btop, duf, gdu (mise);
inxi (`sysinfo`), lm-sensors, smartmontools, iotop-c, nethogs, nvtop, s-tui, acpi, speedtest-cli (apt); `mem-stat [N]`
(memory summary, swap, top N apps), `batinfo`, `battery` (TLP health) and `sudo intel_gpu_top` on MacBooks. The
JetBrainsMono Nerd Font is installed when any desktop app is selected, and on Linux it is the default `monospace`
(`~/.config/fontconfig/conf.d/50-monospace.conf`), so every terminal and code font gets Nerd Font icons.

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

Bootstrap order (`home/.chezmoiscripts/`): install ansible, install mise, fetch the age key from Vaultwarden, log in to
GitHub (`gh`, optional: Ansible and mise download ~20 release binaries through the GitHub API, which allows only 60
anonymous requests/h; with the login they use `gh auth token`), apply the dotfiles, then run the Ansible playbook,
`mise install`, fisher, the ssh-agent unit, and the Claude plugins/MCP servers. Finally, create this machine's SSH key
if it's missing.

Afterwards: log out and back in (login shell, groups, desktop settings), then run `register-ssh-key` (fish). It logs in
to `gh`, `glab` and `tea` where needed and uploads the key. If you skipped the GitHub login and a step hit the rate
limit: `gh auth login`, then `chezmoi apply` (re-runs only what changed or failed).

## Fresh Debian install from USB (laptops)

`install/debian/` builds an unattended Debian netinst ISO: Debian testing (forky) + LXQt on Wayland, no disk
encryption, GPT/EFI/ext4. The ISO is the current stable netinst, whose kernel and firmware know the MacBook; its
preseed installs forky (`mirror/suite`, the installer's own components from the netinst's release), the same system
this repo runs (#57, #66).

```sh
install/debian/build-iso.sh --write /dev/sdX   # asks hostname, user, timezone, Wi-Fi, password; writes the stick
```

Boot the target from the stick (Mac: hold Option, pick "EFI Boot"). The default boot entry
**wipes the first non-USB disk** and installs without questions (~15 min, needs the Wi-Fi from the build).
The login screen already runs on Wayland (weston kiosk); log into "LXQt (Wayland)", then run `~/bootstrap.sh`, which
is the chezmoi one-liner above, and log in again with "LXQt (labwc)".

- `preseed.cfg.tmpl`: the installer answers. Secrets are filled in at build time and only live in the ISO
  (`~/.cache/debian-iso/`, mode 600).
- `pick-disk.sh`: picks the internal disk and zeroes its old partition tables (used drives, APFS, LVM).
- `late.sh`: points SDDM's greeter at weston (2x on Retina MacBooks; forky's desktop task brings no X server), drops
  `~/bootstrap.sh` and writes a NetworkManager profile for the install's Wi-Fi (WPA2-PSK, PMF optional:
  NetworkManager's automatic choice of WPA3-SAE fails on WPA2/WPA3 mixed APs with the MacBook's Broadcom chip).
- On MacBooks the `macbook` Ansible role runs automatically (DMI product name): Broadcom Wi-Fi firmware, `mbpfan`,
  `tlp`, F1-F12 as function keys, the FaceTime HD camera (`facetimehd` driver via DKMS + firmware extracted from Apple's
  update), hibernation (`install/debian/hibernate.sh`: resumes from a swap partition >= RAM, else creates a RAM + 2 GB
  swap file; the Wi-Fi driver `brcmfmac` is unloaded around every suspend/hibernate by
  `/usr/lib/systemd/system-sleep/50-dotfiles-macbook`: otherwise resume hangs and Wi-Fi doesn't come back after
  suspend), lid closed = suspend, then hibernate after 2 h on battery (plain suspend on AC; logind handles the lid, not
  LXQt), hibernate at 5% battery, three-finger drag restarted after every wake-up, a quieter `mbpfan` curve, a
  macOS-like touchpad (tap to click, natural scrolling, two-finger right-click: labwc's `rc.xml`), and the keyboard
  backlight (Fn+F5/F6 via `brightnessctl`, off after 60 s idle: swayidle runs `~/.local/bin/kbd-backlight-idle`).
- FaceTime camera in browsers/Meet: facetimehd reports its sizes as a range, which Chromium's camera code skips (also
  through PipeWire), so Brave/Chrome see no camera. Before a call run `camera-on` and pick "FaceTime HD (relay)": a
  v4l2loopback camera (`/dev/video10`, fixed 1280x720) fed by ffmpeg. `camera-off` afterwards (the LED goes off).
- The build asks for the swap partition size (default 16 GB; >= RAM to hibernate).
- The `lxqt` Ansible role sets only specific keys in `~/.config/lxqt/*.conf` (LXQt rewrites those files, so chezmoi
  doesn't own them): system-wide dark mode (LXQt theme/palette, GTK, freedesktop color-scheme);
  Brave as default browser; LibreOffice as default for office documents (Calibre claims .docx/.odt too), on its Qt6
  backend (`SAL_USE_VCLPLUGIN=qt6`: LXQt 2.x themes only Qt6, so the Qt5 backend stayed light) with Colibre Dark
  icons and a light page in the dark UI (Appearance "Light": documents' own black text and borders stay readable;
  `/usr/lib/libreoffice/share/registry/zz-dark.xcd`); Alacritty as terminal (Ctrl+Alt+T); panel quick launch and
  menu favorites (file manager, Brave, Alacritty, VS Code, Obsidian, DBeaver, as selected); panel widgets
  (`lxqt_panel_plugins`: Debian default minus mount and the X11-only tray/keyboard widgets, plus the CPU monitor).
- File manager bookmarks (pcmanfm-qt's side pane, GTK file dialogs): Documents, Downloads, Pictures and
  `~/Documents/Gitea`, each only if the folder exists (`~/.config/gtk-3.0/bookmarks`, chezmoi). One added in the GUI
  makes `chezmoi apply` ask: add it to the source too.
- Retina boot and login: GRUB console font at 36 px and console in Terminus 16x32 (macbook role); the SDDM greeter
  runs on Wayland inside weston's kiosk shell, 2x on Retina (`/etc/sddm/weston.ini`, labwc role). Locked out by a
  greeter that doesn't start: Ctrl+Alt+F2, log in, `sudo rm /etc/sddm.conf.d/10-wayland.conf`, then
  `sudo systemctl restart sddm`.
- Look (`boottheme` role, desktop machines), Catppuccin Mocha throughout:
  - GRUB: [AstronautGrub](https://github.com/Flava-Clown/AstronautGrub) (pinned; `boottheme_grub_variant` astronaut
    or astronaut_orange). Drawn for 1920x1080, so on Retina its fonts and rows are scaled ×1.6
    (`files/scale-grub-theme.py`) and JetBrains Mono is regenerated at those sizes.
  - Boot splash and SDDM login: AstronautGrub's astronaut image; the login is the
    [sddm-astronaut](https://github.com/Keyitdev/sddm-astronaut-theme) `black_hole` layout (GPL-3.0, pinned),
    recolored key by key in `Themes/astronaut.conf.user`.
  - Desktop wallpaper (lxqt role): `jellyfish` from
    [walls-catppuccin-mocha](https://github.com/orangci/walls-catppuccin-mocha).
  - System monitor on the desktop: two Conky windows (`~/.config/conky/`) under all other windows, one in each outer
    quarter of the screen. Right: CPU (per core, temperature, top apps) and memory (swap, top apps; processes summed
    per app as in `cpu-stat`/`mem-stat`). Left: disk and network I/O, GPU busy % (from i915 RC6 residency, no root)
    and battery draw in watts. About 2.5% of one core for both. Hide with `pkill conky`, restart with `conky-desktop`.
    Conky is upstream's AppImage through mise (Debian 13's 1.22 drew badly on Wayland).
  - Screen lock: swaylock on the login screen's astronaut background (`~/.local/bin/lock-screen`), run by swayidle
    after 10 min idle, before suspend/hibernate and on LXQt's Lock screen or Ctrl+Alt+L (`loginctl lock-session`).
    There is no password box: type the password and press Enter; the ring turns red on a wrong one.
  - None of this art has a license, so nothing is committed: images are fetched from pinned commits with sha256 checks
    and cropped to the screen in `/usr/local/share/backgrounds/dotfiles/`. Change one in `boottheme_images`
    (`ansible/roles/boottheme/defaults/main.yml`: name, url, sha256); drop an entry and that screen uses the login
    preset's own wallpaper. Preview the login without logging out:
    `sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/sddm-astronaut-theme`. More: gnome-look.org (GRUB
    Themes), store.kde.org (SDDM Login Themes, Qt6 only), r/unixporn.
- Wayland only (labwc role, #66): "LXQt (labwc)" on the login screen, the LXQt panel, desktop and apps on the
  [labwc](https://labwc.github.io) compositor (`/usr/local/bin/startlxqt-labwc`: Debian's lxqt-wayland-session plus
  the fcitx5 fix; on Debian 13, which lacks that package, our own start script). Nothing runs on X11 and the login
  screen lists no X11 session; the X server and xfwm4 stay installed only because sddm and the lxqt metapackage
  depend on them (removing them made apt pull in TigerVNC and 9wm). Xwayland runs X11-only apps. Each monitor gets
  its own scale, so a 1080p external screen is sharp at 1x next to the 2x panel: kanshi profiles in
  `~/.config/kanshi/config`, reapplied on plug/unplug. labwc's config is
  `~/.config/labwc/` (`rc.xml`: workspaces, touchpad, brightness/backlight/media/volume keys; `autostart`: fcitx5,
  kanshi, and swayidle for the keyboard backlight, the lock and screens off; `environment`). Print / Shift+Print:
  screenshot (`~/.local/bin/screenshot`). Gestures press keys through `~/.local/bin/sendkey` (wtype). Title bars in
  Catppuccin (`themerc-override`).
  alacritty takes no drag-and-drop on Wayland: `clip-img FILE` copies an image to the clipboard for Ctrl+V.
- fcitx5 (desktop app): US keyboard + Chewing (`~/.config/fcitx5/profile`, chezmoi; stop fcitx5 before editing it by
  hand, it saves its profile on exit). Ctrl+Space toggles, Shift_L switches temporarily. CJK font: `fonts-noto-cjk`.
- Brave: fixed defaults are managed policies (`/etc/brave/policies/managed/dotfiles.json`: no Rewards/Wallet/VPN/News/Leo,
  no password manager, Bitwarden extension forced). Bookmarks, extensions and settings travel with Brave Sync;
  the profile directory is deliberately not in this repo.
- Three-finger drag (MacBooks): [linux-3-finger-drag](https://github.com/lmr97/linux-3-finger-drag), built by the macbook
  role into `~/.cargo/bin` (needs the rust runtime), run by the `three-finger-drag` systemd user unit. libinput can't
  do it natively; the program grabs the touchpad and mirrors everything else to a clone.
- `libinput-gestures` (desktop app, autostarted; `~/.config/libinput-gestures.conf`): 4 fingers left/right switch workspace,
  up shows the desktop, down opens the menu; pinch zooms (3 fingers are taken by the drag, as on macOS).
- Leave the Wi-Fi SSID empty to pick the network and type the passphrase on the target instead (the installer may then
  also ask to retry mounting the stick: answer Yes).

## Where things come from

| Source | Tools |
|---|---|
| apt / Homebrew (Ansible) | shell + base CLI, docker, tailscale, GUI apps, postgres, VPNs, CUDA |
| mise (`~/.config/mise/config.toml`) | node, pnpm, go, java, maven, gradle, kubectl, helm, kubectx, terraform, hcloud (Hetzner), wrangler (Cloudflare), lazygit, neovim, glab, tea, sops, age, rtk, ... |
| chezmoi script (`run_onchange_after_21-helm-plugins`) | the helm-diff plugin, pinned and signature-verified (Helm 4), bumped by Renovate |
| own installers | rustup (`~/.cargo`), bun (`~/.bun`), uv and claude (`~/.local/bin`) |
| Mason (nvim, `~/.local/share/nvim/mason/bin`) | every language server, plus tflint, actionlint, ansible-lint, shellcheck, ruff, prettier. Shared with Claude Code, never installed twice |

Rule: nothing is copied into `/usr/local/bin` or `/opt` by hand. Anything not covered above goes in `~/.local/bin`.

## Claude Code (extra `claude-code`)

One tool per job, all on the Team plan subscription with no API key. `run_onchange_after_40-claude.sh.tmpl`
installs the set listed in `home/.chezmoidata/claude.yaml`, uninstalls the ones replaced there, and warns about any
missing language server.

| Job | Tool | Where |
|---|---|---|
| Code structure (graph) | codebase-memory-mcp + its hooks and 3 agents | mise, `dot_claude/settings.json`, `dot_claude/agents/` |
| Symbol lookup (LSP) | `mason-lsp`: Claude's LSP tool on nvim's Mason servers | `claude-plugins/mason-lsp` (local marketplace `cwchen-local`) |
| Library docs | context7 (hosted MCP, API key) | registered by the claude script (MCP keys below) |
| Frontend design | frontend-design | plugin |
| Specs | OpenSpec (`openspec init` per repo, `/openspec-*` skills) | mise (npm) |
| New project (repo from the Gitea `project-template`, clone, `make init`, Claude on `/kickoff`) | `new-project` script + `kickoff` skill | `dot_local/bin/`, `dot_config/agents/skills/` |
| PRD, flows, sitemap, HTML mockups | `product-docs` skill | `dot_config/agents/skills/` |
| Git (issue → branch → draft PR → fast-forward merge, on tea, glab or gh) | `git-flow` skill + the repo's `## Git profile` | `dot_config/agents/skills/` |
| Task interface (`make help`, `make audit` = the gate) | `makefile` skill | `dot_config/agents/skills/` |
| Review | built-in `/code-review`, plus pr-review-toolkit | plugin |
| Security | built-in `/security-review`, plus security-guidance (patterns + Sonnet commit review; per-turn review off) | plugin, `env` in settings |
| Tests | `test-runner` agent (Haiku, `make audit`) | `dot_claude/agents/` |
| E2E | `e2e-tester` agent (Playwright MCP, scoped to the agent, drives the installed Brave) | `dot_claude/agents/`, mise (npm) |
| UI mockups | local HTML reviewed live in your browser; headless Brave screenshots are Claude's own layout check; Artifact only on request | `product-docs` skill |
| Web performance | `perf-auditor` agent (chrome-devtools-mcp, scoped; uses Brave where installed) | `dot_claude/agents/`, mise (npm) |
| Infra review | `infra-reviewer` agent (read-only plan, diff, lint) | `dot_claude/agents/` |
| Cloudflare | cloudflare plugin (skills) + its MCP server, by API token | plugin; server registered by the claude script |

- **Browsers:** every browser tool drives the installed Brave, so nothing downloads a second Chromium. A machine
  without Brave gets Playwright's Chromium for e2e-tester from the script, and perf-auditor there needs Chrome.
- **Agent-scoped MCP servers** start only when their agent runs, so they cost nothing while idle. The main
  session runs Opus; the agents run Sonnet or Haiku, because subagents draw on the same usage limits.
- **Language servers are installed by `chezmoi apply`**: `run_onchange_after_35-nvim-mason.sh` reruns whenever the
  nvim config changes, installs every Mason package the config declares (headless, `cwchen.util.mason_sync`), and
  repairs half-finished installs. Run it by hand in nvim with `:lua require("cwchen.util.mason_sync").run()`.
- **MCP keys (context7, cloudflare):** authenticated on every machine by API key, not OAuth. OAuth logins can't be
  copied between machines, because their refresh tokens rotate. Once per key, on any machine:
  `claude-mcp-key context7` (free key: context7.com/dashboard) and `claude-mcp-key cloudflare` (API token:
  dash.cloudflare.com -> My Profile -> API Tokens; scope it narrowly, no client-IP filter). That reads the key
  hidden, stores it age-encrypted in this repo, and applies; then commit the new `encrypted_*.age` through git-flow.
  `claude-mcp-headers` sends it as `Authorization: Bearer` (Claude's `headersHelper`), so the key never lands in
  `~/.claude.json`. Our user-scope `cloudflare` outranks the cloudflare plugin's own copy, and the plugin's skills
  stay. `chezmoi apply` reminds you about missing keys (`run_after_41`).
- **No "install <lang>-lsp plugin?" prompts:** Claude Code offers an official LSP plugin whenever its server binary is
  on PATH, and Mason puts them there. mason-lsp already serves those languages, so the claude script turns the
  suggestions off (`lspRecommendationDisabled`), and the Mason sync uninstalls servers the nvim config no longer
  declares.
- **Adding a language server:** add the Mason package to the nvim config (a LazyVim `lang.*` extra, or `servers` /
  `ensure_installed` in `nvim/lua/cwchen/plugins/editor.lua`), then add one entry to
  `claude-plugins/mason-lsp/.claude-plugin/plugin.json`.
  Claude maps servers by file extension, so `.yaml` always goes to yaml-language-server, and helm_ls and ansiblels
  run in nvim only.
- **Not installed on purpose:**
  - Serena, GitNexus, other code graphs (they duplicate the graph and LSP);
  - document-skills and example-skills (they duplicate the Team plan's skills and frontend-design);
  - the official `*-lsp` plugins (they need their own server binaries);
  - the terraform and kubernetes MCP servers (the CLIs are enough).

## Performance (8 GB machines)

- Memory: zram swap (zstd, half of RAM up to 4 GB, priority over the disk swap), `vm.swappiness=180`, and `earlyoom`
  (kills the heaviest browser tab before the machine freezes; never labwc/SDDM/the session). Check: `zramctl`,
  `systemctl status earlyoom`.
- On demand instead of at boot: Docker (`docker.socket`: the first `docker` command starts it; containers don't
  auto-start at boot), VPNs (see [VPNs](#vpns); NordVPN's socket unit can't start it lazily), PostgreSQL (`pgstart` /
  `pgstop`). ModemManager, cups-browsed and NetworkManager-wait-online are off; printing still works through
  `cups.socket`.
- Brave: Memory Saver on (balanced), no background mode, Dark Reader installed by policy (`brave://policy`).
- MacBook: turbo boost only on AC (`/etc/tlp.d/50-dotfiles.conf`).

## Tool updates

Stability first: one reviewed batch a month, not a stream of PRs.

| What | How it moves |
|---|---|
| This repo's pins: `mise.toml` (the gate's tools), pre-commit revs, CI actions, mise in CI, `rtk` and the neovim minor in the global mise config | **Renovate**, preset `renovate-config:stable` (`renovate.json`): one grouped PR "monthly tool updates" on the 1st, releases at least 14 days old; majors only after a tick on the Dependency Dashboard issue; nothing merges itself |
| `latest` entries in `~/.config/mise/config.toml` | `mise up` on each machine |
| nvim plugins (`lazy-lock.json`) and Mason's packages | `make nvim/update` (Lazy sync, Mason upgrade, `lazy-lock.json` copied back here). Renovate can't read them; its monthly PR is the reminder |
| apt packages | below |

Everything Renovate needs lives in `cwchen-twn/renovate-config`: the presets, the pinned Renovate version and the runner
(daily; it autodiscovers every `cwchen-twn` repo with a `renovate.json`). Apps and infra (rigel-ledger, hcloud, projects
from `project-template`) use the weekly `renovate-config:fast` preset instead, where patch bumps of mise and CI version
pins merge themselves on green CI.

## OS updates (Debian)

- **Security updates install themselves; the reboot is yours.** `unattended-upgrades` runs daily, Debian security only,
  only on AC power, and never reboots (Ansible base role, `/etc/apt/apt.conf.d/51unattended-upgrades-local`). When a
  newer kernel or a library waits for a reboot, `reboot-needed` says so: in yellow when a fish shell starts, and as a
  red "Reboot" line on the desktop (Conky). Log: `/var/log/unattended-upgrades/`.
- Everything else (point releases, Brave, Docker and other third-party repos): `sudo apt update && sudo apt upgrade`.
- **Release upgrades (Debian 13 trixie -> 14 forky) are manual.** The sources name the codename, not `stable`, so a new
  release changes nothing by itself. Wait for the x.1 point release, read the release notes, then
  `debian-release-upgrade --dry-run` and `debian-release-upgrade`. It refuses until the release is out and the
  machine is ready (AC power, free space, no broken or held packages). Then it backs up and switches the Debian
  sources, runs `upgrade --without-new-pkgs` and `full-upgrade`, and finishes with `chezmoi apply`. The Ansible
  playbook reruns whenever the OS codename changes, so Docker, Tailscale, PostgreSQL and the other repos follow.
- **Debian testing before the release** (#57): `debian-release-upgrade --testing` moves to the next codename while it
  is still testing, so the machine becomes the new stable at release. It adds apt-listbugs and apt-listchanges and
  keeps the running kernel as the boot fallback (out-of-tree drivers such as facetimehd). On testing,
  unattended-upgrades installs only security fixes; the rest is `sudo apt update && sudo apt full-upgrade`, reading
  what it removes. Docker has no repo for an unreleased Debian, so its newest stable one (trixie) is used.
- The hcloud server is different: it reboots itself at 04:00 when a patch needs it (see that repo's `host/CLAUDE.md`).

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
- The age identity lives in the personal Vaultwarden (`vw.chenantunez.com`, item `chezmoi-age-key`). It is fetched once
  to `~/.config/chezmoi/key.txt`; use `bwp` (fish function) for the personal vault.
- The SOPS age key for the infra repo (hcloud: k3s Secrets, Terraform/CLI secrets, `RESTIC_PASSWORD`) is a chezmoi
  encrypted file, `~/.config/sops/age/keys.txt`, on machines with the `terraform` or `kubernetes` devops group. mise
  uses it for project `[env]` SOPS files (`sops.age_key_file`), so inside hcloud the CLIs and Terraform are authenticated.
  **This makes the chezmoi key a master key for the infra too. Keep an offline copy of it, outside Vaultwarden:
  Vaultwarden runs in the cluster that these secrets restore.**
- Project tool versions belong in the project's `mise.toml` (hcloud pins terraform/helm to its CI versions); the
  global config here is `latest`.
- SSH private keys are per machine and never synced. Each new key is registered with GitHub, GitLab and Gitea.
- Git HTTPS credentials come from `gh`, `glab` and `tea` credential helpers, not from `~/.git-credentials`.
- `make init` installs the pre-commit hooks: gitleaks on staged changes, then `make audit` (which includes the
  internal-IP and work-domain check, `scripts/check-public.sh`).

## Printing, scanning and Bluetooth (Linux desktops)

Driverless: any printer that speaks IPP Everywhere / AirPrint (almost every network printer since ~2013) works
without a vendor driver; the same goes for its scanner (eSCL, via `sane-airscan`).

```sh
printers                     # printers on this network, sorted by name: model, host, color, duplex, scan, added?
printer-add 2 --default      # add #2 from that list (queue named after the model); no sudo (lpadmin group)
lp FILE                      # or any app's print dialog; lpstat -p shows queues
printer-rm 2                 # remove #2's queue (or printer-rm QUEUE; no argument lists the queues)
simple-scan                  # scan (scanimage -L lists scanners)
```

Queues point at the printer's `.local` name, so they survive DHCP changes. `cups-browsed` stays off: it would add
every printer on every network you join.

Bluetooth: `bluez` + `blueman` (tray icon, "Bluetooth Manager") + `pulseaudio-module-bluetooth` for headphones.
`bt-pair` scans classic Bluetooth only (12 s, almost no CPU, unlike Bluetooth Manager's search in a crowded room) and
lists what it hears; `bt-pair N` (or a name/address) pairs, trusts, connects and switches the sound to it. Headphones
must be in pairing mode, not just on; ignore `LE_<name>` entries (Fast Pair beacons, no audio).
Calls: headphones switch to the headset profile (HFP: mic on, phone-call quality) whenever an app records, e.g.
joining a Meet, and back to A2DP music quality afterwards (`~/.config/pulse/default.pa`, `auto_switch=2`). For better
voice quality, pick the MacBook's mic in the meeting instead and the headphones stay in A2DP. Pick the output in
the panel volume menu / `pavucontrol` (profile A2DP for music, HSP/HFP when you need the mic).

## Music (Navidrome)

- **Supersonic** (desktop app `supersonic`): a native Navidrome/Subsonic player, Go + libmpv, a few % CPU where the
  Navidrome web UI in a Brave tab took most of a core. From the Supersonic GitHub release via mise, libmpv2 and
  playerctl from apt, menu entry + panel favorite. Log in to the server once in the app (the password goes to the
  keyring, never to the repo).
- **Opus streaming:** `~/.config/supersonic/config.toml` is a chezmoi *modify* template that only enforces
  `[Transcoding]`: Opus at 192 kbps, transcoded by Navidrome on the server, about 5x less Wi-Fi traffic than the raw
  FLAC. Raw files again: `RequestTranscode = false` in `home/dot_config/supersonic/modify_config.toml`.
- **Media keys:** Fn+F7 / Fn+F8 / Fn+F9 = previous / play-pause / next for whichever player is active (MPRIS via
  playerctl: Supersonic, Brave, ...). The F-row is function keys on the MacBook, hence Fn.
- **Volume keys:** Fn+F10 / F11 / F12 = mute / down / up on the *current default output* (`~/.local/bin/vol`, 5% steps,
  max 100%, with a popup naming the device), bound in labwc's `rc.xml`. `media-check` verifies all six keys.
- **Volume icon:** `pasystray` in the tray instead of the panel's volume widget (removed: it controls one fixed
  device). Its icon follows the default output; scroll = volume, middle-click = mute, left-click = pick the output
  or input and move an app's sound to another device. Same 100% cap and 5% steps as the keys
  (`~/.config/autostart/pasystray.desktop`).
- **YouTube (Brave) on Intel graphics:** hardware video decoding needs two things on this 2015 MacBook Pro
  (Broadwell / Iris 6100), both set up by the desktop role:
  1. **enhanced-h264ify** (Brave policy): YouTube sends H.264 (up to 1080p). Broadwell decodes H.264 and VP8 in
     hardware but not the VP9/AV1 YouTube prefers.
  2. **`intel-media-va-driver-non-free`**: Chromium's VA-API decoder needs the driver's video post-processing
     (`VAEntrypointVideoProc`). Debian's free build leaves those GPU kernels out (7 entrypoints instead of 20), so
     every video fell back to CPU decoding (`FFmpegVideoDecoder`, renderer ~120% of a core for 1080p60) while
     `brave://gpu` still said "Hardware accelerated".

  On X11 (until #66) a third part was needed, Vulkan compositing (`--enable-features=Vulkan,DefaultANGLEVulkan,
  VulkanFromANGLE`): Chromium couldn't pass decoded frames zero-copy there (that needs EGL, blocked for Intel on X11)
  and its OpenGL conversion showed coloured squares. On Wayland Brave has EGL: `VaapiVideoDecoder` with hardware
  decoding and no extra flags (`media-check --decode`). Sources from that hunt: the i965 fork's
  [Chromium artefacts issue](https://github.com/irql-notlessorequal/intel-vaapi-driver/issues/26) and
  [known issues](https://github.com/irql-notlessorequal/intel-vaapi-driver/issues/12), the
  [Arch forum VA-API thread](https://bbs.archlinux.org/viewtopic.php?id=244031&p=45).
- **Brave CPU:** with the above, video and page raster run on the GPU; what stays is page
  JavaScript on each tab's main thread. Brave's task manager (Shift+Esc) or `cpu-stat` shows which tab. Dark Reader
  is gone for that reason (it restyles from a script in every tab on each DOM change); pages are darkened natively
  by Blink's `WebContentsForceDark` flag, set on every machine through the same launchers.
- **`brave-decode-test`** is the real proof: it plays a 1080p60 H.264 clip in a throwaway Brave (temporary profile,
  DevTools) and reports the decoder Chromium actually used, its media log and the CPU per process type.
- **mpv for long videos:** `yt URL` (or `yt` with a link on the clipboard) plays it in mpv, H.264 up to 1080p with
  VA-API (`~/.config/mpv/mpv.conf`). yt-dlp comes from mise, kept current with `mise up` (YouTube breaks old
  versions within weeks); Debian's is removed and pinned out.
- **`media-check`** lists every decision above against the running system (✔ / ✘ with a hint / – n/a), including
  the VA-API post-processing Brave needs, and `media-check --decode` runs `brave-decode-test`: the quick
  way to notice when Brave, PulseAudio or the OS changed something. The expected values sit at the top of the script.
- **`cpu-stat [SECONDS] [N]`** shows where the CPU goes right now: per app in % of one core over a few seconds
  (Brave split into renderer / gpu / network / ...), total busy %, Wi-Fi interrupts/s and the battery draw.
- **Bluetooth codec:** PulseAudio picks LDAC for headphones that offer it, about half a core to encode on a 2015
  dual-core. The `bt-codec` user service switches them to SBC XQ 552 kbps whenever they connect or come back from a
  call (`journalctl --user -u bt-codec` shows each switch); `BT_CODEC=` in the unit keeps PulseAudio's choice.
  Under PipeWire (Debian 14 desktops) WirePlumber picks the codec instead, from SBC XQ and SBC only
  (`~/.config/wireplumber/wireplumber.conf.d/51-bluez-codecs.conf`); bt-codec then stays off, PulseAudio's units
  are masked so it can't take the socket back, and Bluetooth audio comes from `libspa-0.2-bluetooth`.

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

DNS on HIS: the profile ignores the DNS the server pushes and sends every lookup to our own DNS server (set in
the encrypted profile; it forwards the rest upstream) via systemd-resolved, so private names are added there. The vpn
role makes `/etc/resolv.conf` the resolved stub (Tailscale then plugs MagicDNS into resolved instead of overwriting
the file). Check with `resolvectl status tun0`.

## DBeaver

When `dbeaver` is selected, chezmoi ships the connections (`workspace6/General/.dbeaver/`): `data-sources.json`
(connections, folders, SSH network profiles) and `credentials-config.json` (saved passwords; DBeaver's own encryption
uses a public key, so it's age-encrypted here like plaintext), plus a few default preferences (`create_`: written once,
then DBeaver owns them). SQL scripts stay local.

- SSH tunnels log in with a password, or with **Agent** auth (the machine's ssh-agent key), never a key path, so the
  files stay identical across machines. A new machine's public key must be added to those bastions once.
- DBeaver rewrites these files itself. After changing connections: `chezmoi re-add`, commit, push; elsewhere
  `chezmoi update` (with DBeaver closed). If both sides changed, re-add first, or `chezmoi apply` asks before overwriting.

## Daily use

```sh
chezmoi edit ~/.config/fish/config.fish   # edit source, apply on save with --apply
chezmoi re-add                             # pull changes made directly in $HOME back into the source
chezmoi diff && chezmoi apply
mise up                                    # upgrade tools
chezmoi cd && git commit -am "..." && git push
```

## Layout

```text
home/       chezmoi source state (.chezmoiroot)
ansible/    playbook + roles run by home/.chezmoiscripts/run_onchange_after_10-ansible.sh.tmpl
install/    unattended OS installers (Debian preseed ISO)
claude-plugins/  local Claude Code marketplace (mason-lsp), added by the claude script
Makefile    the task interface (`make help`); `make audit` is the gate run by pre-commit and CI
mise.toml   pinned versions of the gate's linters (not deployed: the machines' tools are in home/dot_config/mise)
scripts/    helpers the Makefile calls (template rendering, shell file discovery, public-repo check)
ci/         chezmoi fixture config for CI: every option selected, placeholder identity
.gitea/     Gitea Actions: make audit on every PR and on main
```

### Checks

`make init` once per clone, then `make audit` runs before every commit (pre-commit hook) and on every PR (Gitea
Actions). `make tidy` fixes formatting. Templates are rendered with `ci/chezmoi.toml` on Linux, so darwin-only
template branches are not rendered in CI.
