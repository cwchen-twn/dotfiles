# Commit styles

Choose with `commit-style:` in the repo's Git profile. A repo skill, such as hcloud's `.claude/skills/commit-style`, overrides both styles.

## Common to both

- `<type>: <Subject>`, with **no scope**. `chore(deps):` is Renovate's only.
- No trailing period. Exactly one type.

| Type | Use for |
|---|---|
| `feat` | New capability: an API, report, chart, job, script, deploy target |
| `fix` | Wrong behaviour, a failure, a misconfiguration, a claim corrected |
| `perf` | Performance work without behaviour change |
| `refactor` | Restructuring without behaviour change |
| `chore` | Maintenance: dependencies, tooling, CI, docs, skills |
| `docs` | Documentation-only commits, in repos that use it (hcloud does) |

Don't use made-up types (`add`, `update`, `bug`, `wip`) or component prefixes (`Monitoring:`).

- **The body is required** for anything beyond a one-line, self-explanatory change.
- **Never invent a measurement.** Every number has to be one you actually took.

## `reasoned-list` (default)

```
<type>: <Past-tense subject that names the intention>

<Why: 1-3 sentences on the problem, symptom or requirement. Quote the
observed error when there is one.>

1. <Change>, <reason when it is not obvious>
2. <Change> so that <intended effect>

Closes #<issue>            (or Refs #<issue> for intermediate commits)
Co-Authored-By: ...
```

- **Subject:** past tense, sentence case, starts with a verb: Added, Fixed, Corrected, Moved, Removed, Replaced, Updated, Split, Renamed. Keep it to about 100 characters.
  - Name the intention when it fits, e.g. "…so the testing cluster receives renewals".
  - Bad: "Updated values.yaml" lists what was touched, not why.
- **Body:** start with the reason. Then give a numbered list with one line per change: *what* changed and, when it isn't obvious, *why* ("because…", "so that…", "(was …)").

Example:

```
fix: Corrected the dashboard's database settings so its password is never logged

The app logs every env override at startup and masks only names like
*_PASSWORD, so DATABASE_URL printed the password in clear text; a "/" in
the password also broke URL parsing ("invalid port after host").

1. Replaced DATABASE_URL with DATABASE_HOST and DATABASE_PASSWORD from the secret
2. Made the chart fail with a clear message when the old key is still set
3. Bumped the chart to 0.1.7

Refs #47
```

## `finding-prose`

The subject **states the finding**, not the edit. It is often long (50–85 characters), with a comma clause for the why.

The body is prose paragraphs, in roughly this order:
1. what was wrong and the mechanism;
2. **the measurement** (numbers, exact errors, before/after counts);
3. what was believed and turned out false, often in CAPS;
4. what was considered and rejected;
5. what the operator must now do differently.

Use ASCII `--` and `->` in the body.

Good subjects:

```
fix: Cloudflare was challenging Renovate's API, so no PR was ever opened
feat: push the tailnet policy from git, because the console is not a source
```

Too thin: `fix: Fix Renovate endpoint`.
