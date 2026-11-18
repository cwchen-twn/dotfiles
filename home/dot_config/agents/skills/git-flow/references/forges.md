# Forge commands

Same flow, three CLIs. `<n>` is the issue or PR number. Bodies are files written first (`issue.md`, `pr.md`), so quoting never breaks.

| Step | Gitea (`tea`) | GitLab (`glab`) | GitHub (`gh`) |
|---|---|---|---|
| Find issue | `tea issues ls --keyword "<words>" --state all` | `glab issue list --search "<words>" --all` | `gh issue list --search "<words>" --state all` |
| Create issue | `tea issues create -t "<title>" --description-file issue.md -a <me>` | `glab issue create --assignee @me -t "<title>" -d "$(cat issue.md)"` | `gh issue create --assignee @me -t "<title>" -F issue.md` |
| Draft PR/MR | `tea pulls create --draft --head <branch> -b main -t "<type>: <Subject>" --description-file pr.md` | `glab mr create --draft --source-branch <branch> --target-branch main --assignee @me --remove-source-branch -t "<type>: <Subject>" -d "$(cat pr.md)"` | `gh pr create --draft --base main -t "<type>: <Subject>" -F pr.md` |
| Mark ready | `tea pulls edit <n> -t "<title without WIP:>"` | `glab mr update <n> --ready` | `gh pr ready <n>` |
| Update body | `tea pulls edit <n> --description-file pr.md` | `glab mr update <n> -d "$(cat pr.md)"` | `gh pr edit <n> -F pr.md` |
| CI status | `tea actions runs ls` · `tea actions runs logs <id>` | `glab ci list` · `glab ci trace <job-id>` | `gh pr checks <n> --watch` · `gh run view <id> --log-failed` |
| **FF merge** | `tea api -X POST "repos/{owner}/{repo}/pulls/<n>/merge" -d '{"Do":"fast-forward-only","delete_branch_after_merge":true}'` | `glab mr merge <n>` (project `merge_method: ff`) | `gh pr merge <n> --rebase --delete-branch` |
| Clean up | `tea pulls clean <n>` | `--remove-source-branch` above | `--delete-branch` above |
| Open in browser | `tea open pulls <n>` | `glab mr view <n> --web` | `gh pr view <n> --web` |

## Notes

- **Gitea drafts** are PRs whose title starts with `WIP:`. `--draft` adds the prefix, and marking the PR ready means editing the title to remove it.
- **Gitea merge style.** `tea pulls merge` supports only `merge|rebase|squash|rebase-merge`, and **defaults to `merge` (a merge commit) whatever the repo's default is**. Use the API call above for fast-forward-only.
  - `--style rebase` is the fallback. On a branch that is already rebased it yields the same linear history, but Gitea rewrites the committer.
  - If the API answers 405 or 409, `main` has moved. Rebase, push with `--force-with-lease`, wait for CI, and retry.
- **GitLab** fast-forwards only when the project's `merge_method` is `ff`. If `glab mr merge` refuses, rebase first, as above.
- **GitHub** `--rebase` replays the commits onto `main`. With a branch already rebased, the result is the fast-forward equivalent.
- **Push mirrors.** If a repo's GitHub copy is a push mirror of Gitea, all issue, PR and merge work happens on Gitea; the mirror follows by itself.
- **Closing keywords** (`Closes #N`, `Fixes #N`) work on all three forges when they appear in the PR body or in a commit that reaches the default branch.
