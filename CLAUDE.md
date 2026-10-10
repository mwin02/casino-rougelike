# Casino Roguelike

An iOS casino roguelike card game (blackjack, baccarat, High or Low; spend heat to beat the house) in Godot 4.6.x, typed GDScript.
Rules: `docs/spec-v4.md` (source of truth). Build order and per-block workflow: `BUILD_PLAN.md`. Both are long; read the sections you need. `docs/reference/` is background only; the spec overrides it.

## Verify

`scripts/check` runs lint then tests. It is the only verification command, and the Stop hook runs it whenever `.gd` files changed.

Visual checks: `scripts/ios_sim` builds the game for the iOS Simulator (load the `godot-ios-sim` skill). The phone stays the final on-device check.

## Architecture (enforced partly by `scripts/lint`)

- `src/core/`: the rules core. Plain `RefCounted` classes, no nodes. Never imports `src/view_models/` or `src/scenes/`.
- `src/view_models/`: everything between the rules and the screen. Plain classes, never imports scenes.
- `src/scenes/`: read a view model, draw it, forward input. No rules and no decisions.
- Every `[TUNE]` value lives in `config/` and is never hard-coded. `[OPEN]` items get a clearly named hook, never an invented answer.
- Tests in `test/` mirror `src/core/` and `src/view_models/`. The simulation harness goes in `sim/`.

## GDScript

- Static typing everywhere: every variable, parameter, return and loop variable. Typed-warning violations are errors.
- Randomness only through an injected, seeded `RandomNumberGenerator`.

## Workflow

- Start each block with `/feature <block id>`.
- When a design number changes, update `docs/spec-v4.md` in the same commit.
- A bug found visually gets a failing view-model or core test first, then the fix.
- One feature per commit.

## Git and pull requests

- `main` is protected: every change lands through a pull request, and CI (`.github/workflows/check.yml`, which runs `scripts/check`) must pass before merging. PRs are squash-merged.
- Branch from `main` as `block-<id>/<slug>`, or `tooling/<slug>` / `fix/<slug>` / `spec/<slug>` for other work.
- Keep PRs small: aim for under ~400 changed lines, excluding `.uid` files and generated scenes. If a block is bigger, split it into stacked PRs along natural seams (core, then view model, then scene) and say so in the plan.
- The PR title is the commit message (`Block 3: High or Low pricing`). Fill in `.github/pull_request_template.md` briefly. No filler, no restating the diff, and no generated-by footer.

## Stacked PRs

Uses the `gh stack` extension (github/gh-stack).

- Each PR in a stack branches from the one below it and targets that branch; only the bottom PR targets `main`.
- Link the stack as soon as its PRs are open: `gh stack link --base main <PR numbers, bottom to top>`. Run it again whenever a PR is added.
- Merge only when the developer asks, bottom-up, with `gh stack merge <pr> --squash`. Never use a plain `gh pr merge` on a stacked PR.
- Never merge a lower branch into the ones above it, and don't rewrite upper branches after a PR merges; GitHub retargets them. If a PR conflicts after a squash, fix only that PR's branch and report back.
- Rebasing a stack force-pushes, so ask first. If the merge fails because the stack is behind `main`: `gh stack init <branches, bottom to top>`, `gh stack rebase`, `gh stack push`.
- If the merge fails with `Required status check "check" is cancelled`, a force-push left a cancelled run on a head commit: `gh run rerun` it, wait for green, then merge again.
