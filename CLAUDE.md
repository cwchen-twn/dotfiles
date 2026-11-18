# CLAUDE.md

Personal dotfiles for Debian/Ubuntu and macOS: chezmoi deploys `home/` (`.chezmoiroot`), Ansible (`ansible/`)
installs system packages, mise manages CLI tools and runtimes. This file is not deployed. The README's "Layout" and
"Where things come from" sections are the map; the shared agent rules are `home/dot_config/agents/AGENTS.md`.

**Public repo:** no secrets, internal hostnames or IPs in files or commit messages. Secrets are age-encrypted chezmoi
files (`encrypted_*.age`).

## Git profile

Overrides for the shared `git-flow` skill (`home/dot_config/agents/skills/git-flow`):

```
issue-first: yes                 # every change: issue -> <issue>-<slug> branch -> PR -> merge
branch: <issue>-<slug>
merge: fast-forward-only
commit-style: .claude/skills/commit-style
tags: none
gate: none yet                   # planned: make audit (shellcheck, chezmoi verify), see the makefile skill
deploy: chezmoi apply on each machine (scripts in home/.chezmoiscripts rerun when their inputs change)
```

Gitea (`git.chenantunez.com/cwchen-twn/dotfiles`, `tea`) is the source; GitHub is a push mirror. Issues, PRs and
merges happen on Gitea only.
