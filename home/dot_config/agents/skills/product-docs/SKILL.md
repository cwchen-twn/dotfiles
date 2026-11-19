---
name: product-docs
description: Turns an idea into reviewable product docs before any code. Produces a PRD in Markdown, user flows and a sitemap as Mermaid in Markdown, and clickable HTML UI mockups that the user reviews live in their local browser. Claude self-checks them with headless Brave screenshots, and publishes a private Artifact only on request. Ends with a handoff to OpenSpec. Use when starting a new app or a feature with UI, when asked for a PRD, user flow, sitemap, wireframe, mockup or prototype, or before redesigning an existing screen.
---

# Product docs: idea → PRD → flows → mockups → spec

There are four stages, and **each ends with the user's review**.

- Don't start the next stage until the user approves the current one, or explicitly says to continue.
- Everything lives in the repo under `docs/product/`, so it is versioned and reviewed in the PR.

Small change to an existing screen? Skip to stage 3, and start it by screenshotting the current UI.

## Stage 1: PRD (`docs/product/prd.md`)

Start from [templates/prd.md](templates/prd.md). Before writing, ask the user only what can't be inferred:

- the target users;
- the one outcome that defines success;
- hard constraints (platforms, budget, deadline).

Keep it short:

- a problem statement;
- users and their jobs;
- goals and non-goals;
- features, each with **testable acceptance criteria** (these become the E2E checks later);
- open questions.

## Stage 2: user flows and sitemap

- **`docs/product/flows.md`:** one Mermaid `flowchart` per key flow. Mark decisions, errors and empty states, and give
  every screen node the same name it will have in the sitemap and the mockups.
- **`docs/product/sitemap.md`:** one Mermaid `flowchart TD` of the screens and their navigation. Add a table of screen
  → purpose → mockup file.

Mermaid in Markdown renders on Gitea, GitHub and GitLab, and in nvim's markdown preview. **Check the syntax**: a broken
diagram renders as an error block. Keep node IDs alphanumeric, and quote any label that contains punctuation:
`A["Sign in (SSO)"]`.

## Stage 3: UI mockups (`docs/product/mockups/<screen>.html`)

Follow the **frontend-design** skill for the visual direction, and agree on that direction with the user on the first screen.

1. **One self-contained HTML file per screen**, or per important state (empty, error, loading).
   - Inline CSS and JS; no build step.
   - Realistic sample data, never lorem ipsum.
   - Light and dark themes via `prefers-color-scheme`.
   - Responsive from 390 px (phone) to 1280 px (desktop).
   - Links between mockups follow the sitemap, so the set is clickable.
   - For a mobile app, design at 390x844 first.
2. **Look at it before the user does.** Screenshot every viewport in both themes with the installed Brave (headless
   Chromium, no extra browser), and read the PNGs. Fix overflow, clipping, contrast and alignment until they look right.

   ```bash
   # the packaged binary: ~/.local/bin/brave-browser adds force-dark, which would repaint the mockups
   B=/usr/bin/brave-browser; [ -x "$B" ] || B="/Applications/Brave Browser.app/Contents/MacOS/Brave Browser"
   S=docs/product/mockups/.shots; mkdir -p "$S"; f=docs/product/mockups/<screen>.html
   for vp in 390,844 1280,800; do
     "$B" --headless --disable-gpu --hide-scrollbars --window-size=$vp \
       --screenshot="$S/<screen>-${vp/,/x}.png" "file://$PWD/$f"
     "$B" --headless --disable-gpu --hide-scrollbars --window-size=$vp --blink-settings=preferredColorScheme=0 \
       --screenshot="$S/<screen>-${vp/,/x}-dark.png" "file://$PWD/$f"
   done
   ```

   - The window size is the viewport, so for a long page raise the height (e.g. `390,2400`) to capture all of it.
   - No Brave on this machine? Use
     `npx -y playwright screenshot --viewport-size=390,844 --full-page [--color-scheme=dark] <url> <png>` instead. It
     downloads Chromium on first use.
   - Add `.shots/` to `.gitignore` unless the user wants the screenshots committed.
   - **These screenshots are your own check, not a deliverable.** You can't see a rendered page any other way. Don't
     post them to the user unless they ask, or unless you're discussing a specific rendering problem.
3. **Open it for the user.** The review happens in the user's own browser, on the live local file.
   - First round: `xdg-open docs/product/mockups/<screen>.html` (`open` on macOS) opens it in their default browser.
   - Every round ends with a short list of what changed, and "reload".
   - Feedback comes in chat. If it's ambiguous, ask which screen, state, viewport or theme they mean.
4. **Iterate.** Edit the file in the repo, re-run the self-check screenshots, report the changes, and tell the user to
   reload. Repeat until they approve.
5. **Artifact only on request.** Publish a screen as a private Artifact only when the user asks: to view it on their
   phone, to comment inline, or to share it. Follow the Artifact tool's design rules.
   - Later rounds republish to the **same** Artifact.
   - The repo file stays the source of truth, so apply any Artifact comments back to it.
6. **Existing UI?** Screenshot the current state first. Use the running app via the `e2e-tester` subagent, or a desktop
   screenshot for a non-web UI. Mock up the change next to it so before and after can be compared.

## Stage 4: Handoff

- In a repo that uses OpenSpec (an `openspec/` dir exists, or the user agrees to `openspec init`), create the change
  with `/opsx:propose`, or `openspec` directly.
  - Reference `docs/product/` from the proposal.
  - Turn each acceptance criterion into a task, naming the **make target that verifies it** (e.g. `make test/e2e`).
- Otherwise, write the same task list into the git-flow issue's `## Plan`.
- After implementation, the **e2e-tester** subagent screenshots the real UI at the mockup viewports and reports any
  differences from the approved mockups.
