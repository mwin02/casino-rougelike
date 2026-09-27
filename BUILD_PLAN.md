# Casino Roguelike — Build Plan

**Source of truth for rules:** `docs/spec-v4.md`. This file tracks *what to build and in what order*. When a block changes a design number, update the spec in the same commit.

## Stack

- Godot 4.6.x (pinned; 4.7 has an open iOS export link bug)
- Typed GDScript, type warnings treated as errors
- GdUnit4 for tests, run from the command line (`--headless --ignoreHeadlessMode`), version pinned to match Godot
- gdlint for linting
- iOS export via Xcode 26.x (App Store requires the iOS 26 SDK or later)

## Architecture rules

1. **Rules core:** plain GDScript classes, no scene nodes. Fully tested.
2. **View models:** everything between rules and screen (button states, preview text, summaries, lists). Plain classes. Fully tested.
3. **Scenes:** read a view model, draw it, forward input. No decisions. Checked manually.

The core never imports from view models or scenes. Scenes never implement rules.

## Workflow per block

1. Fresh Claude Code session.
2. Plan mode: read the relevant spec sections and existing code; the plan is approved before coding.
3. Implement with the tests listed for the block.
4. Stop hook runs GdUnit4 + gdlint; the turn can't end until they pass.
5. Reviewer subagent checks the diff against the spec.
6. For anything visual: Claude provides a manual-check list; the developer confirms.
7. Bugs found by eye get a failing test first (view model or core), then the fix.
8. One feature per commit, landed through a small pull request (see CLAUDE.md, "Git and pull requests"). Large blocks split into several PRs. Tick the block's status below when its exit condition is met.

Blocks 2–4 are independent. Blocks 9 and 15 are tuning only (config changes, no new systems). The UI track starts after block 7 and runs alongside the rest.

---

## Foundation

### Block 0 — Pipeline test
- [x] Done
- **Goal:** prove the toolchain end to end before building anything real.
- **Exit:** Godot 4.6 project with GdUnit4, gdlint, a Stop hook running both, and CLAUDE.md. One blackjack hand (deal, hit, stand, resolve) in plain GDScript, shown in a bare scene, running on a physical iPhone.
- **Tests:** hand totals (soft/hard aces, bust at 23); dealer hits soft 17; blackjack pays the configured payout (3:2 by default, 6:5 when set).
- **Manual:** the scene shows the hand; the app launches on the device.

### Block 1 — Core primitives
- [x] Done
- **Goal:** the building blocks every later system uses.
- **PRs:** four stacked: (1) cards, deck, seeded RNG; (2) manipulation layer; (3) event log and save/load; (4) every `[TUNE]` value in config with a typed schema. `[TUNE]` tags with no starting number (stake_factor, deck service prices, clear-marks price, marker interest, pit boss scaling) are added by the blocks that build them.
- **Exit:** card and deck types (composition, edit tracking, symbol marks), seeded RNG, reshuffle every hand, event log, one config file holding every `[TUNE]` value, save/load of game state.
- **Tests:** same seed gives the same shuffle; manipulation changes never touch the owned deck, which is back to full composition after each hand (or after the session, for a taped change); save/load round-trips exactly; minimum deck size enforced; config values load and are type-checked.

## Games (rules only, no heat)

### Block 2 — Blackjack
- [x] Done
- **Goal:** complete blackjack per spec §3.1, with windows as explicit phases.
- **Exit:** a full hand plays through every phase, with doubles, splits, and insurance.
- **Tests:** window order (hole card, before each hit, final); splits act as extra lives; doubles and splits recorded as bet changes; payouts for every result.

### Block 3 — Baccarat
- [x] Done
- **Goal:** baccarat per spec §3.2.
- **Exit:** fixed third-card rules, three windows, Player/Banker/Tie.
- **Tests:** table-driven test of every third-card draw rule; window placement; side switch recorded as a bet change; banker commission.

### Block 4 — High or Low
- [x] Done
- **Goal:** High or Low per spec §3.3.
- **Exit:** calls priced against the actual remaining cards; chains and banking work.
- **Tests:** payouts match the pricing formula exactly; tie loses half the stake (mid-chain: keep half the chain value); 3× per-call cap and 20× chain cap; no reshuffle within a chain; bet locks when a chain starts.

## Actions and heat

### Block 5 — Actions
- [x] Done
- **Goal:** all eight actions and bet adjusts, in all three games.
- **Exit:** knowledge actions reveal the right information, manipulation changes cards correctly, bet limits enforced.
- **Tests:** each partial reveal question answers correctly per game; Nudge doesn't wrap; manipulation lasts the hand unless Masking Tape, a Cold Seal or an Ink charge extends it; only the permanent ones edit the deck; marks apply symbols and show when the card enters play; any manipulation locks the bet (no adjust, double, split, or side switch afterwards); raises cap at 3× opening, decreases floor at 0.5×.

### Block 6 — Heat model
- [x] Done
- **Goal:** spec §1 and §7.1–7.2 in full.
- **Exit:** every hand produces itemized heat events, with the multiplier applied at resolution.
- **Tests:** a hand with no actions has zero heat even with bet changes; $1,000 → $2,000 → $3,000 costs the same as $1,000 → $3,000 (both superseded in U1: each adjust and side switch now adds a bet-change base, spec §1.1); multiplier is symmetric; per-table rolls stay within bounds for a given seed; second-window ×1.7 surcharge; Watched ×1.5, Marked ×2; cooling decays on consecutive straight hands and never drops below the heat floor; Marked consequence rolls once per session; backed off at 90.

### Block 7 — Table session
- [x] Done
- **Goal:** a playable session at one table: sit down, play hands, stand up.
- **Exit:** the session tracks bankroll and table heat; standing up or being backed off rolls heat into run heat; each hand summary shows dollars per heat.
- **Tests:** only heat above the floor rolls over; 50% vs 100% rollover; straight-hand detection; session ends correctly on backed off or broke; High or Low prices every chain against the deck captured at sit-down (a card sealed this session keeps its old price, spec §3.3).

## Balance

### Block 8 — Simulation harness
- [ ] Done
- **Goal:** command-line bots and reports from spec §12, using the same rules core.
- **Exit:** the harness prints dollars per heat per game and quota-clearance rates, running across multiple processes. It includes the honest-adjuster bot (sizing on visible cards with no actions), whose result sets the bet-change base (spec §1.1).
- **Tests:** a fixed seed gives identical reports every run. Sanity check: the prototype's findings reproduce under the old rules (e.g. flat-priced High or Low shows a large player edge).

### Block 9 — First tuning pass
- [ ] Done
- **Goal:** set per-game base costs, the High or Low cut, and cooling values.
- **Exit:** dollars per heat across the three games within 1.5× (spec §3.4); High or Low near −4%.
- **Tests:** the harness report is the test. Config changes only.

### Block 10 — Side bets
- [ ] Done
- **Goal:** all six side bets, repriced for a single deck (spec §8).
- **Exit:** each side bet lands at 5–15% house edge on a standard deck.
- **Tests:** exact enumeration of each side bet's edge; placed at the stake window only; 25% cap; zero heat.

## Run structure

### Block 11 — Deck services and heat floor
- [ ] Done
- **Goal:** shop services and the deviation heat floor (spec §4).
- **Exit:** removal, addition, three reforge tiers, and clear marks work; the heat floor follows the deck.
- **Tests:** floor step per edit and per mark; removal cost escalates; clearing marks lowers the floor; minimum deck size blocks removals.

### Block 12 — Floor layer
- [ ] Done
- **Goal:** one full floor (spec §5–6).
- **Exit:** hand clock, low- and high-stakes table offers, shop stops, quota threshold, cash out / press on, marker.
- **Tests:** only table hands use the clock; quota is reached, not paid; unused hands shed run heat on cash out; marker fronts at most 50% of quota and adds loan + interest to the next quota; a second failure ends the run.

### Block 13 — Items
- [ ] Done
- **Goal:** all 26 items, 6 item slots, and the Masking Tape and Cold Seal consumables (spec §9).
- **Exit:** every item works through a common effect system; unlocks gate their actions.
- **Tests:** one test per item proving its effect; slot limit enforced; actions unavailable until their unlock is owned.

### Block 14 — Tower and run
- [ ] Done
- **Goal:** a full run, floor 1 to floor 5 (spec §5.3, §7.3–7.6, §11).
- **Exit:** five floors with signatures, two-way elevator choice, run heat with pit boss / sweep / ejection, win, score, resume from save.
- **Tests:** run heat thresholds trigger at 40, 70, 100; elevator sheds run heat; sweep offers the item-or-symbol choice; quotas and stakes scale per floor; a full run completes from a fixed seed.

### Block 15 — Full-run tuning
- [ ] Done
- **Goal:** meet every simulation target in spec §12.
- **Exit:** clearance rates, surplus impact, and run-heat budget on target; each archetype bot viable.
- **Tests:** the harness report, including the known-risk checks (Whale at High or Low, Forged Papers + Luminous Ink, etc.). Config changes only.

## UI track (starts after block 7)

### U1 — Debug table screen
- [ ] Done
- **Goal:** a plain screen to play any game at one table.
- **Exit:** every action and adjust reachable; itemized heat visible.
- **Tests:** view-model tests (button states, heat preview text, hand summary).
- **Manual:** play a hand of each game.

### U2 — Real table screen
- [ ] Done
- **Goal:** finished table layout, card visuals (including the masking-tape strip on taped cards), heat meter with tiers.
- **Exit:** a full session playable on the phone.
- **Tests:** view-model tests for tier display, the multiplier line, and which cards show tape.
- **Manual:** layout and readability on a real device.

### U3 — Deck view
- [ ] Done
- **Goal:** Balatro-style deck screen showing edits and symbols.
- **Tests:** view model lists every card with the correct symbol and edit state.
- **Manual:** readability.

### U4 — Floor and run screens
- [ ] Done
- **Goal:** floor map, table offers, shop, elevator choice, run summary.
- **Tests:** view models for offers, prices, slot limits, clock display.
- **Manual:** a full floor played on the phone.

### U5 — Polish
- [ ] Done
- **Goal:** animation, sound, haptics, onboarding.
- **Manual only.**

## Release

### Block 16 — iOS release
- [ ] Done
- **Goal:** ship to TestFlight, then the App Store.
- **Exit:** a build made with Xcode 26 on the iOS 26 SDK passes review; privacy labels, age rating, and store assets done.
- **Tests:** full test suite and harness pass on the release build.
- **Manual:** a full run on a real device; save/resume across an app restart.
