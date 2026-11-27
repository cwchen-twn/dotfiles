---
name: mint
description: Mints an app's images, icons and videos with the mint tool: prompts in assets/manifest.yaml are the spec, a swappable backend (Google Flow today, manual download as the fallback) produces them, and the outputs are committed. Covers the manifest format, the assets/build and assets/icons make targets, spending Flow credits carefully, and the manual fallback. Use when an app needs an icon, logo, favicon, hero or marketing image, illustration or video clip, when asked to generate media with Gemini, Nano Banana, Veo, Flow or "Google AI", or when adding asset targets to a project.
---

# mint: manifest → backend → committed assets

The name is the metaphor: a mint strikes official coinage from approved dies. Here the dies are the prompts in
`assets/manifest.yaml`, the press is whichever backend is plugged in, the coins are the committed files (never
overwritten without `--force`), and every strike has a cost the ledger tracks (`mint credits`).

Apps never call an image or video provider. They describe what they need in `assets/manifest.yaml`, `mint`
produces it, and the result is **committed**. CI and `make audit` never generate anything, so a cancelled subscription
or a broken backend only stops *new* generation. Every existing asset keeps building.

`mint` exists only on machines with the `mint` chezmoi extra. Run `mint --help`. If it is missing, say so
and stop. Don't fall back to calling a provider some other way.

## Backends

| `MINT_BACKEND` | What it does | Cost |
|---|---|---|
| `flow` (default) | Google Flow through gflow-cli, on the Google AI Plus subscription | images: no credits (daily quota); video: Flow credits, 200/month on AI Plus, no rollover |
| `manual` | prints the prompt, opens Flow, waits for the file the user downloads, moves it to `--out` | the user's time |

Adding a backend (for example a paid API with a key) is one `case` branch in `~/.local/bin/mint`
(`home/dot_local/bin/executable_mint` in the dotfiles repo). Apps don't change.

**Risk, accepted by the user:** gflow-cli is unofficial. It drives Flow's web UI in a real browser on the user's main
Google account. If `flow` starts failing (sign-in, UI changes, WAF 403s), switch to `MINT_BACKEND=manual` and
report it. Don't retry in a loop or work around Google's checks.

### Flow backend setup and pitfalls

- One-time: `mint login` (a browser window; sign in until the Flow editor loads), then `mint project <url>`
  with a Flow project made for this, so every generation lands in it instead of a new project each time.
- The browser is Brave standing in for Chrome at `/opt/google/chrome/chrome` (mint ansible role).
- **Open gflow's browser profile only with `mint browse`.** It adds `--password-store=basic`, which is how gflow
  stores the profile's cookies. Opening the profile any other way re-encrypts them with the desktop keyring: Flow then
  shows its public `/about` page and gflow reports a Flow app error until `mint login` is run again.
- Close the `mint browse` window before generating: gflow refuses a profile that is in use ("Profile locked").
- A first visit shows a welcome/consent dialog that covers Flow's buttons (gflow: "UI selector drift" on the
  new-project button). Dismiss it once in `mint browse`.
- gflow errors say whether anything was charged (`"charged": "no"`). Incident bundles with a screenshot go to
  `~/.local/share/gflow-cli/incidents/`. Look at the screenshot before guessing.

## Credit discipline

- **Draft before spending.** Iterate on wording and style in the Gemini app (included in the plan) or with Flow images,
  which are free. Spend video credits only on a prompt that already works as a still.
- **Video:** use `--model veo-lite` (the cheapest) and `--duration 4`. Flow offers no length control on this account,
  so `mint` generates at Flow's default length and trims to `--duration` locally (ffmpeg); the cost is the default
  length's. `MINT_MAX_CREDITS` (default 20) makes gflow refuse any call whose quote is higher. Raise it for a single
  run only when the user asks. Model names: `gflow models`.
- **Ask the user before** any run expected to spend more than about 20 credits in total, such as several clips or a
  re-render of the whole manifest.
- After generating, run `mint credits` and report the balance and this month's spend from the ledger.
- Measured costs (update when a run shows otherwise): an image costs 0 credits (Nano Banana 2, 1024×1024, delivered as
  JPEG and converted to the `--out` extension). A `veo-lite` 16:9 clip costs 10 credits (720p H.264 with audio,
  2026-11-27). The account showed 250 credits before that run.

## The app convention

```text
assets/
  manifest.yaml        what to generate: the source of truth, reviewed in PRs
  src/                 masters exactly as generated (icon master, hero, clips)
public/ or app paths   derived files (icon sizes, favicon), committed too
```

`assets/manifest.yaml`:

```yaml
# Generated media. `make assets/build` makes the entries whose `out` is missing; delete a file to regenerate it.
- id: icon
  kind: image            # image | video
  prompt: >-
    Flat vector app icon, a ledger book with a small star, deep navy and gold,
    centred on a plain background, no text
  aspect: "1:1"
  out: assets/src/icon.png
- id: hero
  kind: image
  prompt: ...
  aspect: "16:9"
  out: assets/src/hero.png
- id: intro
  kind: video
  prompt: ...
  refs: [assets/src/hero.png]   # first frame or style reference
  aspect: "16:9"
  duration: 4
  out: assets/src/intro.mp4
```

Write prompts that name the subject, the style, the palette and the framing, and say "no text" for icons: generated
lettering is unreliable. Keep the brand palette in one place (the PRD or a design doc) and repeat it in each prompt.

## Make targets

Add these to the app's Makefile (makefile skill: `group/action` names, `##` help lines). They write committed files and
are **never** part of `audit` or CI.

Copy [templates/assets.mk](templates/assets.mk) into the app's Makefile (or `include` it). It defines:

- `assets/build`: reads the manifest with `yq` and calls `mint` for each entry whose `out` is missing.
- `assets/icons`: `mint icons assets/src/icon.png $(ICON_OUT)` (default `public/icons`).

`yq` comes from the project's `mise.toml` (`yq = "latest"`). `mint icons` makes `icon-{16…1024}.png`,
`apple-touch-icon.png`, `favicon.ico` and `icon-maskable-512.png` (the master at 56%, inside the circular safe
zone). Point the web manifest and the `<link rel="icon">` tags at them.

## Workflow

1. Add or edit the entry in `assets/manifest.yaml`. To regenerate, delete the old output or pass `--force` once.
2. `make assets/build`, then look at every result (Read the image, `ffprobe` the video) before keeping it. If one is
   wrong, refine the prompt and regenerate that entry only.
3. `make assets/icons` when the icon master changed.
4. Commit the manifest, the masters and the derived files together. The commit says which prompts changed.

## Other AI Plus benefits

Gemini Notebook (research, audio overviews), Flow Music and Colab (notebook GPU time, not a server) are manual tools in
their web apps. There is no automation for them here.
