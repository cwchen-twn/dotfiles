# CLAUDE.md

Personal dotfiles for Debian/Ubuntu and macOS: chezmoi deploys `home/` (`.chezmoiroot`), Ansible (`ansible/`)
installs system packages, mise manages CLI tools and runtimes. This file is not deployed. The README's "Layout" and
"Where things come from" sections are the map; the shared agent rules are `home/dot_config/agents/AGENTS.md`.

**Public repo:** no secrets, internal hostnames or IPs in files or commit messages. Secrets are age-encrypted chezmoi
files (`encrypted_*.age`).

## Commands

Tool versions are pinned in `mise.toml`; the Makefile puts them first on PATH. Run `make help` for the full list.

- `make init`: install the pinned tools and the pre-commit hooks (once per clone).
- `make tidy`: format scripts (shfmt), fish, Lua (stylua), Python (ruff) and Markdown.
- `make lint`: shellcheck, shfmt, fish, stylua, ruff, ansible-lint, markdownlint, actionlint, the public-repo check
  and the pre-commit file checks. chezmoi templates are rendered first (`build/rendered/`) and linted as output.
- `make test`: dry-run `chezmoi apply` of the whole source state into an empty directory, every option selected
  (`ci/chezmoi.toml`).
- `make audit`: the gate, `lint` + `test` + gitleaks over the history. Never bypassed.
- `make apply/dry`: what `chezmoi apply` would change on this machine.

## Git profile

Overrides for the shared `git-flow` skill (`home/dot_config/agents/skills/git-flow`):

```text
issue-first: yes                 # every change: issue -> <issue>-<slug> branch -> PR -> merge
branch: <issue>-<slug>
merge: fast-forward-only
commit-style: .claude/skills/commit-style
tags: none
gate: make audit                 # pre-commit hook and Gitea Actions (.gitea/workflows/ci.yaml)
deploy: chezmoi apply on each machine (scripts in home/.chezmoiscripts rerun when their inputs change)
```

Gitea (`git.chenantunez.com/cwchen-twn/dotfiles`, `tea`) is the source; GitHub is a push mirror. Issues, PRs and
merges happen on Gitea only.
