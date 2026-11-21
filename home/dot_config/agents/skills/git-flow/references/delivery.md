# Delivery: from a tag to a running deploy

Used when an app repo publishes an image (profile `image:`) that an infra repo deploys (profile `deploy:`).

## The pipeline, and who runs each step

| Step | Where | Who |
|---|---|---|
| 1. Merge the PRs that make up the release | app repo | agent, **when asked** |
| 2. `make release version=X.Y.Z summary="…" confirm=yes` | app repo | agent, **when asked** (the preview runs unasked) |
| 3. Build and push `:vX.Y.Z` and `:sha-<12>` | app repo CI (`image.yaml`) | CI |
| 4. Create the release page | app repo CI (`release.yaml`, profile `release:`) | CI |
| 5. Open the bump PR for the pinned tag in the chart's `values.yaml` | infra repo | Renovate |
| 6. Review and merge the bump PR | infra repo | agent, **when asked** |
| 7. `make deploy/chart chart=<name> confirm=yes` (or GitOps, once the infra repo has it) | infra repo | agent, **when asked** |

The agent watches steps 3–5 and reports each result (image tags, release URL, bump PR link) without being asked.

## Image tags

- A `vX.Y.Z` tag pushes `:vX.Y.Z` and `:sha-<12>`. A push to `main` pushes `:sha-<12>` only, for trying a build.
- **No `:latest` for a deployed image.** The chart pins a release tag, so "what is running" is answered by the infra
  repo's `values.yaml`, and a rollback is a one-line revert.

## Registry visibility: owner, not repo

Gitea's package visibility follows the **owner** (user or org), not the repository. Everything under a public user
can be pulled anonymously, **even when the repo that built it is private**.

- **Images that carry personal, household or customer data go to a private org.** Code-only images may stay under
  the user.
- Check it, don't assume it: an anonymous token request for the image's tags must get `401`.
- What a private org costs:
  - a package links only to a repo of the same owner, so it won't show on a user-owned repo's page;
  - CI needs `REGISTRY_USER` / `REGISTRY_TOKEN` repository secrets with package write on that org (the per-job token
    doesn't reliably cover packages);
  - the cluster needs an imagePullSecret (sops-encrypted in the infra repo);
  - Renovate needs a docker `hostRules` entry for the registry with package read on that org (in renovate-config's
    runner), or it never sees the new tags and the bump PR never opens.

## The infra repo's Renovate rule

For an image you release yourself, a release is a decision already made, so don't make it wait:

```json
{
  "matchManagers": ["helm-values"],
  "matchPackageNames": ["<registry>/<owner>/<name>"],
  "schedule": ["at any time"],
  "minimumReleaseAge": "0 days",
  "automerge": false
}
```

The chart's `values.yaml` must be in the infra repo's helm-values file list. Never automerge: merging the bump is the
deploy decision.

## Releases that must not deploy yet

A repo's CLAUDE.md may say "tags and releases are fine, no deploys before vN" (rigel-ledger). Then stop after step 4,
and don't open or merge bump PRs in the infra repo.
