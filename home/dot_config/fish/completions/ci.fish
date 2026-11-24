# Managed by chezmoi. Completions for the ci function (Gitea Actions runs).
complete -c ci -f
complete -c ci -s h -l help -d "Show usage"
complete -c ci -s s -l status -x -a "running queued waiting completed active" -d "Only these statuses (comma-separated)"
complete -c ci -s n -l limit -x -d "How many completed runs"
complete -c ci -l since -x -a "30m 2h 1d 1w" -d "Completed within"
complete -c ci -l failed -d "Only failed or cancelled runs"
complete -c ci -s o -l owner -x -a "(tea api user 2>/dev/null | jq -r '.login // empty'; tea api user/orgs 2>/dev/null | jq -r '.[].username')" -d "Only this owner"
complete -c ci -s r -l repo -x -a "(tea api 'user/repos?limit=50' 2>/dev/null | jq -r '.[].full_name')" -d "Only this repo"
complete -c ci -s w -l watch -d "Redraw every N seconds (-w5)"
