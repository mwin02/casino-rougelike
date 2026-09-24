# Casino Roguelike

An iOS casino roguelike card game (blackjack, baccarat, High or Low; spend heat to beat the house) in Godot 4.6.x, typed GDScript.
Rules: `docs/spec-v4.md` (source of truth). Build order and per-block workflow: `BUILD_PLAN.md`. Both are long; read the sections you need. `docs/reference/` is background only; the spec overrides it.

## Verify

`scripts/check` runs lint then tests. It is the only verification command, and the Stop hook runs it whenever `.gd` files changed.

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
