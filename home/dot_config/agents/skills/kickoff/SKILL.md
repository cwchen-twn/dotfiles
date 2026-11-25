---
name: kickoff
description: Starts a freshly generated project (from the project-template repo, usually via the `new-project` script). It asks the user to explain the idea, files the "Product docs" issue and branch, records the idea in CLAUDE.md, and hands off to the product-docs skill at the PRD stage. Use when the user types /kickoff, or says they want to start a new project, explain a new idea, or begin the dev flow in an empty repo.
---

# Kickoff: idea → issue → product docs

`new-project <name> [description]` has already created the repo from `project-template`, cloned it and run
`make init`. This skill handles the conversational part. It then hands off to **product-docs**, which takes the
idea through its four stages (PRD, flows and sitemap, mockups, OpenSpec handoff), each one reviewed by the user.

## 1. Check the repo

- `CLAUDE.md` has a `## Git profile` and `docs/product/` holds only `.gitkeep`. If product docs already exist, don't
  start over: say what's there and continue the **product-docs** stage the docs have reached.
- `git status` is clean and on `main`. `make help` works.
- Not a template-generated repo (no Git profile, no Makefile)? Say so and suggest `new-project`, or offer to retrofit
  it with the **makefile** skill first.

## 2. Hear the idea

Ask the user to explain the idea in their own words, as long or as short as they like. Don't send a questionnaire.
Then ask, in one message, only what product-docs stage 1 needs and the explanation didn't cover:

- the target users;
- the one outcome that defines success;
- hard constraints (platforms, budget, deadline, offline, privacy).

Don't pick a stack yet. That decision comes after the mockups, during planning.

## 3. Issue and branch (git-flow)

Follow the **git-flow** skill and the repo's Git profile:

1. Issue **"Product docs for <name>"**:
   - `## Description`: the idea as the user told it, tidied but not reinterpreted, plus users, success and constraints.
   - `## Plan`: the product-docs stages: PRD → flows and sitemap → mockups → OpenSpec proposal.
2. Branch `<issue>-product-docs` from `main`.

Creating the issue and branch is part of kickoff. Commit, push and open the draft PR once the work is ready to push
(git-flow, "Ready to push").

## 4. Record the idea

In `CLAUDE.md`, replace the `**Status:**` line with a two- or three-sentence summary of the idea and
`**Status:** product docs (issue #<n>)`. Later stages update the status: planning, implementing, released.

## 5. Hand off

Load the **product-docs** skill and start stage 1: write `docs/product/prd.md` from its template, using what the user
already said, and stop for their review. From here product-docs drives the flow. After its stage 4
(`/openspec-propose`), the flow goes on to planning, implementation (`test-runner`, `e2e-tester` against the
mockups), `/code-review` and the PR, as AGENTS.md's working model describes.
