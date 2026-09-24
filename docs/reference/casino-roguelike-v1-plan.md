# Casino Roguelike — V1 Design Plan

**Working pitch:** A roguelike where you climb a casino tower, clearing a cash quota on every floor. The house edge is real, so honest play loses. You have to cheat — and every time you do, someone notices.

*Revision 3. Scoped to card games. One shoe for the whole run. Adds marking, partial reveal, transform, side bets, and table spread.*

---

## 1. Core loop

**The run**

```
Enter floor  →  Play table sessions  →  Hit quota  →  Choose: cash out or press on
     ↑                                                          ↓
     └──────────────  Pay quota as buy-in, ride up  ←───────────┘
```

**The round** — identical in every game

```
Stake  →  Window?  →  Adjust  →  Window?  →  Adjust  →  Resolve
```

A **window** is an optional action on a hidden card: reveal it, partially reveal it, mark it, or transform it. All cost heat. **Adjust** is increase stake / decrease stake / insurance / no action. Doing nothing is always available and always free.

Games differ only in **how many windows they offer**, which follows naturally from how many cards they deal.

---

## 2. The four pillars

Everything else is content. If these are wrong, nothing else saves the game.

### 2.1 Money is score and currency

One number. The floor quota is the **buy-in for the elevator to the next floor** — you hand it to the house. Everything above it is your spending money.

- Buying a $200 item is a real sacrifice, not a side transaction.
- Playing past quota is the *only* way to afford upgrades.
- The floor gets a push-your-luck arc with no extra systems.

**Risk:** punishing, and Balatro deliberately avoids it. Hardest thing to retrofit. Test it in week one.

### 2.2 The house always wins

**Every table has negative expected value.** Grind twenty hands straight and you are down money. Quotas are set so that straight play cannot clear them.

Without this, playing straight is free *and* sufficient, no player ever opens a window, and the entire heat economy sits unused. With it, heat becomes **mandatory spending**, and the question is never "should I cheat" but *how many dollars am I extracting per point of heat.*

**Tuning rule:** quota gap ÷ average bet = net units you must win outright. Set it high enough that variance alone rarely covers it.

*Floor 1 worked example:* start $500, quota $800, gap $300. At a $50 average bet that's +6 net units. Over ~25 rounds at −4% edge you expect roughly −$50, so variance must produce a ~$350 swing. Possible, rare. That's the target feel.

### 2.3 Heat is the only resource

One meter, two tiers.

**Table heat** accumulates within a session:

| Table heat | Effect |
|---|---|
| 0–30 | Clean |
| 30–60 | **Watched.** Windows cost 50% more |
| 60–90 | **Marked.** Dealer swaps, windows cost double |
| 90+ | **Backed off.** Forced to leave immediately |

**Run heat** is the long arc:

| Run heat | Effect |
|---|---|
| 40 | Pit boss takes an interest — he begins appearing on floors |
| 70 | **Security sweep.** One item confiscated at random |
| 100 | **Ejected.** Run over |

**Rollover, and the asymmetry that matters:**

- Stand up voluntarily → **50%** of table heat converts to run heat.
- Get backed off at 90 → **100%** converts.

**Cooling.** A round played completely straight — no windows, no adjusts — cools the table by 5. It costs real money, because a straight round is a negative-EV round willingly accepted. The result is a sawtooth: cheat hard, lay low, cheat hard again, stand up before 90.

*Note the counterweight in §3: marking rewards staying, rollover rewards leaving. Both forces must be live or leave-timing is a countdown rather than a decision.*

### 2.4 Information costs exposure

Windows are optional, escalating, and priced by what they give you. Adjusts are priced by how conspicuous they are.

Bet spread is how real card counters get caught — not by the counting, but by correlating wagers with knowledge. The mechanic is historically accurate, which is a good sign it'll feel intuitive.

---

## 3. The shoe

**You own one shoe. It is carried for the whole run. Every game deals from it.**

This is the single most important consequence of scoping to card games. There is no per-game noun anymore — no wheel, no reels, no dice. Remove the low cards and it helps in blackjack *and* baccarat *and* high-or-low. Your deck is your build in the Slay the Spire sense.

**Starting shoe:** standard 52. **Minimum size:** 20 (below this the games break).

**Shoe size is a strategic dial.** A marked card only pays off when it cycles back around. Cut from 52 to 30 and marks return nearly twice as fast. "Remove a card" is simultaneously a quality upgrade and a mark-velocity upgrade — one decision, two payoffs.

### Shoe services — at shops, money only, no heat

| Service | Cost |
|---|---|
| Remove a card | $120, +$40 each subsequent removal this run |
| Add a specific card | $150 |
| **Reforge** — permanently rewrite one card into another | $200 |

Escalating removal cost is what stops players cutting to a 20-card shoe on floor one.

---

## 4. Actions — the two menus

Players do **not** start with everything. They start with one rung from each family and acquire the rest as discrete item unlocks.

**Starting kit: Partial reveal and Nudge.** One knowledge action, one manipulator action, both at the bottom. Together they teach the two cost profiles immediately — information is cheap, manipulation is expensive. No tutorial required.

### The critical rule: sidegrades, not tiers

**Full reveal must never strictly supersede partial reveal**, or you built a mechanic and threw it away. Higher rungs cost more heat. At 70 table heat, partial reveal is the only thing you can afford. The ladder is a **menu that grows**, not a power level that rises.

### Knowledge menu

| Action | Heat | Effect | Unlocked by |
|---|---|---|---|
| **Partial reveal** | 3 | Ask one yes/no question from the game's list | *start* |
| **Mark** | 4, +4 per mark this session | That card is identified to you free, forever, whenever it enters play | Wax Pencil |
| **Full reveal** | 6 | See the whole card | Shaded Lenses |
| **Look ahead** | 10 | See the next two cards in the shoe | Mirror Ring |

Marks reset when you stand up (dealer changes, cards get swapped). The escalating cost stops you marking everything — third mark in a session costs 12.

**Partial reveal questions are game-specific,** which lets the same mechanic be worth different amounts in different games with no new rules:

| Game | Questions |
|---|---|
| Blackjack | Does this bust me? · Is it a ten-card? · Red or black? |
| Baccarat | High or low? · Is it a face card? |
| High or Low | Is it within three ranks? · Red or black? |

### Manipulator menu

| Action | Heat | Effect | Unlocked by |
|---|---|---|---|
| **Nudge** | 10 | Shift a card ±1 rank. This hand only | *start* |
| **Recolour** | 8 | Change its suit. This hand only | Dyed Thumb |
| **Switch** | 16 | Swap two cards in play. This hand only | Mechanic's Grip |
| **Palm** | 22, once per session | Becomes any card. **Permanent — the shoe keeps the change** | Cold Deck |

Recolour unlocking *later* but costing *less* than Nudge is the sidegrade principle working. Palm being the only permanent one is what justifies its price.

### They compose

Mark a card. Later, Palm it into an Ace. You now own a permanently tracked Ace that announces itself every time it cycles. Two mechanics, one combo — exactly the kind of thing players should discover rather than be told.

---

## 5. Bets

### 5.1 Table minimum and maximum

Both do more work than they appear to, because they interact with rules already written.

**The minimum is the price of cooling.** Cooling requires a straight round, and a straight round still requires a bet at the table minimum, at negative EV. At a $25 minimum, cooling 5 heat costs about $1. At a $500 minimum, the same 5 heat costs $20.

**High-limit tables are heat traps.** You cannot afford to lay low, so heat only ratchets. Emergent, not designed.

**The maximum is the value of information.** Reveal the hole card at a $50–$100 table and that knowledge is worth $50. At a $50–$1,000 table it's worth $950. The maximum sets the ceiling on what any window can earn you — which means Counters want high-max tables, and high-max tables usually carry high minimums where cooling is ruinous.

### 5.2 Spread is the dial — table types

The *ratio* matters more than the absolute numbers. Make it a table attribute and you get variety within a floor, not just across floors.

| Type | Example range | Plays like |
|---|---|---|
| **Wide** | $25–$1,000 | Cheap cooling, huge press potential. Counter's paradise — compensate with higher base heat or a worse edge |
| **Narrow high** | $500–$1,000 | Cooling is ruinous, pressing barely helps. Pure nerve |
| **Narrow low** | $25–$100 | Cheap everything, low ceiling. Where you go at 70 heat |

### 5.3 Adjust heat scales with the swing

Replaces the old flat rate. More accurate to how bet spread actually gets people caught, and it turns the table maximum from a cap into a heat cliff.

| Swing | Heat |
|---|---|
| Up to 2× your current bet | 6 |
| 2×–4× | 12 |
| Beyond 4× | 24 |

Applies equally to increases and decreases. Insurance is exempt — it costs money plus 2 heat.

### 5.4 Side bets — escape velocity

**These solve a problem the economy has.** With negative EV and roughly even-money main bets, information can only ever recover a little ground; knowing the hole card is worth about 1× your bet. You cannot grind from $500 to $6,500 that way. Side bets paying 10:1, 25:1, 100:1 are what make the late floors mathematically reachable.

**Rules:**

- Placed at the **stake window only**, before any card is seen.
- **Zero heat.** The casino *wants* you taking them — they're advertised, and they carry 5–15% house edge against the main game's 1–4%. A trap for the naive player, a weapon for the prepared one, and suspicious to nobody.
- **Cannot be adjusted.** Blind commitment.
- **Capped at 25% of table maximum,** or a stacked shoe turns into side-bet-only degenerate play and the main game goes vestigial.

**This creates a clean split in what your two knowledge layers are for:**

- **Windows** → drive your main bet. In-hand, tactical, costs heat.
- **Shoe knowledge** → drives your side bet. Built over the run, free, pays huge.

Stack your shoe with pairs and Perfect Pairs stops being a sucker bet. That's deckbuilding converting directly into money, which is the payoff a shoe-crafting layer needs. **Marking bridges the two** — know a marked card is coming and you can time a side bet around it.

| Game | Side bet | Pays |
|---|---|---|
| Blackjack | Perfect Pairs | 6:1 / 12:1 same colour / 25:1 exact |
| | 21+3 — your two plus dealer's up card | 5:1 to 100:1 |
| | Bust It — dealer busts | 3:1 to 50:1 by card count |
| Baccarat | Dragon Bonus — win by a wide margin | up to 30:1 |
| | Perfect Pair | 25:1 |
| High or Low | Call the exact rank | 12:1 |

Side bets also fix the emptiest decision point in the round: the stake window was previously just "set your bet."

---

## 6. The games

Three for V1, chosen to span the window spectrum rather than to be a nice list.

### 6.1 Blackjack — 3 to 5 windows

The long game. High heat ceiling, high money ceiling. Where you go when you're clean and behind on quota.

| Step | What happens |
|---|---|
| Stake | Main bet + side bets |
| Deal | Your two up, dealer one up one down |
| **Window 1** | Act on the hole card |
| Adjust 1 | |
| Play | Hit / stand / split / double, all free. **Before each hit, a window** on the incoming card, then an adjust |
| **Final window** | After you stand, before the dealer plays |
| Resolve | |

House rules: bust threshold moves to 23 · blackjack pays 6:5 · dealer hits soft 17 · splits act as extra lives.

### 6.2 High or Low — 1 window per call

The short game. Minimal exposure per decision. **This is where you go at 70 table heat** — one window of temptation instead of five.

One card up. Call higher or lower on the face-down card. One window before you commit.

**The chain is what saves it from being a coin flip.** Call correctly and you may let it ride, using the new card as the base:

| Correct calls | Multiplier |
|---|---|
| 1 | 1× |
| 2 | 2.5× |
| 3 | 5× |
| 4+ | 10× |

Bank at any point. Miss once and you lose the whole chain. Each continuation is a new window, so heat cost scales with greed — but only one decision at a time.

### 6.3 Baccarat — 2 to 3 windows

**The most important game in the build, and the cheapest to implement.**

Baccarat in reality is the purest zero-agency game in the casino: fixed draw rules, nothing whatsoever to decide. Every scrap of agency here comes from your window ladder. **If the ladder makes baccarat tense, the design works anywhere.** It is the single strongest test you can run.

| Step | What happens |
|---|---|
| Stake | Player / Banker / Tie + side bets |
| Deal | Two cards each side, in sequence |
| **Window 1** | Act on either side's second card |
| Adjust 1 | |
| Draw | Third card per fixed rules |
| **Window 2** | Act on the third card before it lands |
| Adjust 2 | |
| Resolve | |

### 6.4 Deferred

**Poker vs dealer** is the first addition after V1 — the richest fit for partial reveal, since suit questions finally matter. Held back only because hand evaluation is real implementation cost. Three Card Brag, Red Dog, and Casino War after that; all are cheap variations on structures already built.

---

## 7. Run structure

### 7.1 The tower

Five floors. Each has an identity — a game pool, a house rule modifier, table types available, and a quota. At each elevator the player **chooses between two floors going up.** Shops stock weighted toward that floor's games, so routing is how you assemble a build.

### 7.2 Nodes

Three to five stops before quota is realistically reachable.

**Table node** — offers **two or three specific tables**, each with a game, a spread type, and a modifier. Always agency, rarely full freedom.

**Back room node** — shop, shoe services, or event.

### 7.3 Anti-spam is now intrinsic

No penalty rule needed. Game length *is* a heat budget: short games have low heat ceilings because they have few windows. At 70 table heat, blackjack is a trap you can't afford and High-or-Low is where you go. That's a tactical reason to switch driven by your own state, which is far better than a tax. *The "hot table" carrot from revision 2 is cut as redundant.*

### 7.4 The quota gate

A condition that flips mid-floor. Once quota is met, every subsequent table is optional:

- **Cash out.** Leave with the quota exactly. Clears 30 run heat. No shop money.
- **Press on.** Keep earning. Run heat climbs, pit boss circles.

---

## 8. Items

22 for V1: 6 unlocks, 16 modifiers. Everything is cross-game now — the verb/noun split from revision 2 is obsolete, because there is only one noun and every game shares it.

### 8.1 Unlocks — rare, discrete, memorable

Specific items grant specific rungs. "I found a wax pencil, now I can mark cards" is a far stronger beat than crossing a numeric threshold, and rarity tiers control pacing just as well.

| Item | Grants |
|---|---|
| Wax Pencil | Mark |
| Shaded Lenses | Full reveal |
| Mirror Ring | Look ahead |
| Dyed Thumb | Recolour |
| Mechanic's Grip | Switch |
| Cold Deck | Palm |

### 8.2 Cool — heat efficiency

| Item | Effect |
|---|---|
| Poker Face | Your first window each round is free |
| House Regular | Cooling rounds cool 8 instead of 5 |
| Comped Suite | Standing up voluntarily rolls over 30% instead of 50% |
| Quiet Hands | Bet decreases cost half heat |

### 8.3 Read — information quality

| Item | Effect |
|---|---|
| Loaded Question | Partial reveals ask two questions instead of one |
| Long Memory | Marks persist when you stand up |
| Deep Read | Second-window actions cost the same as first-window |
| Full Set | While 4+ marked cards are in the shoe, all windows cost half |

### 8.4 Craft — shoe and transform

| Item | Effect |
|---|---|
| Permanent Ink | Nudge and Recolour persist for the run instead of the hand |
| Sleight | Nudge costs 6 instead of 10 |
| Second Deck | Shoe removals cost a flat $80 with no escalation |
| Signature | Marked cards pay +25% when they land in your hand |

### 8.5 Play — bets and payouts

| Item | Effect |
|---|---|
| High Roller's Nerve | Bets above the table midpoint pay +20% |
| Card Counter's Purse | Side bet cap raised to 50% of table maximum |
| Comp Slip | Your first stake each session is refunded if you lose |
| Late Call | One extra adjust window after the final window. 12 heat to use |

---

## 9. Archetypes

Each is a different *shape on the heat curve*, which is a tighter identity than a list of abilities.

| Archetype | Heat shape | Plays like | Anchors |
|---|---|---|---|
| **The Counter** | Low, efficient | Maximum information per point of heat. Wants wide-spread tables | Poker Face, Loaded Question, Shaded Lenses, Deep Read |
| **The Mechanic** | Steep spikes | Rewrites cards rather than reading them. Needs cooling to survive | Cold Deck, Permanent Ink, Sleight, House Regular |
| **The Whale** | Nearly flat | Bets enormous from round one and *never adjusts*. Bet changes cost heat, so not changing is the edge | High Roller's Nerve, Comp Slip, narrow-high tables |
| **The Grinder** | Shallow sawtooth | Many rounds, many cooling opportunities. Cheats a little constantly | House Regular, Quiet Hands, Comped Suite, narrow-low tables |
| **The Stacker** | Near zero | Builds the shoe, plays side bets, barely opens a window. Money comes from deck construction | Card Counter's Purse, Second Deck, Signature, shoe services |

The Whale falling out of the rule that bet *changes* cost heat was not designed in — it emerged. The Stacker is the newest and least tested; it exists only because side bets and the shared shoe exist, and it's the one most likely to be either broken or non-viable.

---

## 10. Starting numbers

Placeholders. Here so the first build is playable, not because they're right.

**Economy**

| | Quota | Typical spreads |
|---|---|---|
| Start | bankroll $500 | — |
| Floor 1 | $800 | $25–100 |
| Floor 2 | $1,400 | $25–400, $50–200 |
| Floor 3 | $2,400 | $50–800, $200–400 |
| Floor 4 | $4,000 | $100–1,500, $500–1,000 |
| Floor 5 (boss) | $6,500 | $200–3,000, $1,000–2,000 |

House edge −4% per round on main bets. Side bets 5–15%. Item prices: commons $80–150, uncommons $200–350, unlocks and rares $400–700.

**Heat**

| Source | Amount |
|---|---|
| Partial reveal | +3 |
| Mark | +4, escalating +4 per mark this session |
| Full reveal | +6 |
| Look ahead / Nudge | +10 |
| Recolour | +8 |
| Switch | +16 |
| Palm | +22 |
| Second window in a round | ×1.7 on the above |
| Adjust ≤2× | +6 |
| Adjust 2–4× | +12 |
| Adjust >4× | +24 |
| Insurance | money +2 |
| Side bet | 0 |
| Straight round | −5 table heat |
| Watched (30) / Marked (60) | Windows ×1.5 / ×2 |
| Stand up voluntarily | 50% of table heat → run heat |
| Backed off at 90 | 100% → run heat |
| Cash out early | −30 run heat |

---

## 11. V1 scope

**In:** blackjack, high-or-low, baccarat · one shoe with crafting services · the two action menus with 6 unlocks · side bets · table spread types · five floors with two-way elevator choice · table and run heat with rollover · negative EV economy · quota gate and cash-out · 22 items · one starting loadout.

**Explicitly out:** poker vs dealer and all other card games · multiple characters · meta-progression · boss dealers with unique mechanics (floor 5 gets a house rule, not a personality) · art beyond placeholder · loan sharks and events beyond a basic shop.

---

## 12. Build order

Each milestone must be playable and must answer its question before you proceed.

1. **Blackjack standalone.** Full window ladder, one shoe, partial reveal and nudge only, table heat, cooling. No run structure, no economy.
   *Question: is the window-and-adjust decision still interesting on the thirtieth hand with only two actions available?*

2. **The floor economy.** Quota, negative EV, table minimums and maximums, the quota gate, cash-out.
   *Question: does the house edge read as pressure or as punishment?* Riskiest pillar, most likely to need retuning.

3. **High-or-Low, Baccarat, and the 6 unlocks.**
   *Question: does baccarat become tense?* If the ladder can't rescue the most passive game in the casino, it won't rescue anything. Also: does partial reveal stay in use after full reveal unlocks, or did you build a tier ladder by accident?

4. **Side bets and shoe crafting.**
   *Question: can a player actually reach floor 5's quota now?* This is the milestone that proves the economy closes.

5. **The tower.** Five floors, elevator routing, floor identities, shop weighting, run heat carry.
   *Question: do the archetypes emerge, or does one dominate?*

6. **Tuning pass.** Numbers only. No new systems.

---

## 13. Open questions for playtest

- **How negative can the house edge be before it feels unfair rather than tense?** −4% is a guess and the number most likely to be wrong. Tune against quota gaps, not in isolation.
- **Is money-as-both too punishing?** Cannot be retrofitted cheaply.
- **Do marking and rollover actually balance?** Marking rewards staying, rollover rewards leaving. If either dominates, leave-timing stops being a decision. This is the newest tension in the design and the least tested.
- **Does a 100:1 side bet hit trivialise a floor?** A lucky spike clearing a quota is a good roguelike memory; happening often enough to make the grind feel pointless is not. Fix by lowering the cap, not the payout — the payout is where the fantasy lives.
- **Does cutting the shoe deep break the games?** 20 is a guessed floor. Blackjack may need more.
- **Are 6 unlocks enough to feel like progression?** Too few and the run feels static; too many and the starting kit feels crippled.
- **Is the Stacker viable, or broken?** It barely touches the heat system, which is either an elegant off-axis build or a hole in the design.
- **What happens at $0?** Run over, or a loan shark backstop? A backstop softens the roguelike but may be needed for the early game to feel fair.
