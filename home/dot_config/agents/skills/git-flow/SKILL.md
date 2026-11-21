---
name: git-flow
description: Git workflow for every repository, on any forge (Gitea via tea, GitLab via glab, GitHub via gh). It covers the issue → branch → draft PR/MR → fast-forward merge flow that must exist before development starts, commit messages, annotated release/deploy tags, and what a tag sets off (CI release pages, images, the Renovate hand-off to an infra repo), with per-repo overrides from a "Git profile" block. Use before starting any code or config change; when creating an issue, branch, PR or MR; when committing or writing a commit message; and when merging, tagging, releasing or publishing an image. A repo-specific git or commit skill, if present, takes precedence for whatever it covers.
---

# Git flow

**Order of precedence:**

1. the repo's own git or commit skill (e.g. `.claude/skills/commit-style`), for what it covers;
2. the repo's **Git profile** (below);
3. these defaults.

**Ask first:** commit, push, open a PR or MR, merge, and push tags only when the user asks. A pushed tag may **deploy**.

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
commit-style: reasoned-list      # reasoned-list | finding-prose | <path to repo skill>
tags: none                       # none | vX.Y.Z | <env>.<app>.<X.Y.Z>
release: none                    # none | page | goreleaser: what CI makes of a vX.Y.Z tag (§4)
image: none                      # or <registry>/<owner>/<name>, pushed by CI on tags and main
gate: make audit                 # the check run before commit and in CI
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

2. **Branch.** Create it from an up-to-date default branch and name it `<issue>-<short-slug>`:

   ```bash
   git switch main && git pull --ff-only && git switch -c 48-git-flow
   ```

3. **Draft PR/MR.** Open it once the first commit is pushed, and keep it a draft until it is ready.
   - **Title:** the conventional subject of the main change, in commit-subject format (§2).
   - **Body:** use [templates/pr.md](templates/pr.md):
     - `Closes #<issue>`;
     - `## What`, with why each change is needed;
     - `## Testing done`, which names the make targets or commands actually run and what is not verified yet;
     - `## Before merge / deploy`, for manual steps;
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
- **Run the gate** (profile `gate:`, default `make audit`) before committing.
  - A pre-commit hook usually runs it.
  - Fix any failure. **Never use `--no-verify`.**
  - If the gate needs mise's `[env]` (sops-decrypted credentials, say for `terraform init`) and the shell isn't
    mise-activated (an agent's bash), commit with `mise exec -- git commit …`.
- Each commit must stand on its own: with fast-forward merges, `main` gets the branch's commits as they are.
- End with the Co-Authored-By line the session asks for.

## 3. Merge

- **`fast-forward-only` (default):** no merge commit, no squash.
  - If `main` has moved, rebase first:

    ```bash
    git fetch && git rebase origin/main
    git push --force-with-lease
    ```

    Then let CI pass again.
  - Merge through the forge with the fast-forward method. The tea, glab and gh forms are in `forges.md`.
    **`tea pulls merge`'s default style creates a merge commit**, so don't use it bare.
- After the merge, delete the branch. Then `git switch main && git pull --ff-only`, and archive any OpenSpec change:
  `openspec archive <change>`.

**Stacked PRs** (work that splits into dependent changes):

- Branch each one from the previous branch's tip, not from `main`. Every PR still targets `main`; its body says
  `Stacked on #<n>, merge after it`.
- Merge in order. Each branch already sits on the previous one, so each fast-forwards with no rebase.

**When force-push isn't allowed** (a permission check refuses it, branch protection, or the user said no):

- Never rewrite pushed history to fix a branch. Add a follow-up commit; it must still stand on its own.
- If `main` moved and the fast-forward fails, ask the user to run the `--force-with-lease` push, or merge with
  Gitea's `--style rebase` fallback (`forges.md`), which rebases on the server.

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
| issue, branch, local commits, `make release` preview, watching CI, reporting | push, open or merge a PR, `make release … confirm=yes`, merge an infra bump PR, deploy |
