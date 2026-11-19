# Task interface for this repo: run `make` (or `make help`) to list targets.
# Tool versions live in mise.toml; this file only runs tasks. GNU Make 3.81 compatible (macOS).
#
# Each stack below defines <stack>/tidy, /lint and /test (a no-op `@:` where a verb doesn't apply).
# The contract targets fan out to every stack listed in STACKS. `make audit` is the gate: pre-commit and CI run it.

-include .env

STACKS := shell fish lua python ansible markdown chezmoi workflows

# The pinned tools from mise.toml come first on PATH, ahead of Mason's or the system's copies.
export PATH := $(shell mise bin-paths 2>/dev/null | tr '\n' ':')$(PATH)

RENDERED    := build/rendered
SHFMT       := shfmt -i 4 -ci -bn
SHELL_FILES  = $(shell scripts/shell-files.sh)
FISH_FILES   = $(shell git ls-files '*.fish')
LUA_FILES    = $(shell git ls-files '*.lua')

.DEFAULT_GOAL := help

##help: List the targets
.PHONY: help
help:
	@echo 'Usage: make <target> [name=value ...]'
	@sed -n 's/^##//p' $(MAKEFILE_LIST) | column -t -s ':' | sed -e 's/^/ /'

##init: Install the pinned tools (mise) and the git hooks
.PHONY: init
init:
	mise install
	@if command -v pre-commit >/dev/null 2>&1; then pre-commit install; else echo "pre-commit not installed: skipping hooks"; fi

##tidy: Format scripts, Lua, Python and Markdown (writes files)
.PHONY: tidy
tidy: $(addsuffix /tidy,$(STACKS))

##lint: Static checks (read-only)
.PHONY: lint
lint: $(addsuffix /lint,$(STACKS)) lint/public lint/hygiene

##test: Build the chezmoi source state for a fresh machine (dry run)
.PHONY: test
test: $(addsuffix /test,$(STACKS))

##audit: The gate run by pre-commit and CI - lint + test + secret scan of the whole history
.PHONY: audit
audit: lint test
	gitleaks git --no-banner --redact .

##updatedep: Bump the tool pins in mise.toml and the pre-commit hook revisions now (Renovate does it monthly)
.PHONY: updatedep
updatedep:
	mise upgrade --bump
	pre-commit autoupdate

# Renovate can't see these: lazy.nvim pins plugins in lazy-lock.json, Mason pins nothing. Run it when the monthly
# Renovate PR arrives, on the machine you edit from, and commit lazy-lock.json with it.
##nvim/update: Update nvim plugins (lazy-lock.json, copied back to the source) and Mason packages on this machine
.PHONY: nvim/update
nvim/update:
	nvim --headless '+Lazy! sync' +qa
	nvim --headless -c 'lua require("cwchen.util.mason_sync").run({ upgrade = true })'
	chezmoi re-add $(HOME)/.config/nvim/lazy-lock.json

##upgradeable: List tools with newer versions than the pins
.PHONY: upgradeable
upgradeable:
	mise outdated --bump

##clean: Remove build output and tool caches
.PHONY: clean
clean:
	rm -rf ./build ./ansible/.ansible

##apply/dry: Show what chezmoi apply would change on this machine (read-only)
.PHONY: apply/dry
apply/dry:
	chezmoi apply --dry-run --verbose

##lint/public: No internal IPs or work domains in tracked files (public repo)
.PHONY: lint/public
lint/public:
	scripts/check-public.sh

##lint/hygiene: pre-commit-hooks file checks on every file (whitespace, EOF, YAML/JSON/TOML, keys)
.PHONY: lint/hygiene
lint/hygiene:
	SKIP=make-audit,no-commit-to-branch,gitleaks pre-commit run --all-files --show-diff-on-failure

# ---- shell: plain scripts are formatted and checked; rendered templates are checked only ----
.PHONY: shell/tidy shell/lint shell/test
shell/tidy:
	$(SHFMT) -w $(SHELL_FILES)
shell/lint: chezmoi/render
	shellcheck $(SHELL_FILES)
	$(SHFMT) -d $(SHELL_FILES)
	shellcheck $$(scripts/shell-files.sh $(RENDERED))
shell/test:
	@:

# ---- fish: fish_indent on plain files; syntax check on those and the rendered templates ----
# fish 4 is one binary that acts as fish_indent when called by that name; mise's package ships only `fish`,
# so the pinned one is linked here (a system fish_indent may be a different version, or missing as in CI).
FISH_INDENT := build/bin/fish_indent
$(FISH_INDENT):
	mkdir -p $(@D) && ln -sf "$$(command -v fish)" $@
.PHONY: fish/tidy fish/lint fish/test
fish/tidy: $(FISH_INDENT)
	$(FISH_INDENT) -w $(FISH_FILES)
fish/lint: chezmoi/render $(FISH_INDENT)
	$(FISH_INDENT) --check $(FISH_FILES)
	@for f in $(FISH_FILES) $$(find $(RENDERED) -name '*.fish'); do fish --no-execute "$$f" || exit 1; done
fish/test:
	@:

# ---- lua: nvim config and conky widgets (stylua.toml) ----
.PHONY: lua/tidy lua/lint lua/test
lua/tidy:
	stylua $(LUA_FILES)
lua/lint:
	stylua --check $(LUA_FILES)
lua/test:
	@:

# ---- python: helper scripts shipped by ansible roles (ruff.toml) ----
.PHONY: python/tidy python/lint python/test
python/tidy:
	ruff check --fix ansible
	ruff format ansible
python/lint:
	ruff check ansible
	ruff format --check ansible
python/test:
	@:

# ---- ansible: ansible-lint (profile and skips in ansible/.ansible-lint) includes the syntax check ----
# --project-dir . makes it install ansible/requirements.yml into ansible/.ansible on the first run.
.PHONY: ansible/tidy ansible/lint ansible/test
ansible/tidy:
	@:
ansible/lint:
	cd ansible && ansible-lint --project-dir .
ansible/test:
	@:

# ---- markdown: markdownlint-cli2 (.markdownlint-cli2.yaml) ----
.PHONY: markdown/tidy markdown/lint markdown/test
markdown/tidy:
	markdownlint-cli2 --fix
markdown/lint:
	markdownlint-cli2
markdown/test:
	@:

# ---- chezmoi: render templates with the fixture config (ci/chezmoi.toml), dry-run a fresh apply ----
.PHONY: chezmoi/tidy chezmoi/lint chezmoi/test chezmoi/render
chezmoi/tidy chezmoi/lint:
	@:
chezmoi/render:
	scripts/chezmoi-render.sh
chezmoi/test:
	scripts/chezmoi-test.sh

# ---- workflows: Gitea Actions ----
.PHONY: workflows/tidy workflows/lint workflows/test
workflows/tidy workflows/test:
	@:
workflows/lint:
	actionlint .gitea/workflows/*.yaml
