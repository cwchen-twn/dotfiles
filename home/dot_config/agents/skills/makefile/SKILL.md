---
name: makefile
description: The Makefile is every project's single task interface, with the same targets everywhere (help, init, tidy, lint, test, audit, build, run, updatedep, test/e2e, plan/diff/deploy). Use when scaffolding a new repo, adding a script or recurring command to a project, wiring pre-commit or CI checks, retrofitting a repo that has no Makefile, or when unsure how to build, test or run a project. Run `make help` first in any repo that has one.
---

# Makefile: one task interface for every project

**Who does what**, with nothing done twice:

| Tool | Owns |
|---|---|
| **mise** (`mise.toml`) | tool and runtime versions |
| **Make** | every task: build, test, lint, run, deploy, maintenance scripts |
| **Mason** (nvim) | editor language servers |

- Don't use mise tasks or package.json scripts as an entry point. A `package.json` script may exist, but **a make
  target wraps it**.
- pre-commit, CI and humans all call the same targets, so "works locally" means "works in CI".

## Using an existing Makefile

1. Run `make help`.
2. Use the targets: `make test`, not `go test ./...`.
3. **`make audit` is the gate**, run before every push (pre-push hook) and in CI; `make lint` runs on every commit.
   Fix what they report; never bypass them (`--no-verify`).
4. A new script or recurring command becomes a target with a `##` help line, not a loose shell file. A long script can
   live in `scripts/`, with a target that calls it.

## The contract

Every repo provides the targets that apply to it, under exactly these names:

| Target | Meaning | Writes files? |
|---|---|---|
| `help` | default goal; lists `##` lines | no |
| `init` | `mise install`, dependency install, `pre-commit install --hook-type pre-commit --hook-type pre-push`. Idempotent | yes |
| `tidy` | format code, tidy modules and lockfiles | yes |
| `lint` | static checks only, quick enough for every commit (seconds): formatters' check mode, linters, file hygiene | no |
| `test` | unit and integration tests | no |
| `audit` | **the gate**: `lint` + `test` + vulnerability and secret scans + "is it tidy" checks (`go mod tidy -diff`, `gofmt -l`, `cargo fmt --check`) | no |
| `build` | build artifacts (`build/dev`, `build/prod` when they differ) | yes |
| `run` | run locally (`run/live` = hot reload) | – |
| `updatedep` | update dependencies to latest, by hand (Renovate does it on its schedule, see AGENTS.md) | yes |
| `upgradeable` | list what could be updated | no |
| `test/e2e` | Playwright specs (web apps) | no |
| `clean` | remove build output | yes |
| `release` | preview the `vX.Y.Z` tag message; with `confirm=yes`, tag `main` and push (CI then publishes) | tag |
| `dist` | the files a `release: page` release attaches, in `dist/` | yes |
| infra: `plan`, `diff` | `terraform plan`, `helm diff`: read-only | no |
| infra: `deploy …` | applies changes. **Requires `confirm=yes`** | yes |

Any other target uses a `group/action` name: `db/reset`, `migrations/new`, `upgrade/go`, `frontend/build`.

Apps with generated media add `assets/build` (generate the manifest's missing entries through `genmedia`) and
`assets/icons` (derive icon sizes from the master). Both write committed files and are never part of `audit` or CI;
the `media-assets` skill has the recipe.

## Style

Start from [templates/Makefile.base](templates/Makefile.base), then add a snippet per stack from `templates/` (`go.mk`,
`python-uv.mk`, `bun.mk`, `rust.mk`, `terraform.mk`, `helm.mk`, `ansible.mk`). Paste the snippets in, rather than using
`include`, so the file stays self-contained and readable.

- `##<target>: <description>` directly above each target. This is what `help` prints; the description must not contain `:`.
- `.PHONY:` for every target that isn't a file.
- `-include .env` for local settings. Commit `.env.example`, never `.env`.
- **Parameters** are `name=value`. Fail clearly when one is missing:

  ```make
  @test -n "$(name)" || { echo "usage: make migrations/new name=<name>"; exit 1; }
  ```

- **Destructive targets** (dropping data, deploying, force-pushing anything) require `confirm=yes` and print what they
  will do first.
- **Portability:** recipes must work with GNU Make **3.81**, which is what macOS ships.
  - No `.ONESHELL`, `::=`, `!=`, `$(file …)` or other 4.x-only features.
  - Each recipe line is its own `sh` shell, so chain with `&&` or `\`.
  - Use POSIX `sh` syntax, not bash.
- **Don't install tools with curl** in `init`. Pin them in `mise.toml` and run `mise install`.
- Keep targets thin and readable. Move logic longer than about 10 lines into `scripts/<name>.sh`.

## Wiring

- **pre-commit** (`.pre-commit-config.yaml`): `make lint` on commit, `make audit` on push, as local hooks. The gate's
  tests (a database, a browser) can take minutes, too long to pay on every commit, docs-only ones included.

  ```yaml
  default_install_hook_types: [pre-commit, pre-push]
  default_stages: [pre-commit]   # the file-check hooks run on commit only, not again on push

  repos:
    - repo: local
      hooks:
        - id: make-lint
          name: make lint
          entry: make lint
          language: system
          stages: [pre-commit]
          pass_filenames: false   # one run per commit, not one per batch of files
          require_serial: true
          always_run: true
        - id: make-audit
          name: make audit
          entry: make audit
          language: system
          stages: [pre-push]
          pass_filenames: false
          require_serial: true
          always_run: true
  ```

  A `lint/hygiene` target that runs the file hooks on every file skips both (`SKIP=make-lint,make-audit,...`), or
  they recurse.

- **CI** (Gitea, GitHub or GitLab): the job runs `mise install` (or the setup actions), then `make audit`, plus
  `make test/e2e` and `make build` where relevant. CI does nothing that isn't a make target.
  - Trigger on `push: branches: [main]` and `pull_request`, not on every push: a PR branch push would run twice.
  - Docs-only changes may skip it (`paths-ignore`: `"*.md"`, `"**/*.md"`, `docs/**`) when no branch protection
    requires the check; the pre-commit `make lint` still covers markdown.
- **The repo's CLAUDE.md** lists the main targets, with one line each, under a "Commands" heading.
- **Git profile:** `gate: make audit` (pre-push and CI; `make lint` on commit). See the git-flow skill.
- **Releases** (profile `tags: vX.Y.Z`): copy [templates/release.sh](templates/release.sh) to `scripts/release.sh`
  and paste [templates/release.mk](templates/release.mk). `make release` only tags; the tag push starts CI, which
  builds the image and creates the release page (git-flow, `references/release-tags.md`). Add `dist` only for
  `release: page` with files to attach.

## Retrofitting a repo

1. Inventory how the repo is driven today: README commands, `scripts/`, `package.json` scripts, CI steps, pre-commit hooks.
2. Map each one to a contract target, or to a `group/action` name. **Keep behaviour identical**, because CI depends on it.
3. Point CI and pre-commit at the targets.
4. Update the README and CLAUDE.md, and verify that `make help` and `make audit` work.
5. Ship it through git-flow as a `chore:` PR.
