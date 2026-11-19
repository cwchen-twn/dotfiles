# Shared agent instructions

Agent-agnostic instructions that every coding agent loads (Claude Code imports this from ~/.claude/CLAUDE.md).
Managed by chezmoi: edit with `chezmoi edit ~/.config/agents/AGENTS.md`.

## Machine conventions

- Interactive shell is fish; scripts are bash. Debian/Ubuntu (apt) or macOS (Homebrew).
- CLI tools and language runtimes are managed by mise (`~/.config/mise/config.toml`). Install with
  `mise use -g <tool>`, not with `sudo cp` into /usr/local/bin or ad-hoc curl installers. Project versions belong in the
  project's `mise.toml`.
- Language servers (and the linters nvim uses) are installed by nvim's Mason only, and shared with Claude Code through
  `~/.local/share/nvim/mason/bin` on PATH. Never install a second copy through mise, npm or rustup. Exception: a repo's
  `mise.toml` may pin the linters its `make audit` gate runs, so local runs and CI use the same versions.
- Dotfiles are managed by chezmoi (source: ~/Documents/Gitea/cwchen-twn/dotfiles, public repo). Edit the source, not the
  target file, and never put secrets, internal hostnames or IPs in it. Secrets go in age-encrypted chezmoi files.
- Git forges: GitHub (`gh`), GitLab (`glab`), self-hosted Gitea at git.chenantunez.com (`tea`).

## Shared skills

Skills live in ~/.config/agents/skills/<name>/SKILL.md and are symlinked into each agent's skills directory.

## Working model

Every project is driven the same way. Follow it unless the repo's CLAUDE.md/AGENTS.md says otherwise.

- **Tasks run through make.** Run `make help` first. `make audit` is the gate before every commit and in CI, and it is
  never bypassed (no `--no-verify`). A new script or recurring command becomes a make target. See the `makefile` skill.
- **Git runs through the `git-flow` skill:**
  - issue → `<issue>-<slug>` branch → draft PR/MR → fast-forward merge;
  - the repo's `## Git profile` overrides the defaults.
  - Commit, push, open PRs, merge or tag only when asked.
- **New apps or UI features start with the `product-docs` skill:** PRD → Mermaid flows and sitemap → HTML mockups
  reviewed live in the local browser before any code. Then an OpenSpec change (`/opsx:propose`) where the repo uses OpenSpec.
- **The main session plans, implements and decides; subagents return conclusions, not logs.** Delegate:
  - `test-runner` after a change and before committing (runs `make audit`, reports failures only);
  - `e2e-tester` for web UI flows and mockup comparison (Playwright);
  - `infra-reviewer` before committing Terraform, Helm, Ansible, Kubernetes or CI changes (read-only checks);
  - `perf-auditor` when performance is in question or before a web release (Chrome DevTools traces);
  - `codebase-memory-scout` (or `Explore`) for broad code questions.

  Run independent agents in parallel. Don't delegate what a couple of direct tool calls can answer.
- **Before a PR:**
  - `/code-review` on the diff;
  - `/security-review` when auth, input handling, secrets or crypto changed;
  - `infra-reviewer` for infra diffs.
- **Usage limits are shared.** Subagents run on Sonnet or Haiku. Keep the main context lean: delegate noisy output and
  `/compact` at natural breakpoints, rather than relying on a huge context.
