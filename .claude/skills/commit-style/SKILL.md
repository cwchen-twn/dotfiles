---
name: commit-style
description: Writes commit messages for the dotfiles repo in its own style. Scoped conventional subjects state the outcome, not the edit. Bodies open with the reason, list the changes as bullets, and close with the issue reference. Use when committing, staging and committing, writing or rewriting a commit message, or preparing a PR title or description in this repository. Overrides the git-flow skill's default commit style; git-flow still governs the issue, branch, PR and merge flow.
---

# Commit messages (dotfiles)

Derived from the repo's history, where the newest 60 commits are all conventional, 56 of them with a scope. git-flow
adds two rules the history didn't always follow: **the body opens with the reason**, and **the footer references the
issue**. The oldest commits (`add vim-latex-live-preview`) predate any convention; don't copy them.

## Format

```text
<type>(<scope>): <Subject that states the outcome>

<Reason: what was wrong, missing or requested, with the symptom or the measurement.
Wrapped at ~90 columns.>

- <area>: <what changed>, <so that / because ...>
- <area>: <what changed>

<Ruled out: what was tried or considered and why it lost, when anything was.>

Closes #<issue>
Co-Authored-By: ...
```

## Type and scope

| Type | Use for |
|---|---|
| `feat` | A new capability on the machines: a tool, a role, a widget, a config that didn't exist |
| `fix` | Wrong behaviour, a trap found, a regression |
| `perf` | Faster or lighter, same behaviour (CPU, RAM, boot, battery) |
| `chore` | Maintenance: renames, pins, lockfiles, re-encrypting, repo housekeeping |
| `docs` | README or CLAUDE.md only, with no config change |

**The scope is required.** It names the area of the machine, not a file. Reuse an existing scope:

- desktop session: `desktop` `lxqt` `fcitx5` `touchpad` `look` `fonts`;
- apps: `brave` `audio` `video` `music` `camera` `dbeaver`;
- shell and tools: `fish` `nvim` `tools` `mise` `ssh`;
- machine setup: `base` `macbook` `install` `hibernate`;
- infra: `vpn` `k8s` `infra`;
- repo and agents: `chezmoi` `claude`.

Add a new scope only for a new area. `chore(deps):` is reserved for Renovate.

## Subject

- **It states the outcome or the finding, in the present, not the edit.** Capitalised after the colon, no period,
  about 85 characters at most (the median is 59).
- Patterns that read well here:
  - "X no longer Y"
  - "X survives Y"
  - "A via B, not C"
  - "X shows Y, and follows changes"
  - a tool name followed by what it does
- Good:

  ```text
  fix(desktop): A Wi-Fi drop no longer makes the left Conky window vanish
  fix(brave): GPU video decoding via the non-free Intel media driver, not flags
  fix(macbook): Wi-Fi survives sleep, and the lid suspends then hibernates
  perf(brave): YouTube in H.264 with hardware decoding
  ```

- Too thin, because it says what a diff already shows:

  ```text
  fix(conky): Update widgets.lua
  feat: Add lock screen
  fix(desktop): Added restart logic       (past-tense "Added X" is another repo's style)
  ```

## Body

1. **The reason comes first, always, even before bullets.** One short paragraph covers:
   - what was wrong, missing or requested;
   - how it showed: the symptom, the exact error, the measurement (`renderer ~120% of a core`,
     `16x16 in the middle of the screen`, `~50 s after wake-up`).

   A bullets-only body is out of style, even when the change is small.
2. **Then `-` bullets, one per change**, led by the area: `desktop role: …`, `conky-desktop: …`, `README: …`. Each says
   what changed and, when it isn't obvious, why ("so that…", "because…", "(was …)"). A one-change commit may skip
   bullets and say it in the reason paragraph.
3. **Ruled out**, when anything was: what was tried and why it lost. Experiments that bisect a problem belong here.
4. **Footer:**
   - `Closes #N` on the commit that completes the issue, or `Refs #N` on intermediate commits;
   - then the `Co-Authored-By` line the session asks for.

Body rules:

- Wrap at ~90 columns. The measured p90 is 91.
- Plain ASCII punctuation is fine (`->`, `--`). Write `~` for approximate numbers.
- **Never claim a measurement you didn't take.** The value of these bodies is that their numbers can be trusted.
- **This repo is public:** no secrets, internal hostnames, IPs or work-project names in messages either.
- Name what the user must do differently, if anything. For example, "takes effect after a reboot", or "run
  `chezmoi apply`".

## Examples (from this history, with the git-flow footer)

```text
fix(desktop): A Wi-Fi drop no longer makes the left Conky window vanish

The left window disappeared after Wi-Fi dropped a few times. It hadn't crashed: it was a
16x16 square in the middle of the screen with its main loop hung. net_watch reloaded the
window in place (SIGUSR1) on every network change, and Conky's in-place reload rebuilt
the window wrong; a fresh start of the same config drew it correctly.

- net_watch: starts a fresh Conky with the same config and exits the old one, instead
  of SIGUSR1. Tested with a stale network list at start: it replaced itself once.
- conky-desktop: SIGKILL for whatever is left a second after pkill, since a hung Conky
  ignores SIGTERM.

Closes #12
Co-Authored-By: ...
```

```text
fix(brave): GPU video decoding via the non-free Intel media driver, not flags

Measured with brave-decode-test (1080p60 H.264): Brave picked VaapiVideoDecoder, then fell
back to FFmpeg on this Broadwell GPU with or without flags (renderer ~120% of a core),
while brave://gpu said "Hardware accelerated". The free driver has no VideoProc entrypoint;
the non-free one has, and the clip then decodes on the GPU (renderer ~15%).

- desktop role: intel-media-va-driver-non-free on Intel graphics.
- The generated Brave menu entry with VA-API flags is removed (not needed).

Ruled out: VA-API flags alone, the i965 driver.

Closes #7
Co-Authored-By: ...
```

```text
feat(tools): brave-decode-test

brave://gpu reports "Hardware accelerated" even when every video falls back to software,
so there was no honest way to check GPU decoding. This plays a 1080p60 H.264 clip in a
throwaway Brave profile and reports the decoder, the media log and CPU per process type;
exit 0 hardware, 1 software, 2 untestable.

Refs #7
Co-Authored-By: ...
```

## Don't

- Leave out the scope, or end the subject with a period.
- Write a past-tense edit as the subject ("Added X", "Updated Y").
- Write a bullets-only body with no reason.
- Commit without the issue reference: every change has an issue (git-flow), Renovate PRs excepted.
- Rewrite pushed history on `main`.
