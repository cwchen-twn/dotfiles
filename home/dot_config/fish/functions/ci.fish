# Managed by chezmoi. Gitea Actions runs across your user and every org you belong to (tea's default login).
function ci --description "List Gitea Actions runs (running, queued, waiting, completed) or show one run's jobs"
    argparse h/help 's/status=' 'n/limit=' 'since=' failed 'o/owner=' 'r/repo=' 'w/watch=?' -- $argv
    or return 2

    if set -q _flag_help
        echo "ci [-s STATUS,...] [-n N] [--since 30m|2h|1d|1w] [--failed] [-o OWNER | -r OWNER/REPO] [-w[SECS]]"
        echo "ci OWNER/REPO RUN_ID | ci RUN_URL     one run: its jobs and steps"
        echo
        echo "STATUS: running, queued, waiting, completed, active (= running,queued,waiting)."
        echo "Default: active runs plus the last 5 completed. -n/--since/--failed limit completed runs."
        echo "-w redraws every SECS seconds (default 10) until Ctrl-C."
        return 0
    end
    for tool in tea jq column
        command -q $tool; or begin
            echo "ci: $tool not found" >&2
            return 1
        end
    end

    # One run: `ci owner/repo 123` or its URL.
    if test (count $argv) -ge 1
        set -l repo
        set -l id
        if set -l m (string match -rg '/([^/]+/[^/]+)/actions/runs/(\d+)' -- $argv[1])
            set repo $m[1]
            set id $m[2]
        else if test (count $argv) -eq 2; and string match -qr '^\d+$' -- $argv[2]
            set repo $argv[1]
            set id $argv[2]
        else
            echo "ci: expected OWNER/REPO RUN_ID or a run URL" >&2
            return 2
        end
        __ci_run $repo $id
        return
    end

    set -l statuses running queued waiting completed
    set -l limit 5
    if set -q _flag_status
        set statuses
        for s in (string split , -- $_flag_status)
            test "$s" = active; and set -a statuses running queued waiting; or set -a statuses $s
        end
        for s in $statuses
            contains -- $s running queued waiting completed; or begin
                echo "ci: unknown status '$s' (running, queued, waiting, completed, active)" >&2
                return 2
            end
        end
    end
    set -l since 0
    if set -q _flag_since
        set -l m (string match -rg '^(\d+)([smhdw])$' -- $_flag_since)
        or begin
            echo "ci: --since takes 30m, 2h, 1d, 1w" >&2
            return 2
        end
        set -l unit (contains -i -- $m[2] s m h d w)
        set -l secs 1 60 3600 86400 604800
        set since (math "$m[1] * $secs[$unit]")
        set limit 50
    end
    set -q _flag_failed; and set limit 50
    if set -q _flag_limit
        string match -qr '^\d+$' -- $_flag_limit; or begin
            echo "ci: -n takes a number" >&2
            return 2
        end
        set limit $_flag_limit
    end
    # --since/--failed/-n only make sense for completed runs: imply it when no -s was given.
    if not set -q _flag_status; and begin
            set -q _flag_since; or set -q _flag_failed; or set -q _flag_limit
        end
        set statuses completed
    end

    set -l scopes
    if set -q _flag_repo
        set scopes repos/$_flag_repo
    else
        set -l me (tea api user 2>/dev/null | jq -r '.login // empty')
        test -n "$me"; or begin
            echo "ci: no Gitea login (tea login add)" >&2
            return 1
        end
        if set -q _flag_owner
            test "$_flag_owner" = "$me"; and set scopes user; or set scopes orgs/$_flag_owner
        else
            set scopes user (tea api user/orgs 2>/dev/null | jq -r '.[].username' | string replace -r '^' 'orgs/')
        end
    end

    # `--` can't be a separator here: `set` takes it as the end of its own options.
    set -l color (isatty stdout; and echo 1; or echo 0)
    set -l args $statuses :: $limit $since (set -q _flag_failed; and echo 1; or echo 0) :: $scopes
    if set -q _flag_watch
        set -l every (test -n "$_flag_watch"; and echo $_flag_watch; or echo 10)
        string match -qr '^\d+$' -- $every; or begin
            echo "ci: -w takes seconds, e.g. -w5" >&2
            return 2
        end
        while true
            # Rendered before clearing, so the screen never sits blank while tea is asked.
            set -l out (__ci_list $color $args 2>&1)
            clear
            printf '%s\n' $out
            echo
            set_color brblack
            echo "every $every"s", Ctrl-C to stop · "(date +%T)
            set_color normal
            sleep $every; or break
        end
    else
        __ci_list $color $args
    end
end

# __ci_list COLOR STATUS... :: LIMIT SINCE FAILED :: SCOPE...
function __ci_list
    set -l color $argv[1]
    set -e argv[1]
    set -l sep (contains -i :: $argv)
    set -l statuses $argv[1..(math $sep - 1)]
    set -l rest $argv[(math $sep + 1)..-1]
    set -l limit $rest[1]
    set -l since $rest[2]
    set -l failed $rest[3]
    set -l scopes $rest[5..-1]

    # Runs per scope and status; jobs (which carry created_at and runner_name, runs don't) for the active ones.
    set -l tmp (mktemp -d)
    touch $tmp/runs $tmp/jobs
    for scope in $scopes
        for s in $statuses
            set -l api (string replace running in_progress -- $s)
            set -l n 50
            test $s = completed; and set n (math "max($limit, 1)")
            # Only the fields used below: a full run object carries its whole repository.
            tea api "$scope/actions/runs?status=$api&limit=$n" 2>/dev/null \
                | jq -c --arg s $s '[.workflow_runs[]? | {id, path, event, conclusion, started_at, completed_at,
                    repository: {full_name: .repository.full_name}, q: $s}]' >>$tmp/runs
            test $s = completed; or tea api "$scope/actions/jobs?status=$api&limit=50" 2>/dev/null \
                | jq -c '[.jobs[]? | {run_id, created_at, started_at, runner_name}]' >>$tmp/jobs
        end
    end
    tea api admin/actions/runners 2>/dev/null | jq -c '[.runners[]? | {name, status, busy, labels}]' >$tmp/runners 2>/dev/null
    or echo '[]' >$tmp/runners

    # Shared by both passes: the rows, split into $active and $done (the completed runs shown).
    set -l rows '
      def ts: if . == null then null else
          (sub("[.][0-9]+"; "")
           | if test("Z$") then fromdateiso8601
             else (capture("^(?<d>.*)(?<s>[+-])(?<h>[0-9]{2}):(?<m>[0-9]{2})$") as $c
                   | ($c.d + "Z" | fromdateiso8601)
                     - (($c.s + "1" | tonumber) * (($c.h | tonumber) * 3600 + ($c.m | tonumber) * 60)))
             end)
          | if . <= 0 then null else . end end;
      def hms: if . == null or . < 0 then "-"
          elif . < 60 then "\(floor)s"
          elif . < 3600 then "\(./60|floor)m\(floor % 60)s"
          elif . < 86400 then "\(./3600|floor)h\((./60|floor) % 60)m"
          else "\(./86400|floor)d\((./3600|floor) % 24)h" end;
      ($rs | add // []) as $runs | ($js | add // []) as $jobs | ($rn[0] // []) as $runners
      | now as $now
      | ($jobs | group_by(.run_id) | map({key: (.[0].run_id|tostring),
            value: {created: (map(.created_at|ts) | map(select(.)) | min),
                    started: (map(.started_at|ts) | map(select(.)) | min),
                    runner: (map(.runner_name // empty | select(. != "")) | unique | join(","))}})
         | from_entries) as $jm
      | [$runs[] | . as $r | ($jm[$r.id|tostring] // {}) as $j
         | ($r.path // "" | capture("^(?<wf>[^@]*)@refs/(?:heads/|tags/|pull/)?(?<ref>.*)$") // {wf: ($r.path // "?"), ref: ""}) as $p
         | {q: $r.q, id: $r.id, repo: ($r.repository.full_name // "?"), wf: $p.wf,
            ref: ($p.ref | sub("/head$"; "") | if $r.event == "pull_request" then "#" + . else . end),
            event: ($r.event // "?" | sub("pull_request"; "pr") | sub("workflow_dispatch"; "dispatch")),
            status: (if $r.q == "completed" then ($r.conclusion // "completed") else $r.q end),
            created: $j.created, started: ($r.started_at|ts // $j.started), done: ($r.completed_at|ts),
            runner: ($j.runner // "" | gsub("-gitea-runner(?=,|$)"; "") | if . == "" then "-" else . end)}]
      | (map(select(.q != "completed")) | sort_by(.created // 0)) as $active
      | (map(select(.q == "completed"
                    and ($since == 0 or ((.done // 0) >= $now - $since))
                    and ($failed == 0 or (.status == "failure" or .status == "cancelled"))))
         | unique_by(.id) | sort_by(-(.done // 0)) | .[:$limit]) as $done
      | '
    set -l jqargs --slurpfile rs $tmp/runs --slurpfile js $tmp/jobs --slurpfile rn $tmp/runners \
        --argjson limit $limit --argjson since $since --argjson failed $failed

    # Completed runs have no jobs in the scope-level call (it lists the oldest first): fetch the shown runs' jobs,
    # for their runner, in parallel.
    for pick in (jq -nr $jqargs "$rows"'$done[] | "\(.repo) \(.id)"')
        set -l p (string split ' ' -- $pick)
        tea api "repos/$p[1]/actions/runs/$p[2]/jobs" 2>/dev/null \
            | jq -c '[.jobs[]? | {run_id, created_at, started_at, runner_name}]' >$tmp/jobs-$p[2] &
    end
    wait
    for f in $tmp/jobs-*
        cat $f >>$tmp/jobs
    end

    jq -nr $jqargs "$rows"'
        (if ($runners | length) > 0 then
           $runners[] | "#runner\t\(.name)  \(.status)\(if .busy then ", busy" else "" end)  \([.labels[]?.name] | join(","))"
         else
           "#runner\t" + ([$active[] | select(.q == "running") | .runner] | group_by(.) | map("\(.[0] // "?"): \(length) running") | join("  ") | if . == "" then "no job running" else . end)
           + "  (runner status needs a tea token with read:admin)"
         end),
        "#summary\t" + ([$active[] | .q] | group_by(.) | map("\(length) \(.[0])") | join(" · ") | if . == "" then "nothing running or queued" else . end),
        "STATUS\tAGE\tWAIT\tDUR\tREPO\tWORKFLOW\tEVENT\tREF\tRUNNER\tRUN",
        ($active[] | [.status,
            ((.created // .started) | if . then ($now - .) | hms else "-" end),
            (if .q == "running" then (if .created and .started then .started - .created else null end) else (if .created then $now - .created else null end) end | hms),
            (if .q == "running" and .started then ($now - .started) | hms else "-" end),
            .repo, .wf, .event, .ref, .runner, (.id|tostring)] | join("\t")),
        ($done[] | [.status,
            (if .done then ($now - .done) | hms else "-" end),
            "-",
            (if .done and .started then .done - .started else null end | hms),
            .repo, .wf, .event, .ref, .runner, (.id|tostring)] | join("\t"))
    ' | __ci_format $color
    rm -rf $tmp
end

# Header lines (#runner, #summary) print as-is; the table goes through column, then each row is coloured by status.
function __ci_format --argument-names color
    set -l rows
    while read -l line
        if string match -q '#*' -- $line
            set -l text (string replace -r '^#[a-z]+\t' '' -- $line)
            test $color = 1; and set_color brblack
            echo $text
            test $color = 1; and set_color normal
        else
            set -a rows $line
        end
    end
    test (count $rows) -le 1; and begin
        echo "(no runs)"
        return
    end
    printf '%s\n' $rows | column -t -s \t | while read -l line
        if test $color = 1
            switch (string split -f1 ' ' -- $line)
                case STATUS
                    set_color --bold
                case running
                    set_color yellow
                case queued waiting
                    set_color cyan
                case success
                    set_color green
                case failure
                    set_color red
                case '*'
                    set_color brblack
            end
        end
        echo $line
        test $color = 1; and set_color normal
    end
end

# One run: header, then each job with its steps.
function __ci_run --argument-names repo id
    set -l run (tea api "repos/$repo/actions/runs/$id" 2>/dev/null)
    if not echo $run | jq -e '.id' >/dev/null 2>&1
        echo "ci: run $id not found in $repo" >&2
        return 1
    end
    set -l tmp (mktemp -d)
    printf '%s\n' $run >$tmp/run
    tea api "repos/$repo/actions/runs/$id/jobs" 2>/dev/null >$tmp/jobs
    jq -nr --slurpfile r $tmp/run --slurpfile j $tmp/jobs '
      def ts: if . == null then null else (sub("[.][0-9]+"; "") | if test("Z$") then fromdateiso8601 else null end
              | if . != null and . <= 0 then null else . end) end;
      def hms: if . == null or . < 0 then "-" elif . < 60 then "\(floor)s"
               elif . < 3600 then "\(./60|floor)m\(floor % 60)s" else "\(./3600|floor)h\((./60|floor) % 60)m" end;
      def took(a; b): if (a|ts) and (b|ts) then ((b|ts) - (a|ts)) | hms
                      elif (a|ts) then (now - (a|ts)) | hms else "-" end;
      $r[0] as $run | $j[0] as $jobs |
      "\($run.display_title // "")",
      "\($run.path)  \($run.event)  \($run.status)/\($run.conclusion // "-")  run \($run.id) (#\($run.run_number))",
      "\($run.html_url)",
      "",
      ($jobs.jobs[]? |
        "\(.status)/\(.conclusion // "-")  \(.name)  \(took(.started_at; .completed_at))  on \(.runner_name // "-")",
        (.steps[]? | "    \(.number). \(.name)  \(.status)/\(.conclusion // "-")  \(took(.started_at; .completed_at))"))
    '
    rm -rf $tmp
end
