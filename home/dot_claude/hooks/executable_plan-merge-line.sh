#!/usr/bin/env bash
# PreToolUse hook for ExitPlanMode: a plan made in a git repo must say who merges its PR,
# with a `Merge: agent (...)` or `Merge: ask (...)` line (git-flow skill, "Agent-merged PRs").
# Reads the hook JSON on stdin; denies the tool call when the line is missing.
set -euo pipefail

input=$(cat)
cwd=$(jq -r '.cwd // empty' <<<"$input")

# Outside a repo there is no PR to merge.
git -C "${cwd:-.}" rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

plan=$(jq -r '.tool_input.plan // empty' <<<"$input")
if [[ -z $plan ]]; then
    file=$(jq -r '.tool_input.planFilePath // empty' <<<"$input")
    if [[ -z $file ]]; then
        # shellcheck disable=SC2012 # plan file names are generated slugs, no odd characters
        file=$(ls -t "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/plans/*.md 2>/dev/null | head -n 1 || true)
    fi
    [[ -n $file && -r $file ]] || exit 0
    plan=$(<"$file")
fi

if grep -Eq '^\**Merge:\**[[:space:]]+(agent|ask)([^[:alnum:]]|$)' <<<"$plan"; then
    exit 0
fi

jq -n '{hookSpecificOutput: {
	hookEventName: "PreToolUse",
	permissionDecision: "deny",
	permissionDecisionReason: "The plan has no Merge line. Add `Merge: agent (<one-line reason it is low-risk>)` or `Merge: ask (<reason>)` at the end of the plan file (git-flow, Agent-merged PRs), then call ExitPlanMode again."
}}'
