# Release and deploy tags

Used only when the repo's Git profile sets `tags:`.

## Naming

| Profile | Tag | Use |
|---|---|---|
| `vX.Y.Z` | `v1.4.0` | Libraries, CLIs and apps: CI publishes an image and/or a release page from the tag |
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

## Tagging a `vX.Y.Z` release: `make release`

Repos with `tags: vX.Y.Z` carry the makefile skill's `release` target (`templates/release.sh`, `release.mk`):

```bash
make release version=1.4.0 summary="Faster DC lookups and no more worker timeouts"            # preview only
make release version=1.4.0 summary="Faster DC lookups and no more worker timeouts" confirm=yes  # tag + push
```

- It refuses unless HEAD is a clean `main` in sync with `origin/main`, the tag is new (locally and on origin), and
  the Git profile sets `tags: vX.Y.Z`.
- The preview is what to show the user before asking for `confirm=yes`. The push starts CI: it may publish and
  deploy.
- **It only makes the tag.** It never builds or uploads anything; CI does (below).

## Message

Tags are always annotated, and for `vX.Y.Z` the message **is the release notes**:

- **First line:** what this release delivers, and why, in one sentence (`summary=`).
- **Then the changes since the previous `v*` tag, grouped** `Features:` (`feat`), `Fixes:` (`fix`) and `Other:`
  (everything else), one `- type: Subject` line each. `docs:` and Renovate's `chore(deps):` are left out.
- The groups match the GoReleaser changelog (`changelog.groups`), so `release: page` and `release: goreleaser` notes
  read the same.

```text
Faster DC lookups and no more worker timeouts

Features:

- feat: Date indexes for the prescription lookup (#46)

Fixes:

- fix: The worker master no longer blocks on the DB wait (#78)
```

`release.sh` writes this from `git log`. If the subjects need cleaning up (fix-ups, noise), it's too late to
rewrite them, so tag by hand with the same format:

```bash
PREV=$(git tag -l '<pattern>' --sort=-v:refname | head -1)
git log --no-merges --format='%s' "$PREV"..<commit> -- <paths of this app>
git tag -a v1.4.0 <commit> -F notes.txt
git show --no-patch v1.4.0     # check before pushing
git push origin v1.4.0         # only when the user asked: this may deploy
```

## What CI does with the tag (profile `release:`)

The release page is **always created in CI**, never by hand, so every release has one and it is reproducible.

| `release:` | On a `vX.Y.Z` tag | Language |
|---|---|---|
| `none` | Nothing beyond the image (profile `image:`), if any | any |
| `page` | `release.yaml` creates the Gitea release: title `vX.Y.Z`, the tag message as notes, and `make dist`'s `dist/*` as assets when the repo has a `dist` target | **any**: only `make dist` changes per stack |
| `goreleaser` | GoReleaser builds the binaries, archives and checksums and creates the release with its grouped changelog | Go (its other-language builders are newer: check them before relying on one) |

- The workflow templates (`image.yaml.example`, `release.yaml.example`) are in project-template, with the runner
  details in their comments. Copy them to `.gitea/workflows/` and set the secrets the header lists.
- The release job needs a repo-write token as a repository secret. Gitea refuses secret names starting with `GITEA_`
  or `GITHUB_`, so name it `RELEASE_TOKEN` and map it in the workflow.

## After the push

Watch every run the tag started (`forges.md`, "CI status": `ci`, `image`, `release`) and report the **result**:

- the image tags pushed;
- the release page URL;
- the bump PR it leads to in the infra repo, if any ([delivery.md](delivery.md)).

A failed run is fixed forward: fix on a branch, merge, tag the next patch version.
