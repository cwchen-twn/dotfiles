# Shared agent instructions

Agent-agnostic instructions that every coding agent loads (Claude Code imports this from ~/.claude/CLAUDE.md).
Managed by chezmoi: edit with `chezmoi edit ~/.config/agents/AGENTS.md`.

## Machine conventions
- Interactive shell is fish; scripts are bash. Debian/Ubuntu (apt) or macOS (Homebrew).
- CLI tools and language runtimes are managed by mise (`~/.config/mise/config.toml`). Install with `mise use -g <tool>`, not with
  `sudo cp` into /usr/local/bin or ad-hoc curl installers. Project versions belong in the project's `mise.toml`.
- Dotfiles are managed by chezmoi (source: ~/Documents/Gitea/cwchen-twn/dotfiles, public repo). Edit the source, not the
  target file, and never put secrets, internal hostnames or IPs in it. Secrets go in age-encrypted chezmoi files.
- Git forges: GitHub (`gh`), GitLab (`glab`), self-hosted Gitea at git.chenantunez.com (`tea`).

## Shared skills
Skills live in ~/.config/agents/skills/<name>/SKILL.md and are symlinked into each agent's skills directory.
