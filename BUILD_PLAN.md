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
- [x] Done
- **Goal:** command-line bots and reports from spec §12, using the same rules core.
- **Exit:** the harness prints dollars per heat per game and quota-clearance rates, running across multiple processes. It includes the honest-adjuster bot (sizing on visible cards with no actions), whose result sets the bet-change base (spec §1.1).
- **Tests:** a fixed seed gives identical reports every run. Sanity check: the prototype's findings reproduce under the old rules (e.g. flat-priced High or Low shows a large player edge).

### Block 9 — First tuning pass
- [x] Done
- **Goal:** set per-game base costs, the High or Low cut, and cooling values.
- **Exit:** dollars per heat across the three games within 1.5× (spec §3.4); High or Low near −4%.
- **Tests:** the harness report is the test. Config changes only.
- **Starting point (block 8 harness, floor 1 high stakes, 1,000 sessions × 20 hands or 1,000 floors, default config):**
  - Marginal $/heat (gain per hand over straight flat, per heat) by blackjack / baccarat / High or Low:

	| Bot | Blackjack | Baccarat | High or Low |
	|---|---|---|---|
	| Honest adjuster (base 2) | 550 | 612 | — |
	| Reveal-only | 71 | ~0 | 152 |
	| Reveal + adjust | 173 | 442 | 223 |
	| Manipulate-max | 264 | 414 | 569 |

  - The bet-change base is far too cheap at baccarat. The honest adjuster makes +113% of the opening bet per hand and clears floor 1 97% of the time (41% at blackjack). Baccarat's later adjusts come after both totals show, so a side switch plus a 3× raise there is close to a sure thing. At base 4 it is backed off every session and still earns 299 $/heat. This may need a rule change, not only a number (spec §1.1 allows a per-game base).
  - At High or Low the honest adjuster has nothing to size on: every call is priced at true odds less the cut.
  - High or Low greedy (chasing chains) runs at −12.7% against the ~−4% target, because each call compounds the cut.
  - Honest play clears floor 1 well under the §12 target of < 20%: straight flat 4.5% / 1.4% / 0.2%. Bold play clears 22–32%.
  - Reveal and manipulate bots often end floors at a p90 run heat of 100. Ejection, the pit boss and the sweep aren't modelled until block 14, so those floors count as cleared.
  - Sweep a value with `scripts/sim --set=section.key=a,b,c`; clearance is `scripts/sim --mode=floor`.
- **Result (floor 1 high stakes, 1,000 sessions × 20 hands):**
  - Rule change: baccarat has one adjust per hand, after the initial window (spec §3.2). No bet-change base fixed the late side switch plus raise.
  - Each game has its own bet-change base and reveal and manipulation factors (spec §3.3): blackjack 5 / 1 / 1, baccarat 4 / 2 / 1, High or Low 2 / 7 / 3.5. High or Low cut stays 7%; cooling stays 10% with stake factor 0.1 → 1.0.
  - Marginal $/heat (band = max ÷ min across the games it's measured on, from unrounded values):

    | Bot | Blackjack | Baccarat | High or Low | Band |
    |---|---|---|---|---|
    | Honest adjuster | 175 | 107 | — | ≤ 1.35× reveal + adjust |
    | Reveal-only | 71 | ~0 | 75 | 1.06× (blackjack vs High or Low) |
    | Reveal + adjust | 129 | 156 | 117 | 1.34× |
    | Manipulate-max | 264 | 300 | 306 | 1.16× |

  - Low stakes keeps the bands (reveal + adjust 25 / 31 / 25, manipulate-max 62 / 64 / 69).
  - High or Low straight flat −3.9% per call; greedy chaining −12.7% per opening stake (the cut compounds per call).
  - Cooling (`cool/h`): the min-bet cooler sheds 0.11 heat per hand against 2.05 spent, so min-bet cooling barely helps; manipulate-max's straight max-bet hands shed 0.9.
  - For blocks 14 and 15: honest play clears floor 1 at 4.5% / 1.4% / 0.2%, but the honest adjuster clears 41% / 54%. The High or Low reveal bots clear ~100% while ending at run heat 100. Ejection, the pit boss and the sweep will cut these once modelled.
  - **After the bust revert to 21** (block 10 prep): blackjack straight flat −0.17%. Marginal $/heat: honest adjuster 241, reveal-only 95, reveal + adjust 142, manipulate-max 238. The game bands hold (reveal + adjust 1.37×, manipulate-max 1.28×, reveal-only 1.27×), but the honest adjuster is 1.70× reveal + adjust at blackjack, over the 1.5× limit. Applied: a blackjack bet-change base of 7 brings it to 1.33× (159 vs 120), with reveal + adjust still in band (120 / 160 / 116, 1.37×).

### Block 10 — Side bets
- [x] Done
- **Goal:** all six side bets, repriced for a single deck (spec §8).
- **Exit:** each side bet lands at 5–15% house edge on a standard deck.
- **Tests:** exact enumeration of each side bet's edge; placed at the stake window only; 25% cap; zero heat.
- **Result (floor mode, floor 1 high stakes, 1,000 floors; `--bots=side_gambler,side_chaser`, opt-in):**
  - Side-bet gambler (table minimum plus every side bet at the cap) clears floor 1 at 21% / 21% / 23% at a 25% cap, against bold 29% / 32% / 23%, in 8–24 hands (high swing). At 10% it clears only 20% / 11% / 7%; above 25% it barely moves. The cap stays 25%.
  - Side-bet chaser (every manipulation that raises the side bets' value, each window) reaches the quota in 1–5 hands but ends 95–100% of floors at run heat 100 (ejected) at every cap from 10% to 50%. Its marginal $/heat is 180–270 per session, near manipulate-max: side-bet heat prices the gain.
  - Not yet measured: a player who manipulates for side bets rarely, and the Stacker (blocks 11, 15).
- **Result after action factors, repeat multipliers and the 50 run-heat rollover cap (200 floors, cleared / ejected):**
  - Side-bet gambler unchanged: 21% / 21% / 22% cleared, against bold 32% / 28% / 22%.
  - Nudge-only chaser (`side_nudger`): 80% / 18%, 95% / 86%, 91% / 6% (blackjack, baccarat, High or Low).
  - Full chaser: 100% / 0%, 100% / 72%, 100% / 88%. At blackjack one Palm into a capped Perfect Pairs clears floor 1 in one hand, is backed off, and rolls over only the capped 50 run heat. Run-level cost (two such floors eject) waits for block 14's run model.
  - Nudge factor sweep (0.075–0.3): the Nudge-only chaser clears 80% / 95% / 91% at every factor; only ejection moves (blackjack 18% → 32%, High or Low 6% → 27%; baccarat 86–87% throughout, from the Nudges' own heat). Kept at 0.075 so one Nudge into a side bet stays cheap. **Revisit** in block 13 (items that cut this heat) and block 15 (run-level heat), where a Nudge-hunting player's run heat across floors shows.

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
- **Carried over from block 10:** side-bet heat for a Nudge (factor 0.075) is cheap enough that a Nudge-hunting side-bet player clears floor 1 80–95% of the time. Design items that reduce or reshape side-bet heat with this in mind, then re-run `--bots=side_nudger,side_chaser`.

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

### Block 17 — House rules and game modifiers
- [ ] Done
- **Goal:** house-rule variants as game modifiers: blackjack's bust threshold (e.g. 23), dealer rules, and the rule changes floor signatures make (spec §3.1, §5.3). Unscheduled; slot it in when the run structure needs it.
- **Exit:** a table or floor can change a game's house rules through config, and the side bets and the harness price against the rules in play.
- **Tests:** each modifier changes play as specified; side-bet edges stay in band under each modifier the game uses.

## UI track (starts after block 7)

### U1 — Debug table screen
- [x] Done
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
