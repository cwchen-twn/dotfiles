---
name: git-flow
description: Git workflow for every repository, on any forge (Gitea via tea, GitLab via glab, GitHub via gh). It covers the issue → branch → draft PR/MR → fast-forward merge flow that must exist before development starts, commit messages, annotated release/deploy tags, and what a tag sets off (CI release pages, images, the Renovate hand-off to an infra repo), with per-repo overrides from a "Git profile" block. Use before starting any code or config change; when creating an issue, branch, PR or MR; when committing or writing a commit message; and when merging, tagging, releasing or publishing an image. A repo-specific git or commit skill, if present, takes precedence for whatever it covers.
---

# Git flow

**Order of precedence:**

1. the repo's own git or commit skill (e.g. `.claude/skills/commit-style`), for what it covers;
2. the repo's **Git profile** (below);
3. these defaults.

**Ready to push.** Commit, push the issue branch and open its **draft** PR/MR without asking, once all of these hold:

1. `make lint` passed on every commit (pre-commit hook), and the gate passes on the push (pre-push hook).
2. The reviews the change needs found no blockers: `/code-review` on the diff; `infra-reviewer` for infra or CI;
   `/security-review` when auth, input handling, secrets or crypto changed. Every finding is fixed, or listed in the
   PR body.
3. The branch is the issue's branch, never the default one, and the push names it: `git push -u origin <branch>`,
   not `HEAD` or `@` (those prompt). It is a plain push (no `--force*`), and nothing stray or secret is committed.
4. The push is **its own Bash call**, with nothing chained before or after it. Commit, push and open the PR as
   separate calls. The permission rules match the whole command string, so a trailing `; git switch main`, or a
   `+`, `HEAD` or `-d` in a commit message or JSON body, makes a branch push prompt as a push to `main`.

Then report the PR link. If any condition fails, stop and report instead of pushing.

**Agent-merged PRs.** Merge without asking when all of these hold:

- The PR is in one of these classes, and the profile's `auto-merge:` doesn't leave its class out:
  - `docs`: the diff touches only Markdown, `docs/` or comments. No code, config or CI.
  - `deps-minor`: a Renovate PR (`renovate/*`) whose updates are all patch or minor. Never a major.
  - `planned`: the plan the user approved said **Merge: agent**, and the PR body carries the line
    `Merge: agent (agreed in plan)` from the moment the PR is opened. **Every plan that ends in a PR carries a
    `Merge:` line**, whatever the task, with its reason in parentheses. `agent` is the default, and `ask` is only
    for the cases AGENTS.md lists (CI or deploys, infra, secrets, auth, the agents' own rules, permissions or hooks,
    unrecoverable deletes, or the user should see it working first). Decide it while planning: approving the plan
    is the user's confirmation, and a missing line means ask. A PreToolUse hook on ExitPlanMode
    (`~/.claude/hooks/plan-merge-line.sh`) denies a plan without the line or without a reason. Merge in a Bash
    call of its own, separate from marking the PR ready.
    **Say the decision in chat as well:** the message that presents the plan (and a revised plan after a rejection)
    names it, e.g. "Merge: agent, I merge after CI" or "Merge: ask, you merge". The user approves the chat as much
    as the plan file. The PR report repeats it.
- CI passed on the PR's head commit, and the "Ready to push" reviews left nothing open.

**Watch CI.** Right after opening an agent-merged PR, start a background wait on its head commit's CI
(`run_in_background`, the "Wait for CI" row in forges.md). It is a bounded loop that prints the final state and
never chains the merge, and the harness notifies the session when it exits. Then:

- **success:** in separate Bash calls, check the PR body has its marker (`planned`), mark it ready (Gitea: drop
  `WIP:`), merge it as in §3, clean up, and report the merged commit.
- **failure or timeout:** report the failing job and stop. Don't retry the merge.
- **Not watching** (the session ends, or the user said to wait): say so in the report ("not watching CI; say
  `merge #N` when it's green"). Never write "I'll merge once CI passes" without a wait running.

Gitea reads a `WIP:` draft as `mergeable: false`: mark it ready, re-check `mergeable`, and if it is still false check
whether `main` moved (§3).

**Ask first:** force-push (even `--force-with-lease`), any push to `main`, merging any other PR, tags,
`make release … confirm=yes` and deploys. A pushed tag may **deploy**.

## 0. Detect the forge and the profile

```bash
git remote get-url origin
```

| Remote host | Forge | CLI |
|---|---|---|
| your Gitea host (e.g. `git.<domain>`) | Gitea | `tea` |
| `gitlab.com` or a GitLab host | GitLab | `glab` |
| `github.com` | GitHub | `gh` |

When in doubt, `glab repo view` / `tea repos ls` / `gh repo view` tells which login works. A GitHub repo that is only a
**push mirror** of Gitea is never worked on directly: use the Gitea origin.

Commands per forge are in [references/forges.md](references/forges.md). Read it before the first forge command in a session.

**Git profile.** Look for a `## Git profile` block in the repo's `CLAUDE.md` or `AGENTS.md`. Every key is optional, and
missing keys take the default shown:

```text
## Git profile
issue-first: yes                 # yes | no (then branches are <type>/<slug>)
branch: <issue>-<slug>           # or <type>/<slug>
merge: fast-forward-only         # fast-forward-only | merge | squash
auto-merge: docs,deps-minor,planned  # the agent-merged classes (top of this skill), or none
commit-style: reasoned-list      # reasoned-list | finding-prose | <path to repo skill>
tags: none                       # none | vX.Y.Z | <env>.<app>.<X.Y.Z>
release: none                    # none | page | goreleaser: what CI makes of a vX.Y.Z tag (§4)
image: none                      # or <registry>/<owner>/<name>, pushed by CI on tags and main
gate: make audit                 # the check run before push and in CI (make lint runs on commit)
deploy: <how a change reaches production, e.g. "infra repo chart, via a Renovate PR">
rust-analyzer: mason             # or rustup, for pinned/nightly toolchains
```

## 1. Before any development: issue → branch → draft PR

Every change goes through an issue and a PR or MR. That includes config, CI, docs and skills.

- Never commit to the default branch.
- Never start on an unrelated branch.

1. **Issue.** Search first; create one only if none exists. Use [templates/issue.md](templates/issue.md) and leave out
   any section that would be empty:

   | Section | Content |
   |---|---|
   | `## Description` | The problem or need, and why it matters now |
   | `## Plan` | The intended approach |
   | `## Details` | Specifics, affected files and environments |
   | `## Challenge` | Risks, manual steps, open questions |
   | `## Reference` | Related issues, PRs/MRs, docs, links |

   Then put the issue on its owner's board when AGENTS.md names one (forges.md, "Add to board"): the forge doesn't
   do it by itself. Only the issue goes on the board. Its PR is linked by `Closes #N`, and Renovate PRs stay off
   boards (§3).

2. **Branch.** Create it from an up-to-date default branch and name it `<issue>-<short-slug>`:

   ```bash
   git switch main && git pull --ff-only && git switch -c 48-git-flow
   ```

3. **Draft PR/MR.** Push and open it as soon as the work is "ready to push" (top of this skill), and keep it a draft
   until the user marks it ready, or until it is an agent-merged PR whose CI passed.
   - **Title:** the conventional subject of the main change, in commit-subject format (§2).
   - **Body:** use [templates/pr.md](templates/pr.md):
     - `Closes #<issue>`;
     - `## What`, with why each change is needed;
     - `## Testing done`, which names the make targets or commands actually run and what is not verified yet;
     - `## Before merge / deploy`, for manual steps;
     - `Merge: agent (agreed in plan)`, only for a `planned` agent-merged PR;
     - the attribution line the session asks for.
   - When the work changes direction, update the body. It must describe what gets merged, not the first draft.

## 2. Commits

Pick the style from the profile. Both styles are described in [references/commit-styles.md](references/commit-styles.md).

- **`reasoned-list` (default):**
  - a past-tense, sentence-case subject that names the intention;
  - a 1–3 sentence reason, then a numbered change list;
  - `Closes #N` or `Refs #N`.
- **`finding-prose`:** the subject states the finding, and the body is prose with measurements. hcloud uses this.

Rules for every style:

- Conventional type: `feat` `fix` `perf` `refactor` `chore` (and `docs`, where the repo uses it).
- **No scope.** `chore(deps):` is Renovate's only.
- No trailing period. Exactly one type.
- **Run `make lint` before committing, and the gate** (profile `gate:`, default `make audit`) **before pushing.**
  - The pre-commit and pre-push hooks usually run them (makefile skill, "Wiring").
  - Fix any failure. **Never use `--no-verify`.**
  - If the hooks need mise's `[env]` (sops-decrypted credentials, say for `terraform init`) and the shell isn't
    mise-activated (an agent's bash), run them under it: `mise exec -- git commit …` and, now that the gate runs on
    push, `mise exec -- git push …`.
  - The pre-push gate can take minutes (database tests). Give the push a long timeout rather than reading a slow
    hook as a hang.
- Each commit must stand on its own: with fast-forward merges, `main` gets the branch's commits as they are.
- End with the Co-Authored-By line the session asks for.

## 3. Merge

- **`fast-forward-only` (default):** no merge commit, no squash. Merge through the forge, never by pushing `main`
  (the forms are in `forges.md`; **`tea pulls merge`'s default style creates a merge commit**, so don't use it bare).
  1. **Fast-forward.** On Gitea, the merge API with `"Do":"fast-forward-only"`.
  2. **`main` moved** (Gitea answers 405 or 409): **don't rebase locally and don't force-push.** Merge with
     `"Do":"rebase"`: Gitea rebases the branch onto `main` on the server and fast-forwards. History stays linear;
     only the committer is rewritten.
  3. **The server rebase conflicts:** stop and report. Never resolve it with a force-push.

  GitLab and GitHub have no server-side fallback here: a local `git rebase origin/main` and
  `git push --force-with-lease` of the branch run only when the user asks.
- After the merge: `git switch main && git pull --ff-only`, then `git branch -D <branch>` (`-D`: a server rebase
  rewrote its commits, so `-d` refuses). Archive any OpenSpec change: `openspec archive <change>`.

**Stacked PRs** (work that splits into dependent changes):

- Branch each one from the previous branch's tip, not from `main`. Every PR still targets `main`; its body says
  `Stacked on #<n>, merge after it`.
- Merge in order. Each fast-forwards when the previous one did; if the previous one took the server rebase, the next
  one takes it too.

**Never rewrite pushed history to fix a branch.** Add a follow-up commit; it must still stand on its own.

**Renovate PRs/MRs** (`renovate/*` branches, opened by the bot):

- No issue needed; the Dependency Dashboard tracks them.
- Review, merge, and deploy the way the repo deploys.
- Don't push to a Renovate branch unless you need to: Renovate stops rebasing a branch once a human commits to it.

## 4. Release and deliver (profile `tags:` ≠ `none`)

See [references/release-tags.md](references/release-tags.md) for tagging and release pages, and
[references/delivery.md](references/delivery.md) for images and the hand-off to an infra repo. The non-negotiables:

- Tag with `make release version=X.Y.Z summary="…"` where the repo has it (makefile skill). It previews the message;
  `confirm=yes` tags and pushes. It only makes the tag: **CI publishes**, the image (profile `image:`) and the
  release page (profile `release:`).
- Tags are always annotated (`git tag -a`), and the message lists the changes since the previous tag of the same series.
- Production or release tags go only on commits that are on `main`, and whose CI run passed.
- **Never move, delete or re-push an existing tag.** Fix forward with the next version.
- After pushing, watch every run the tag started and report the **result**: image tags, release page URL, the bump
  PR in the infra repo. Not just that the tag was pushed.

What the agent does unasked, and what waits for the user:

| Unasked | Only when asked |
|---|---|
| issue, branch, commits, push the issue branch and open its draft PR once ready to push, merge an agent-merged PR (docs, Renovate patch/minor, `planned`) once CI passed, `make release` preview, watching CI, reporting | force-push, push to `main`, mark any other PR ready or merge it, `make release … confirm=yes`, merge an infra bump PR, deploy |
