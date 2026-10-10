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

Blocks 2–4 are independent. Blocks 9 and 15 are tuning (config changes, no new game systems; block 15 also built the harness bots it needed, plus two small rule changes). The UI track starts after block 7 and runs alongside the rest.

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
- [x] Done
- **Goal:** shop services and the deviation heat floor (spec §4).
- **Exit:** removal, addition, three reforge tiers, and clear marks work; the heat floor follows the deck.
- **Tests:** floor step per edit and per mark; removal cost escalates; clearing marks lowers the floor; minimum deck size blocks removals.

### Block 12 — Floor layer
- [x] Done
- **Goal:** one full floor (spec §5–6).
- **Exit:** hand clock, low- and high-stakes table offers, shop stops, quota threshold, cash out / press on, marker.
- **Tests:** only table hands use the clock; quota is reached, not paid; unused hands shed run heat on cash out; marker fronts at most 50% of quota and adds loan + interest to the next quota; a second failure ends the run.

### Block 13 — Items
- [x] Done
- **Goal:** all 26 items, 6 item slots, and the Masking Tape and Cold Seal consumables (spec §9).
- **Exit:** every item works through a common effect system; unlocks gate their actions.
- **Tests:** one test per item proving its effect; slot limit enforced; actions unavailable until their unlock is owned.
- **Carried over from block 10:** side-bet heat for a Nudge (factor 0.075) is cheap enough that a Nudge-hunting side-bet player clears floor 1 80–95% of the time. Design items that reduce or reshape side-bet heat with this in mind, then re-run `--bots=side_nudger,side_chaser`.
- **Result (floor mode, floor 1 high stakes, 200 floors, cleared / ejected; blackjack, baccarat, High or Low):** no item cuts side-bet heat. Sleight cuts only the Nudge's action cost, and Side Pocket's larger stake raises side-bet heat in proportion.
  - No items: Nudge-only chaser 80% / 18%, 95% / 86%, 91% / 6%; full chaser 100% / 0%, 100% / 72%, 100% / 88% (block 10's numbers).
  - `--items=side_pocket,sleight`: Nudge-only chaser 66% / 3%, 74% / 43%, 73% / 1%; full chaser 100% / 0% at all three.
  - Side Pocket lowers the Nudge-only chaser's clearance (bigger side stakes swing harder) but turns the full chaser into a one-hand floor: one capped Palm clears it, and the 50 run-heat session cap means no ejection. **Revisit** in block 15 with run heat across floors: Side Pocket + Cold Deck is the side-bet build to watch.

### Block 14 — Tower and run
- [x] Done
- **Goal:** a full run, floor 1 to floor 5 (spec §5.3, §7.3–7.6, §11).
- **Exit:** five floors with signatures, two-way elevator choice, run heat with pit boss / sweep / ejection, win, score, resume from save.
- **Tests:** run heat thresholds trigger at 40, 70, 100; elevator sheds run heat; sweep offers the item-or-symbol choice; quotas and stakes scale per floor; a full run completes from a fixed seed.
- **Decisions:** signatures are a pool for floors 2–4 (floor 5 is the `[OPEN]` boss hook); Stingy house pays main-game winnings at 90% instead of 6:5 and a raised cut; the run saves anywhere but mid-hand. `scripts/sim --mode=run` plays whole runs.
- **First look (40 runs each, default config):** no bot wins a run. Ejected: reckless chaser 98% (all by floor 2), reveal + adjust 85% (on floor 1, far off §12's "normal" target), honest adjuster 33%. For block 15.

### Block 15 — Full-run tuning
- [x] Done
- **Goal:** meet every simulation target in spec §12.
- **Exit:** clearance rates, surplus impact, and run-heat budget on target; each archetype bot viable.
- **Tests:** the harness report, including the known-risk checks (Whale at High or Low, Forged Papers + Luminous Ink, etc.). Config changes only.
- **Status:** paused after eight PRs; difficulty (block 18) came first, then block 19 finished this block's targets per difficulty and ticked it.
- **Harness built (PRs 1–6):**
  - Bots stand up when table heat reaches their nerve, drawn per player between 35 and 85 and moved ±5 each session (`sim/bots/nerve.gd`); reckless and side-bet bots sit until backed off.
  - Runs press on to 150% of quota before cashing out (reckless: 100%; `--cash-out=N`).
  - Each bot starts a run with the starting kit plus only the unlock items its policy uses, in its slots, and buys a wishlist at shops (`sim/run_plan.gd`). Floor mode still gives every unlock.
  - Archetype bots: Reader, Whale, Marker (blackjack only), Mechanic, Stacker (blackjack only); `stacker_greedy` (opt-in) nudges into Perfect Pairs every hand.
  - "Good" bots (Reader, Whale, Mechanic) skip low-stakes tables they can afford to rise above; the Reader raises only on a 0.25 edge; the Stacker nudges only for at most 100 heat.
  - The run report splits losses (short, broke, ejected) and shows the share reaching floors 2 and 3.
- **Changes (PRs 7–8):**
  - In a run, the map (one table per node) and table heat ended a floor long before its 60-hand clock. Map rows 6 → 10; tier thresholds 30 / 60 / 90 → 45 / 90 / 135 (§7.1, the Marked consequence at 90, §7.2); stand-up rollover 20% → 10% and Comped Suite 12% → 6% (§7.3, §9). A back-off now always reaches the 50 run-heat session cap.
  - Nudging into Perfect Pairs every hand won 61.5% of runs. The side-bet repeat now counts side-bet manipulations in earlier hands on the floor, at any table (§8; save version 6), and the Nudge's side-bet factor is 0.15 (was 0.075). Side-bet payouts moved toward the top of the 5–15% band: Perfect Pairs 9:1 / 23:1 (13.7%), 21+3 flush 5:1 (12.8%), Bust It five cards 7:1 (12.4%), Dragon Bonus margin 8 at 8:1 (Player 9.0%, Banker 14.8%).
- **Result (run mode, 400 runs, default config; won / reached floor 2 / reached floor 3 / ejected):**

  | Bot | Won | F2+ | F3+ | Ejected |
  |---|---|---|---|---|
  | Reader | 0% | 86% | 28% | 7% |
  | Whale | 1.8% | 66% | 30% | 0% |
  | Marker | 0% | 60% | 7% | 0% |
  | Mechanic | 1% | 88% | 48% | 2.5% |
  | Stacker | 4% | 72% | 40% | 0.2% |
  | Stacker greedy | 5% | 67% | 41% | 79.5% |

  - Run-heat targets met: reckless chaser 100% and manipulate-max 88% ejected by floor 2; reveal + adjust 20% ejected before floor 4 (on the limit); every good bot ≤ 7%.
  - Honest play (floor 1, high stakes): straight flat 3.5% / 1.4% / 0.2%. Bold clears 23–32% but finishes in 13–19 hands, not a whole clock.
  - Surplus (floor mode, floor 2 entered at 2× the floor 1 quota): blackjack clearance +20 points (Reader 28 → 50%), over the 10–15 target.
- **Open for block 19:**
  - Viability: only the Mechanic and the Stacker reach floor 3 in about 40% of runs; nobody wins more than 5%. At 3× growth instead of 5×, Reader, Whale, Mechanic and Stacker win 8–10% and reach floor 3 38–55%, but surplus impact rises to about +30 points. Hence block 18.
  - Strong surplus: 2× contradicts the 10–15 point target at any winnable growth. Define it as 1.5× or loosen the limit.
  - The Marker is weak at every setting (floor 3 in 4–13% of runs).
  - Most Stacker runs never remove a card (no money to spare early); left as is.
  - Known risks still to run: High Roller's Nerve + Whale; Forged Papers + Luminous Ink; deviation floor steps; taped and sealed composition at High or Low.
  - High or Low reads: a full reveal of the next card clears floor 1 for every reading bot whatever it costs; heat only adds ejection. Diluted in runs (a third of tables). A rule fix belongs to block 17.

### Block 17 — House rules and game modifiers
- [ ] Done
- **Goal:** house-rule variants as game modifiers: blackjack's bust threshold (e.g. 23), dealer rules, and the rule changes floor signatures make (spec §3.1, §5.3). Unscheduled; slot it in when the run structure needs it.
- **Exit:** a table or floor can change a game's house rules through config, and the side bets and the harness price against the rules in play.
- **Tests:** each modifier changes play as specified; side-bet edges stay in band under each modifier the game uses.
- **From block 19:** High or Low full reveals clear a floor at any price and need a rule; and the taped and sealed composition check at High or Low (spec §12 known risks) needs a bot that tapes and seals.

### Block 18 — Run difficulty
- [x] Done
- **Goal:** a run has a difficulty, Easy, Medium or Hard, that sets each floor's quota and stakes, the run price multiplier, and a small shift on the table cost rolls (spec §6.3, §6.4, §1.2). Answers the §6.3 `[OPEN]`: difficulty sets the growth per floor.
- **Decisions:** heat rules, action costs and tiers stay the same at every level: the player's sense of what an action costs carries over, and a harder run only asks for more heat-efficient play. Starting values: Easy 3× growth per floor, Medium 4×, Hard 5× (today's numbers); floor 1 the same at every level; run price ×1 and roll shift 0.0 at every level until block 19 tunes them. Medium is the default until the run-start screen (U4) offers the choice.
- **Plan (three PRs):**
  1. Config and core: `[difficulty]` (`levels`, `default`) and a section per level holding `quotas`, the four stakes lists, `run_price_pct` and `roll_shift`; the per-floor lists leave `[floors]` and `run_price_pct` leaves `[shop]`. `TuneConfig.for_difficulty(name)` returns a config with that level's values written into `[floors]` and `[shop]` and the roll shift added to every `[table_rolls]` range, so existing readers don't change. TuneSchema checks it.
  2. Run: `RunState.difficulty`; `Run.start(config, seed, kit, difficulty)` applies it; saves store it and re-apply it on load (save version 7).
  3. Harness `--difficulty=` for floor and run modes; a baseline report per level; spec §6.3 table per difficulty, §6.4 run multiplier.
- **As built:** levels are numbers so more can slot in later: Easy 0, Medium 2, Hard 4, `[difficulty] default=2`. A level may also set `start_bankroll`, `floor_price_pct` or `house_swap_chance` (none do yet). Harness overrides name the level (`--set=difficulty_2.quotas=[...]`); `--difficulty=N` works in every mode. Four stacked PRs (config overlay, config checks, run and save, harness).
- **Baseline (run mode, 400 runs, won / F2+ / F3+ / ejected):**

  | Bot | Easy (0) | Medium (2) | Hard (4) |
  |---|---|---|---|
  | Reader | 10% / 86% / 38% / 8% | 1.2% / 86% / 31% / 7.5% | 0% / 86% / 28% / 7% |
  | Whale | 8.2% / 66% / 39% / 0% | 4.5% / 66% / 33% / 0% | 1.8% / 66% / 30% / 0% |
  | Marker | 0% / 60% / 13% / 0% | 0% / 60% / 10% / 0% | 0% / 60% / 7% / 0% |
  | Mechanic | 8% / 88% / 55% / 8.8% | 3.5% / 88% / 51% / 6.2% | 1% / 88% / 48% / 2.5% |
  | Stacker | 9.8% / 72% / 44% / 1.2% | 6.5% / 72% / 42% / 0.5% | 4% / 72% / 40% / 0.2% |

  Hard reproduces block 15's table. Run-heat targets hold at every level (reckless 100% and manipulate-max 85–88% ejected by floor 2; reveal + adjust 20–21% before floor 4). Floor 1 is the same everywhere, so F2+ doesn't move.
- **Exit:** a run started at any level plays with that level's quotas, stakes and prices, and resumes at it.
- **Tests:** each level's values come through the overlay; the roll shift moves every range; unknown levels are refused by config and save; a run at Easy uses Easy's quotas on every floor; the difficulty survives save and resume.

### Block 19 — Full-run tuning per difficulty
- [x] Done
- **Goal:** finish block 15: meet spec §12 at each difficulty.
- **Decisions:**
  - Run-heat targets (reckless, normal, good) hold at every level; honest play and surplus impact are judged at Medium. Honest play is straight flat (a whole floor clock).
  - Viability binds at Easy: floor 1 ≥ 50%, floor 3 ≥ 40%, each archetype wins ≥ 5%. Medium and Hard set no floor: results fall as the level rises, and at least one archetype still wins at Hard.
  - The reader's ~70% is judged in runs at Easy as the Reader's pass rate on floors 2–5. Growth stays 3× / 4× / 5×: the win rates are reasonable for single-archetype bots with simple policies, and difficulty is adjusted later from real play.
  - Bankroll vs next floor's stakes (§6.3): left as is. A player builds up through smaller bets; no stipend, no ratio change.
  - The Marker is not a standalone archetype (§10): marks supplement any build. The marks-only bot stays in the report with no target. Checked instead: a Reader that also marks does no worse than the Reader. Its stand-up test was tried against heat above the floor and changed nothing (floor 3 in 12.5% of runs at Easy, from 13%).
  - Strong surplus: 1.5× the previous quota with the 10–15 point limit.
  - Levers, in order: each level's quotas and stakes for floors 2–5, `run_price_pct`, `roll_shift` (Hard). Heat rules change only if reveal + adjust is over 20% ejected before floor 4 at 2,000 runs.
- **Plan (four PRs):** decisions and spec; run report pass rate per floor; `reader_marks` bot; results and known-risk checks (no config value changed, so tuning and results are one PR).
- **Harness (PRs 2–3):**
  - The run report shows each floor's pass rate among the runs that entered it.
  - The Reader never reads into a back-off: when a read plus the largest raise would reach Backed off, it plays the hand honestly and stands up. Before, two High or Low hands with a full reveal and a raise came to 134 heat at average rolls, a point under the back-off, and any high roll or heat floor tipped it into the 50 run-heat cap. Reader ejections fell from 7–9% to under 1% and its wins at Easy rose from 10.5% to 15.5%.
  - `reader_marks` (opt-in): the Reader, also making one mark a blackjack session on a face-up ten or ace while it costs at most 4 heat. It skips the question when the marks already answer it and ignores them on a house deck. Run mode, 1,000 runs, won / F3+ / ejected:

	| Level | Reader | Reader + marks |
	|---|---|---|
	| Easy | 15.5% / 48.7% / 0.8% | 15.2% / 48.7% / 5.1% |
	| Medium | 3.2% / 40.2% / 0.1% | 2.9% / 40.2% / 6.0% |
	| Hard | 0.3% / 37.5% / 0.1% | 0.2% / 38.2% / 6.7% |

	Marks leave the Reader's wins and floor 3 rate where they were and cost about 5 points of ejection, inside the good target (≤ 10%): the add-on check passes as §12 words it, with no gain shown. The ejections are not back-offs. In the runs traced, a Reader that survives to floors 3–4 banks 7–10 run heat a session and sheds 15–20 a floor, so run heat climbs toward 100 and a mark's few points of heat a session tip the longest runs over. A cap on marks held (3 to 20) changed nothing. For the tuning PR: the good target holds with little room in long runs.
  - Block 15's exit ("each archetype bot viable") now reads as the four archetypes; the marks-only bot is a reference.
- **Result (run mode, 1,000 runs, default config; won / F2+ / F3+ / ejected):**

  | Bot | Easy (0) | Medium (2) | Hard (4) |
  |---|---|---|---|
  | Reader | 15.5% / 89% / 49% / 0.8% | 3.2% / 89% / 40% / 0.1% | 0.3% / 89% / 38% / 0.1% |
  | Whale | 9.0% / 65% / 37% / 0.1% | 4.8% / 65% / 32% / 0% | 2.0% / 65% / 28% / 0% |
  | Mechanic | 6.4% / 88% / 54% / 7.8% | 3.1% / 88% / 49% / 4.8% | 0.9% / 88% / 45% / 2.6% |
  | Stacker | 9.7% / 72% / 43% / 1.3% | 5.3% / 72% / 42% / 1.1% | 3.8% / 72% / 39% / 0.6% |
  | Marks only | 0% / 61% / 11% / 0.2% | 0% / 61% / 8% / 0.1% | 0% / 61% / 7% / 0% |

  - Reader pass rate on floors 2–5: Easy 55 / 61 / 71 / 74%, Medium 45 / 39 / 37 / 55%, Hard 42 / 28 / 13 / 21%.
  - Run heat: reckless chaser 100% and manipulate-max 86–88% ejected by floor 2; reveal + adjust 20.0% / 19.6% / 19.5% ejected before floor 4 (3,000 runs; on the limit); every archetype ≤ 7.8%.
  - Honest play (floor 1, high stakes, 2,000 floors): straight flat 3.5% / 1.1% / 0.4%.
  - Surplus (floor mode, Medium, floor 2, blackjack; entering at 1× / 1.5× / 2× the floor 1 quota): Reader 36 / 49 / 63%, Whale 32 / 45 / 57%, Mechanic 44 / 57 / 68%, Stacker 62 / 78 / 86%. 1.5× adds 13–15 points.
  - Growth sweep at Medium (Reader won; pass rate floors 2–5): 3× 15.5%, 55 / 61 / 71 / 74%; 2.5× 18.7%, 59 / 67 / 70 / 77%; 2× 25.8%, 64 / 76 / 79 / 75%. At 2.5× a 1.5× surplus adds about 22 points, so ~70% a floor and the surplus limit can't both hold at one growth.
- **Known-risk checks (run mode, 1,000 runs):**
  - High Roller's Nerve + Whale: owned from the start it lifts the Whale's wins from 9.0% to 24.9% at Easy and 4.8% to 16.6% at Medium, with no ejections. At a 15 / 10 / 5% bonus the Medium figure is 13.7 / 9.3 / 6.1%. Left at 20%; the strongest single item measured, to revisit with play data.
  - Forged Papers + Luminous Ink on the Reader with marks: 3.5% wins against 2.9% at Medium, ejected 6.2% against 6.0%. Not floor-free in any way that pays.
  - Deviation floor steps: the Stacker at 1 / 3 / 6 heat per removal wins 4.5 / 5.3 / 3.4% at Medium. The step barely matters, since most Stacker runs remove few cards.
  - High or Low full reveals: still clears floor mode every time (block 15); a rule fix for block 17.
  - Taped and sealed composition at High or Low: not run, since no bot tapes or seals. Moved to block 17, with the High or Low reveal rule.
- **Accepted as recorded:** the Whale reaches floor 3 in 37% of runs at Easy, against the 40% target. Bot win rates are a check on single-archetype play with simple policies; difficulty is adjusted from real play.
- **Exit:** every §12 target met at its level or accepted as recorded; the strong-surplus definition settled; marks pay as an add-on; the known-risk checks run or moved to block 17 (see block 15, "Open for block 19"). Ticks block 15 too.
- **Tests:** the harness report at each level. Config changes only, apart from the report columns and the `reader_marks` bot.

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
