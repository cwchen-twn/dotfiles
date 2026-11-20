# rtk (token-saving CLI proxy)

Write the `rtk` prefix yourself for the commands it compacts: `rtk git ...`, `rtk gh ...`, `rtk grep ...`,
`rtk ls ...`, `rtk find ...`, `rtk make ...`, `rtk curl ...`, `rtk docker ...`. A PreToolUse hook would add it anyway,
but a hook-rewritten call makes auto mode ask for the call again; a prefixed call passes through unchanged.

- Read files with the Read tool, not `cat`/`head`/`tail`: the hook turns those into `rtk read`, which drops lines
  from structured files.
- rtk caps long output (grep at 200 matches, git status at 15 files). When you need all of it: `rtk proxy <cmd>`.
- `rtk gain` shows the savings.
