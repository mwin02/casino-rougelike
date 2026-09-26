# Casino Roguelike — Design Spec v4

**Status:** source of truth for implementation. Supersedes `casino-roguelike-v1-plan.md` (revision 3) wherever they conflict, and incorporates `prototype-findings.md`.

**Conventions in this file**
- `[TUNE]` marks a placeholder number that the simulation harness must set. Code should read these from a single config, never hard-code them.
- `[OPEN]` marks an unresolved question. Do not invent an answer in code; leave a clearly named hook.
- "Plan §x" refers to sections of the V1 plan that still apply unchanged.
- **Money is 100× the V1 plan's figures.** Dollar amounts in `docs/reference/` (plan, prototype findings) are at the old scale; multiply by 100. Heat values are unscaled.

---

## 0. Core objective

The player's goal is to **extract the most profit per point of heat**. The intended skill is using a little information to size big bets. Manipulation exists, but as an expensive rescue, not the main way to win.

Every table has negative expected value. Honest play should not clear quotas. Heat is the resource the player spends to beat the house.

### Summary of changes from the V1 plan

- The deck reshuffles every hand. No card counting.
- Heat = action base costs × a bet-change multiplier. Base costs are randomized per table and per game.
- Manipulation locks the bet for the rest of the hand.
- Manipulation changes last the hand. Consumables stretch a change to the table session or make it permanent; Permanent Ink gives a few permanent changes per floor. Reforging (shops, events) is the other way to change cards permanently.
- Deckbuilding and marks raise a per-session heat floor.
- Marks are player-assigned symbols that last the whole run.
- Two table types: low stakes (setup) and high stakes (payoff).
- Each floor has a hand clock. Quotas are thresholds and grow about 5× per floor.
- One marker (loan) per run prevents a single bad floor from ending the run.

---

## 1. Heat model

### 1.1 Formula

Heat for a hand is computed and applied at resolution:

```
hand_heat = (sum of base costs of actions used this hand) × m(r)
r         = max(final_bet / opening_bet, opening_bet / final_bet)
```

- `final_bet` is the bet at resolution. "Opening bet" is the stake placed at the stake window.
- A hand with no actions has zero base, so its heat is 0 regardless of bet changes. Honest bet changes (including blackjack doubles) are never penalized.
- `m(r)` is fixed for the whole run. `m(1) = 1`. Shape is `[TUNE]`; starting proposal: `m(1)=1, m(2)=1.5, m(3)=2`, linear between.
- `m` is symmetric: decreasing the bet by a ratio costs the same as increasing it by that ratio.
- The multiplier is never explained in-game. The player learns it through play.

### 1.2 Base costs

- Every action has a base cost per game (see §2.3 and §3).
- Each table rolls its own base costs within a bounded range around the center: ±30% `[TUNE]`.
- Rolls may be biased by table type or floor so they read as patterns. Required bias: high-stakes tables roll higher manipulation costs.

### 1.3 Adjust limits

- Bet changes are always measured against the **opening** bet, never the current bet.
- Raises: total bet ≤ 3× opening `[TUNE]` and ≤ table max.
- Decreases: total bet ≥ 0.5× opening `[TUNE]` and ≥ table min.
- Blackjack doubles and splits, baccarat side switching, and insurance all count as bet changes (§3).

### 1.4 Visibility

- Heat is **itemized**: each action's heat appears as its own line when it lands.
- The multiplier's effect appears as its own line at resolution.
- Cooling appears as its own line, e.g. `straight hand −6`.
- A table's rolled base costs are hidden. The Pit Ledger item reveals them (§9).
- The end-of-hand summary shows the hand's efficiency: `+$24,000 for 6 heat`.

### 1.5 Second window surcharge

A second window action in the same hand costs ×1.7 (plan §10). Deep Read removes this.

### 1.6 Cooling

A **straight hand** (no actions, no bet changes) cools the table:

```
cooling = table_heat × cool_rate × stake_factor(bet) × decay
```

- `cool_rate` = 10% `[TUNE]`.
- `stake_factor` rises with the absolute bet relative to the table's range `[TUNE]`. Min-bet cooling should be nearly worthless.
- `decay` halves on each consecutive straight hand (1, 0.5, 0.25, …) and resets to 1 after any non-straight hand.
- Cooling cannot take table heat below the table's heat floor (§4.2).

Intended properties: cooling is never free at low heat; min-bet cooling barely helps; the cheat-then-cool sawtooth still works because alternating hands resets the decay.

---

## 2. Actions

### 2.1 Roles

- **Knowledge** actions give information. Their value only turns into money through bet sizing or play decisions. They are cheap.
- **Manipulation** actions change cards and produce certainty. They are expensive, and they are a **rescue tool**.

### 2.2 Rescue rule

Any manipulation action **locks the bet** for the rest of the hand. After a manipulation, no adjusts, doubles, splits, side switches, or insurance. Manipulation saves a hand you are already committed to; it can never set up a raise **in that hand**.

A consumable can keep a changed card changed for later hands (§2.3). That shifts the deck those hands deal from, which a later hand's bet can exploit. This is intended: it is prepaid by the consumable and the manipulation's heat. Watch its size in simulation (§12).

### 2.3 Base cost centers (blackjack reference)

Other games scale these per §3. All `[TUNE]`.

| Action | Family | Base | Notes |
|---|---|---|---|
| Partial reveal | Knowledge | 2 | Ask one yes/no question from the game's list (plan §4) |
| Mark | Knowledge | 3, +3 per mark this session | Applies a symbol to a card in play (§4.3) |
| Full reveal | Knowledge | 4 | See the whole card |
| Look ahead | Knowledge | 7 | See the next two cards. **Current hand only** (deck reshuffles every hand) |
| Recolour | Manipulation | 10 | Change suit |
| Nudge | Manipulation | 12 | ±1 rank. **Does not wrap** (King cannot become Ace) |
| Switch | Manipulation | 20 | Swap two cards in play |
| Palm | Manipulation | 28, once per session | Card becomes any card |

**Duration of manipulation.** Every manipulation, Palm included, changes the card **for the current hand only**. When the hand ends the card reverts. It is not a deck edit and does not raise the heat floor. Marks stay on the physical card through any change.

- During the same hand, the player may spend a consumable on a change made that hand (§9, Consumables):
  - **Masking Tape:** the change lasts the rest of the table session, then reverts. Not a deck edit. A taped card shows a strip of masking tape over it whenever it's on screen, so the player can see what's temporary.
  - **Cold Seal:** the change becomes permanent, a deck edit at +1 floor (§4.2).
  - A Permanent Ink charge works like a Cold Seal (§9).
- Session changes stop working if the pit swaps in a house deck (§7.2).
- Switching two cards makes each card take the other's identity. Composition is unchanged, but any marks now sit on different ranks. One consumable or Ink charge on a Switch covers both cards. Sealed, it is two card changes, so two deck edits (+2 floor).
- A card carries at most one session change, with a hand change on top. When the hand ends, a hand change reverts to what the card read before it (so a taped Palm under a Nudge survives).

Full reveal costs about twice partial reveal. Per-table rolls will sometimes make partial reveal the better buy; that is intended (sidegrades, not tiers).

### 2.4 Starting kit

- Partial reveal
- Nudge
- Mark, with **2 symbols**

Everything else is unlocked by items (§9).

---

## 3. Games

### 3.1 Blackjack

- Windows: hole card, before each hit, and a final window after standing (plan §6.1).
  - Order: deal → hole-card window → adjust → play. A hit or a double opens a window on the incoming card, then an adjust, then the card is dealt. After the last hand stands: final window → dealer plays → resolve.
  - A player natural resolves at once, with no windows. If every player hand busts, the final window is skipped and the dealer doesn't play.
- **No peek.** The dealer's natural is found at resolution and beats every stake on the table, doubles included.
- **Doubles:** on any two-card hand. The stake doubles, the hand takes exactly one card, then stands.
- **Splits (extra lives):** a two-card pair of the same rank (K+Q does not split) splits into two hands, each with its own stake equal to the split hand's. Each hand takes its second card with no window, then plays and settles on its own; one busting doesn't end the round. Resplits up to 4 hands `[TUNE]`. Split aces play normally, doubling after a split is allowed, and a split ace plus a ten is 21, not a natural.
- **Insurance:** offered in the adjust after the hole-card window when the dealer's up card is an ace. Stake up to 50% of the opening bet `[TUNE]`; pays 2:1 `[TUNE]` if the dealer has a natural, otherwise lost.
- House rules (plan §6.1, amended): bust threshold 23 `[TUNE]`, blackjack pays 3:2 `[TUNE]`, dealer hits soft 17 `[TUNE]`, splits act as extra lives. Floor signatures change these (floor 3 lowers the payout to 6:5, §5.3).
- **Totals:** each ace counts 11 while the total stays under the bust threshold (so up to 22), otherwise 1. A+A is a soft 22.
- **Natural:** exactly two cards, an ace and a ten-value card (a two-card 21). It beats every other hand, including a 22. Natural against natural is a push.
- **Dealer:** stands on hard 17 or more and soft 18 or more `[TUNE]`. The stand point does not move with the bust threshold.
- **Doubles and splits are bet changes.** They feed the multiplier and count toward the 3× raise cap.
- **Insurance is a regular adjust** (no special +2 heat rule).
- After any manipulation, no doubling or splitting (§2.2).
- Side bets: Perfect Pairs, 21+3, Bust It (§8).

### 3.2 Baccarat

- **Three windows**: one after the initial deal, and one before each possible third card.
  - Order: deal (Player, Banker, Player, Banker; both second cards face down) → initial window → adjust → second cards turn over. A natural (a two-card 8 or 9 on either side) resolves at once. Otherwise, if the player draws: player-third window → adjust → card. Then, if the banker draws: banker-third window → adjust → card. Then resolve.
  - Each third-card window opens only when that side will draw, so a hand has 1–3 windows.
- **Third-card rules** are the standard fixed tableau: the player draws on 0–5; the banker draws on 0–5 if the player stood, otherwise by its total and the player's third card.
- **Switching sides** (Player ↔ Banker) is an adjust. For the multiplier it counts as the maximum possible bet change (`r` = 3). A Tie bet never switches, and nothing switches to Tie. Every switch is recorded, including a switch back.
- Bet options: Player, Banker, Tie.
- **Payouts:** Player 1:1; Banker 1:1 less a 5% commission `[TUNE]`; Tie 8:1 `[TUNE]`. A tie pushes Player and Banker bets.
- Side bets: Dragon Bonus, Perfect Pair (§8).

### 3.3 High or Low

- One card up; call higher or lower on the next. One window per call.
  - Order: deal one card up → window on the next card → adjust (first call only) → call → flip. A correct call then offers bank or continue; continuing opens the next call's window.
  - Any call is allowed, even one no remaining card can win ("higher" on a King); it loses unless a manipulated card wins it, and then it pays the per-call cap.
  - The chain banks itself when it reaches the chain cap or the deck runs out.
- **Aces are low.** Extremes are Ace and King.
- **Pricing:** each call pays true odds against the **actual remaining cards** (deck composition, minus cards already drawn this chain), less a house cut. Cut ≈ 7% `[TUNE]`.
  - "Deck composition" is the **owned deck**, permanent edits included. Temporary manipulation changes (§2.3), this hand's or taped, are not priced in, so a consumable can tilt the odds.
  - The cut is higher than the V1 prototype's 4% because half-loss ties return about 3 points of edge to the player.
- **Ties:** matching the previous card's rank loses **half** the stake. Mid-chain, a tie ends the chain and the player keeps half the current chain value.
- **Chain:** after a correct call the player may bank or continue. Draws within a chain are without replacement. The first card up counts as drawn.
- **The bet locks when the chain starts.** No adjusts during a chain.
- **Caps:** per-call payout ≤ 3× `[TUNE]`; total chain value ≤ 20× stake `[TUNE]`.
- **Floor:** a correct call never pays less than 1× `[TUNE]`. True odds less the cut dip below 1× when more than 93% of the remaining cards win ("higher" on an ace); floored, the call still carries the house edge through ties.
- The chain value rounds down to whole dollars after every call (§6.2).
- **Per-game base costs:** reveals at High or Low cost roughly 3–4× their blackjack base (3.5× to start) `[TUNE]`, so all three games land in the same dollars-per-heat band.
- Side bet: exact rank (§8).

### 3.4 Game balance target

At the same table stakes, dollars extracted per heat point should be within about **1.5×** across all three games. This is the acceptance test for per-game base costs.

### 3.5 Cards shown per hand

This affects how useful each game is for marking (§5.1):

| Game | Cards in play per hand |
|---|---|
| Baccarat | 4–6 |
| Blackjack | ~5 |
| High or Low | 1–2 per call |

---

## 4. The deck

### 4.1 Deck basics

- The player owns one deck for the whole run. Every game deals from it.
- **The deck reshuffles every hand.** Its composition matters; its order never does.
- Starting deck: standard 52. Minimum size: 20 `[TUNE]`.
- Deck services at shops (plan §3): remove a card, add a specific card, reforge a card, plus **clear marks**. Prices are a share of the current floor quota `[TUNE]`; removal cost escalates per removal this run.
- **Reforging** changes cards permanently outside of play; Cold Seal and Permanent Ink do it during a hand (§2.3, §9). It comes in three tiers, offered at shops and by events. Events may offer a tier cheaper or free.

| Tier | What the player does | Price |
|---|---|---|
| Rummage | Shown 5 random cards from the deck; makes a small change to one of them | ~3% of quota `[TUNE]` |
| Touch-up | Chooses any card and makes a small change | ~6% of quota `[TUNE]` |
| Full reforge | Chooses any card and turns it into any card | ~15% of quota `[TUNE]` |

  A **small change** is ±1 rank (no wrap) or a new suit `[TUNE]`. A reforged card keeps its mark.

### 4.2 Deviation heat floor

Deck changes create a permanent edge at zero heat, so they are priced in heat:

- Every table session starts at, and cannot cool below, a **heat floor** based on the deck's deviation from standard.
- Deviation is counted in **edits**, not computed edge:
  - Each removal or addition: +3 floor `[TUNE]`
  - Each reforge: +3 floor `[TUNE]`, a separate value for each tier (Rummage, Touch-up, Full reforge), all starting at 3
  - Each Cold Seal change: +1 floor `[TUNE]`
  - Each Permanent Ink change: +1 floor `[TUNE]`, a separate value from Cold Seal
  - Both are lower than a reforge, so making a change permanent doesn't feel like a punishment
  - Edits count cumulatively: removing a card and adding it back is two edits
  - Each marked card: +1 floor `[TUNE]` (Luminous Ink marks: +0.5)
- Forged Papers reduces the floor by 10 `[TUNE]`.
- Only table heat **above** the floor rolls over to run heat (§7.3).

### 4.3 Marks (symbols)

- The player owns a limited set of distinct **symbols**. Start with 2; items add more.
- Marking is a window action (base 3, +3 per mark this session) targeting a card in play.
- The player chooses which symbol to apply. The symbol's meaning is up to the player (e.g. symbol A on all four Aces means "an Ace").
- Marks **last the whole run** and are part of the deck.
- When a marked card enters play, its symbol is visible to the player.
- Any number of cards can carry a symbol. The heat floor is what limits how many are worth marking.
- Re-marking a card overwrites its old symbol.
- Marks can be removed at a shop (clear marks), which lowers the heat floor.
- Marks never affect side bets, because side bets are placed before any card is dealt.

### 4.4 Deck view

A deck screen (like Balatro's) shows every card in the deck, including edits and each card's symbol. It is the player's legend for their marks.

---

## 5. Tables and difficulty

### 5.1 Table types

Two types, both with a max-to-min ratio of about 4:1 `[TUNE]`.

| | Low stakes | High stakes |
|---|---|---|
| Role | **Setup**: marking, learning a table | **Payoff**: hitting the quota |
| Cooling | Cheap, but moves little heat | Moves real heat, costs real money |
| Value of a read | Low | High |
| Manipulation costs | Rolled lower | Rolled higher |
| Mark costs | Rolled lower | Normal |

- Clearing a quota at low stakes should be close to impossible. At high stakes, hard without reads and achievable with good ones.
- Setup's real cost is run heat (rollover) and a higher heat floor at later tables.
- Low stakes need some reward of their own so setup doesn't feel like chores: modest winnings, a chance to learn a table's costs, the Tell Reader item. `[OPEN]` whether more is needed after playtest.

### 5.2 Table offers

- A floor presents table nodes (2–3 tables each) and back-room nodes (shop, deck services, events), as in plan §7.2.
- A table offer shows: game, stakes type, and house rule. Its cost rolls are hidden.

### 5.3 Floors and difficulty

- Stakes and quotas rise every floor at the same rate (§6.3), keeping the quota-to-table-max ratio constant.
- Each floor also has a **signature pressure** that leans on one lever:

| Floor | Signature |
|---|---|
| 1 | Baseline, no signature |
| 2 | Watchful pit: heat bases rolled high |
| 3 | Stingy house: blackjack pays 6:5, High or Low cut raised |
| 4 | Short nights: smaller hand clock |
| 5 | `[OPEN]` boss floor: house rule, not a personality (plan §11) |

- At each elevator the player chooses between **two floor options**, each with its own signature. Which pressure suits the build is the routing decision.
- Levers available for signatures: heat scaling, payout scaling, quota scaling, clock size.

---

## 6. Pacing, quotas and economy

### 6.1 The floor clock

- Each floor has a pool of **hands** (floor 1: 60 `[TUNE]`), spent across any tables.
- One hand costs one clock tick at any table, low or high stakes.
- Back-room stops (shops, services, events) cost no hands.
- Leaving a table (standing up or being backed off) loses nothing extra; hands already played are spent.
- Items and surplus can adjust the clock (§6.4, §9).

### 6.2 Quotas are thresholds

- The quota is an amount the bankroll must **reach** before the clock runs out. It is not paid.
- The player keeps their whole bankroll going into the next floor.
- Money is one number: score, currency, and cushion.
- Money is whole dollars. Any fractional result (odds payouts, quota-share prices, interest) rounds **down**, in the house's favour, through one rounding function. At these stakes the fraction never matters.
- Spending money mid-floor (e.g. a shop before reaching the quota) is a real sacrifice.

### 6.3 Scaling

Quotas grow about **5× per floor** `[TUNE]`, so no realistic surplus solves the next floor. Stakes scale by the same factor.

| Floor | Quota | Low stakes | High stakes |
|---|---|---|---|
| Start | bankroll $50,000 | | |
| 1 | $140,000 | $1,000–4,000 | $5,000–20,000 |
| 2 | $700,000 | $5,000–20,000 | $25,000–100,000 |
| 3 | $3,500,000 | $25,000–100,000 | $125,000–500,000 |
| 4 | $17,500,000 | $125,000–500,000 | $625,000–2,500,000 |
| 5 | $87,500,000 | $625,000–2,500,000 | $3,125,000–12,500,000 |

All values `[TUNE]`. Config lists each floor's quota and stakes explicitly, so each floor tunes on its own. The 5× growth and the 4:1 max-to-min ratio (§5.1) are the targets those lists follow, not config values. Worked example: a player who hits exactly the floor 1 quota enters floor 2 with $140,000, facing a $560,000 gap. A player who hits 2× (and keeps it) enters with $280,000, facing a $420,000 gap: 25% less, not solved.

`[OPEN]` **Bankroll vs next floor's stakes.** A player entering floor 2 with $140,000 has barely more than one max bet at the $100,000 high-stakes max. This may be fine (start each floor at low stakes, which fits setup-then-payoff) or too fragile. Fallback levers: raise the quota-to-max ratio, or add a small house stipend at each elevator. Decide from simulation.

### 6.4 Surplus

Money above the quota can be used for:

- **Items**, bounded by **6 item slots**
- **Extra hands** for the next floor's clock, capped at +10 per floor `[TUNE]`
- **Deck services**
- **Cushion**: simply keeping it as bankroll against bad luck

Prices are a share of the current floor's quota so they scale automatically: common ~5%, uncommon ~10%, rare ~18% `[TUNE]`.

### 6.5 Quota gate

Once the quota is reached, the rest of the clock is optional:

- **Cash out:** stop playing. Each unused hand sheds 1 run heat `[TUNE]`.
- **Press on:** keep playing to build surplus, at the cost of more heat and pit boss exposure.

---

## 7. Heat consequences

### 7.1 Table heat tiers

| Table heat | Tier | Effect |
|---|---|---|
| 0–30 | Clean | — |
| 30–60 | Watched | Action costs ×1.5 |
| 60–90 | Marked | Action costs ×2, plus the Marked consequence (§7.2) |
| 90+ | Backed off | Forced to leave after the current hand. 100% of above-floor heat rolls over |

### 7.2 The Marked consequence

When a table first crosses 60 in a session, roll once for its consequence:

- **House deck swap:** the table switches to the casino's standard deck. The player's edits and marks stop working at this table for the rest of the session.
- **New dealer:** the table's base cost rolls are redrawn.

Rules:
- The player is only told that "something bad happens at 60." They learn the two outcomes through play.
- P(house deck swap) rises each floor `[TUNE]`: 20%, 35%, 50%, 65%, 80% on floors 1–5.
- The result is announced clearly when it happens, e.g. "The pit swaps in a house deck."
- The Pit Ledger item reveals a table's rolled consequence in advance.

### 7.3 Rollover

- Standing up voluntarily: 50% `[TUNE]` of table heat **above the heat floor** becomes run heat.
- Backed off: 100% of table heat above the floor becomes run heat.

### 7.4 Run heat

| Run heat | Effect |
|---|---|
| 40 | Pit boss appears (§7.5) |
| 70 | Security sweep (§7.6) |
| 100 | Ejected. Run over |

Run heat reduction:
- Each elevator ride sheds 15–20 run heat `[TUNE]`.
- Cashing out sheds 1 per unused hand (§6.5).
- Rollover and shed amounts must be tuned with the clock so a normal run doesn't hit 100 by floor 2.

### 7.5 Pit boss

- From run heat 40, the pit boss watches one table per floor. That table is visibly marked.
- On a watched table, tier thresholds are lower: Watched applies from 0 heat `[TUNE]`.
- As run heat rises, he watches more tables `[TUNE]`.

### 7.6 Security sweep

At run heat 70, the player **chooses** what to lose: one item, or every mark of one symbol.

---

## 8. Side bets

- Placed at the stake window only, before any card is dealt.
- Zero heat. Cannot be adjusted.
- Capped at 25% of table max (50% with Side Pocket).
- Marks never affect them. Deck composition does (this is the Stacker's niche, priced by the heat floor).
- **Must be repriced for a single 52-card deck** (prototype findings §5). Starting points:

| Game | Side bet | Repricing starting point |
|---|---|---|
| Blackjack | Perfect Pairs | Drop the impossible "perfect" tier; pay 10:1 mixed / 24:1 coloured (~−8%) |
| Blackjack | 21+3 | Remove impossible suited-trips tier; retune to 5–15% edge |
| Blackjack | Bust It | 1:1 / 3:1 / 9:1 / 35:1 / 120:1 by dealer card count (~−10%) |
| Baccarat | Dragon Bonus | Up to 30:1; ~−3% currently, raise edge into 5–15% |
| Baccarat | Perfect Pair | Define as same rank only, or reprice as Perfect Pairs |
| High or Low | Exact rank | 11:1 (~−7.7%) |

Target edge 5–15% on a standard deck. Verify by exact enumeration in the test suite.

---

## 9. Items

- **6 item slots** `[TUNE]`. 26 items. All items are permanent passives in V1, except Permanent Ink, whose charges are spent during hands and refill each floor.
- Prices: share of current floor quota by rarity (§6.4).

### Unlocks and symbols

| Item | Rarity | Effect | Archetype |
|---|---|---|---|
| Shaded Lenses | Rare | Unlocks full reveal | Reader |
| Mirror Ring | Rare | Unlocks look ahead | Reader |
| Dyed Thumb | Uncommon | Unlocks Recolour | Mechanic |
| Mechanic's Grip | Rare | Unlocks Switch | Mechanic |
| Cold Deck | Rare | Unlocks Palm | Mechanic |
| Wax Pencil | Uncommon | +1 symbol | Marker |
| Grease Pencil | Uncommon | +1 symbol | Marker |
| Luminous Ink | Rare | +1 symbol; its marks add half as much to the heat floor | Marker |

### Heat

| Item | Rarity | Effect | Archetype |
|---|---|---|---|
| Poker Face | Uncommon | First window each hand is free | Reader |
| House Regular | Common | Cooling rate 15% instead of 10% | Mechanic |
| Comped Suite | Uncommon | Voluntary stand-up rolls over 30% instead of 50% | Any |
| Quiet Hands | Common | Bet decreases don't count toward the multiplier | Reader |

### Information

| Item | Rarity | Effect | Archetype |
|---|---|---|---|
| Loaded Question | Uncommon | Partial reveals answer two questions | Reader |
| Deep Read | Uncommon | No ×1.7 surcharge on a second window | Reader |
| Pit Ledger | Uncommon | On sitting down, reveals the table's cost rolls and its Marked consequence | Reader, Marker |
| Tell Reader | Common | Marking costs 1 less at low-stakes tables | Marker |

### Deck

| Item | Rarity | Effect | Archetype |
|---|---|---|---|
| Permanent Ink | Rare | 2 charges per floor `[TUNE]`. A charge makes a manipulation made this hand permanent, like a Cold Seal, with no heat surcharge. Each counts as a deck edit at +1 floor (§4.2). Unused charges don't carry over | Mechanic, Stacker |
| Sleight | Common | Nudge costs 40% less | Mechanic |
| Second Deck | Uncommon | Card removals cost a flat price, no escalation | Stacker |
| Signature | Uncommon | Marked cards pay +25% when they land in your hand | Marker |
| Forged Papers | Uncommon | Heat floor −10 | Stacker, Marker |

### Bets and clock

| Item | Rarity | Effect | Archetype |
|---|---|---|---|
| High Roller's Nerve | Uncommon | Bets above the table midpoint pay +20% | Whale |
| Side Pocket | Uncommon | Side bet cap 50% of table max | Stacker |
| Comp Slip | Common | First stake each session refunded if lost | Whale |
| Late Night | Rare | +5 hands on every floor | Any |
| Comped Breakfast | Uncommon | Up to 10 unused hands carry to the next floor | Reader |

### Consumables

Single-use. Bought at shops or found at events, and **held without limit**. Each is spent during a hand on a manipulation made that hand (§2.3).

| Consumable | Effect | Price |
|---|---|---|
| Masking Tape | The change lasts the rest of the table session; the card wears a strip of tape | ~3% of quota `[TUNE]` |
| Cold Seal | The change becomes permanent: a deck edit at +1 floor | ~8% of quota `[TUNE]` |

Removed from the V1 plan: Long Memory (marks now persist by default), Full Set (too strong with plentiful marks), Late Call (baccarat's third window covers it). Likely playtest cuts: Comp Slip or High Roller's Nerve.

---

## 10. Archetypes

Working hypotheses, to be refined by simulation bots and playtesting.

| Archetype | How it plays | Heat shape |
|---|---|---|
| **Reader** | Partial and full reveals, precise bet sizing, uses heat intel | Low and steady |
| **Marker** | Heavy setup at low stakes, many symbols, cashes in when marked cards show at high stakes | High floor, calm payoff |
| **Mechanic** | Rescues committed hands with manipulation, then cools | Sharp spikes |
| **Whale** | Opens big and never changes the bet (multiplier stays ×1); reads pay through play decisions | Flat |
| **Stacker** | Deck composition plus side bets, few windows | Almost entirely floor |

The Grinder from the V1 plan is dropped: weak min-bet cooling and the clock remove its niche.

---

## 11. End states

- **Win:** reach floor 5's quota.
- **Score:** final bankroll after floor 5. Also shown: overall dollars per heat for the run.
- **Marker (one per run):** if the clock runs out short of quota, or the bankroll can't cover the low-stakes minimum, the house fronts the shortfall, up to 50% of the quota `[TUNE]`. The loan plus interest `[TUNE]` is added to the next floor's quota.
- **Loss:** a second failure, failing on floor 5, or run heat reaching 100.
- Endless mode past floor 5 is out of scope for V1.

---

## 12. Simulation targets and checks

The simulation harness is the acceptance test for every `[TUNE]` value.

**Targets**
- Dollars per heat across the three games within ~1.5× at equal stakes (§3.4).
- Honest play spending a whole floor clock at high stakes clears the quota < 20% of the time.
- A competent reader with a sensible setup/payoff split clears ~70%.
- Carrying a strong surplus into a floor raises that floor's clearance by at most ~10–15 percentage points.
- A normal run does not reach 100 run heat before floor 4.
- Side bets land at 5–15% house edge on a standard deck, verified by exact enumeration.
- High or Low sits near the main-game edge (~−4%) after the tie rule and cut.

**Known risks to test first**
- Whale at High or Low: open big, reveal, call, with no bet change (×1 multiplier).
- High Roller's Nerve + Whale.
- Forged Papers + Luminous Ink making a Marker build nearly floor-free.
- Bankroll vs next floor's stakes (§6.3 `[OPEN]`).
- Deviation floor step sizes vs the value of each edit.
- Free raises on hands where marked cards show (by design, prepaid via the floor; verify magnitude).
- Taped and sealed manipulation shifting composition for later hands (§2.2), especially at High or Low, which prices against the owned deck (§3.3). Unlimited consumable holding.

**Bot policies to implement**
Straight flat bet; bold play; reveal-only; reveal + adjust; manipulate-max; High or Low greedy; min-bet cooler; one bot per archetype.

---

## 13. Scope

**In V1:** blackjack, baccarat, High or Low; one deck with services and symbol marks; both action menus with 5 action unlocks and 3 symbol items; heat model with per-table rolls and heat floor; two table types; five floors with signatures and two-way elevator choice; floor clock; quota thresholds and marker; side bets; 26 items with 6 slots; Masking Tape and Cold Seal consumables; one starting loadout.

**Out of V1 (unchanged from plan §11):** poker vs dealer and other games; multiple characters; meta-progression; boss dealers with unique mechanics; art beyond placeholder; loan sharks and events beyond a basic shop; consumables beyond Masking Tape and Cold Seal; endless mode.
