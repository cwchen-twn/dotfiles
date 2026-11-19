# Release and deploy tags

Used only when the repo's Git profile sets `tags:`.

## Naming

| Profile | Tag | Use |
|---|---|---|
| `vX.Y.Z` | `v1.4.0` | Libraries, CLIs and apps released through GoReleaser, CI images or similar |
| `<env>.<app>.<X.Y.Z>` | `production.api.1.0.19` | Monorepos where a tag deploys one app to one environment. The repo lists its apps, envs and paths |

- Bump the patch for fixes, the minor for features, and the major for breaking changes or migrations.
- If CI checks the tag against a version file (`Chart.yaml` `version:`, `package.json`, `Cargo.toml`), bump that file
  **in the PR**, before tagging.
- With env tags, deploy to `testing.` first, then tag the same version for `production.` once it is verified.

## Where

- Release and production tags go only on commits that are on `main`.
- A `testing.` tag may sit on a PR-branch commit. Once the branch is rebased, that commit no longer reaches `main`;
  leave the tag where it is.
- **Never move, delete or re-push a tag.** Re-pushing can re-trigger a deploy. Fix forward with the next version.

## Message

Tags are always annotated. Write the message this way:

- **First line:** what this release delivers, and why, in one sentence.
- **Then a numbered list:** one line per change in `type: Subject` form, with issue or PR references.

```bash
PREV=$(git tag -l '<pattern>' --sort=-v:refname | head -1)
git log --no-merges --format='%s' "$PREV"..<commit> -- <paths of this app>
```

Rewrite that output into the message: drop fix-ups and noise.

```bash
git tag -a v1.4.0 <commit> -F - <<'EOF'
Faster DC lookups and no more worker timeouts

1. fix: Corrected the blocking DB wait in the worker master (#78)
2. perf: Added the date indexes for the prescription lookup (#46)
EOF
git show --no-patch v1.4.0     # check before pushing
git push origin v1.4.0         # only when the user asked: this may deploy
```

Then watch the pipeline (see `forges.md`, "CI status") and report the result.
