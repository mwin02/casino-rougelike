# Casino Roguelike — findings from the V1 session prototype

Notes from building and instrumenting `pit-sheet.html`, a single-table implementation of the round loop: three games, the eight window actions, swing-scaled adjusts, side bets, table heat with tiers and cooling. No items, floors, shop or run structure.

Everything below is measured, not estimated. Method: a random-agent fuzz across 150 sessions to shake out crashes, then Monte Carlo policy simulations at 1,500–2,500 sessions per data point, plus exact enumeration for the side bets. Numbers are for a $500 bankroll against the floor-1 quota of $800.

---

## 1. High or Low's chain table pays the player 44%

**Severity: fixed in the build, but the reasoning matters for anything similar.**

The 1× / 2.5× / 5× / 10× table in §6.2 assumes each call is close to a coin flip. It isn't. Calling "higher" on a deuce wins 85% of the time, and even money on that is enormously positive. Playing the obvious edge against the flat table returned **+44% per hand**. No quota tuning fixes this; the bet is simply mispriced.

The build instead prices each call at true odds against the nominal 52-card shoe, less a 4% cut: a correct call multiplies your stake by `(1 ÷ probability) × 0.96`, and a chain compounds those. Straight play now measures −1.3%, rising to −3.2% if you chase chains, and the greed decision survives intact — a three-call chain of safe calls is worth about 1.6×, three risky ones can be 40×.

Two side effects worth keeping:

- **Greed is priced by risk instead of by length**, which reads closer to the intent of §6.2 than the flat table did.
- Because the board prices against a *fresh* shoe but resolves against the *remaining* one, counting the shoe down is a real unassisted edge. That is the "shoe knowledge is free and pays huge" link from §5.4 falling out of the maths for nothing.

---

## 2. Information is priced per action but pays per game, and the spread is 20:1

**This is the biggest problem in the design as written.**

One full reveal per hand, $50 flat, narrow-low table, 12 hands, measured against the same policy playing straight:

| Game | What the reveal buys | Gain | Heat | **Dollars per heat point** |
|---|---|---|---|---|
| Baccarat (reveal only) | one hidden second card | $4 | 109 | **$0.04** |
| Blackjack | the hole card, played into | $23 | 90 | **$0.26** |
| Baccarat (reveal + adjust) | same card, plus a bet response | $57 | 113 | **$0.51** |
| High or Low | the card about to be flipped | $445 | 88 | **$5.07** |

High or Low returns ten to a hundred times more per point of heat than anything else. The cause is structural rather than a tuning slip: in High or Low a full reveal converts into *certainty*, and certainty pays at odds — up to 12× the stake — whereas in blackjack the hole card is worth a fraction of a unit of edge and in baccarat it barely moves the needle.

This inverts §7.3. The plan expects High or Low to be where you go *at 70 heat*, because it offers one window of temptation instead of five. In practice it is where you go *always*, at any heat, because its rate dominates. A player who understands this never opens a window at another table.

The plan's own anti-spam argument — "game length is a heat budget" — turns out to measure the wrong quantity. Blackjack's five windows are a heat *ceiling*, yes, but High or Low's single window has a far better heat *rate*, and rate is what a player optimises. If the games are meant to be genuine alternatives, the ladder needs to be priced per game, or High or Low's payout ceiling needs a cap (a maximum multiplier of about 3× would bring it into line), or its window has to resolve against a card other than the one being flipped.

---

## 3. Baccarat does become tense — but the adjust carries it, not the window

The strongest test in the plan (§6.2: "if the ladder makes baccarat tense, the design works anywhere") passes, with a caveat that changes where the design should spend its attention.

Revealing a hidden card in baccarat and doing nothing with it is worth **$0.04 per heat point** — statistically nothing. You have already committed to a side, so knowing you are ahead has no expression. Revealing and then *moving the bet* is worth **$0.51 per heat point**, a twelve-fold improvement, and it is the difference between a dead mechanic and a live one.

So the interesting decision in baccarat is not "do I look" but "how hard do I press once I have looked" — and the swing-scaled adjust in §5.3 is what prices that. Knowledge is a prerequisite; the adjust is the payoff. Worth noting because it suggests the adjust ladder deserves as much design attention as the window ladder, and it predicts that any game where you cannot respond to what you learn will feel flat no matter how good the reveal is.

---

## 4. Straight play clears floor 1 about half the time

**Pillar 2 does not currently hold, and the lever isn't the house edge.**

P(reaching $800 from $500 before running out), zero cheating, flat betting, blackjack:

| Flat bet | Net units needed | Quota cleared | Hands taken |
|---|---|---|---|
| $25 | 12.0 | **30.3%** | 235 |
| $50 | 6.0 | **50.0%** | 62 |
| $100 | 3.0 | **54.7%** | 16 |
| $200 | 1.5 | 48.0% | 4 |
| $400 | 0.8 | 47.7% | 1 |

This is gambler's ruin, and it is close to unfixable by tuning the edge. In a near-fair game, P(reaching a target with bold play) approaches bankroll ÷ target — $500/$800 is 62.5% before the edge takes its cut. Making the edge −8% instead of −4% moves these numbers by a few points; it does not change the shape.

What *does* change the shape is the number of hands the player is forced to play. At $25 flat the edge gets 235 hands to work and quota clearance falls to 30%. At $100 flat it gets 16 hands and clearance peaks at 55%.

The floor-1 numbers in §10 sit almost exactly on the worst point of that curve: a $300 gap against a $100 table maximum is 3 net units, which bold play covers by coin flip, for free, generating zero heat. **The heat economy is competing with a 55% coin toss that costs nothing.**

The tuning rule in §2.2 is the right rule, applied to the wrong denominator. It reads "quota gap ÷ average bet"; it should be **quota gap ÷ table maximum**, because the maximum is what the player will actually bet when behind. A ratio of 3 is a coin flip. A ratio of 12 gets you to 30%. Getting below 20% needs a ratio near 20 — floor 1 would want a $300 gap against a $25 maximum, or a much larger gap.

Conveniently, this is the same lever that fixes finding 2: raising gap ÷ maximum shrinks what any single revealed card can earn, since a window's value is capped by the table maximum (§5.1).

---

## 5. The side bets assume a multi-deck shoe. §3 specifies one 52-card shoe

Exact enumeration over a single deck. Three of the six are broken, and not subtly:

| Side bet | As specified | Actual edge on 52 cards |
|---|---|---|
| **Perfect Pairs** 6:1 / 12:1 / 25:1 | 25:1 tier needs same rank *and* same suit | **Impossible.** 0 of 1,326 hands. Bet is **−47.1%** |
| **Baccarat Perfect Pair** 25:1 | same | **Impossible.** 0 of 500,000 hands. **−100%** |
| **Bust It** 3:1 to 50:1 | 3-card bust dominates and pays 3:1 | **+62.1% to the player** |
| **21+3** 5:1 to 100:1 | suited trips also impossible | −18.2% |
| **Exact rank** 12:1 | 1 in 13 paying 13 back | **exactly 0.0%** |
| **Dragon Bonus** to 30:1 | — | −3.2% |

Only Dragon Bonus and 21+3 land anywhere near the 5–15% band §5.4 asks for, and 21+3 only by accident of losing its top tier.

The exact-rank bet is the one to watch. At 12:1 on a 13-rank deck it is a perfectly fair bet *before* information, which means **any** information at all makes it profitable — and §5.4 explicitly designs shoe knowledge to feed side bets. 11:1 puts it at −7.7%.

Suggested repricing for a single deck:

- **Perfect Pairs** — drop the perfect tier, pay 10:1 mixed / 24:1 coloured. Lands near −8%.
- **Baccarat Perfect Pair** — same problem, same fix, or define it as same rank only.
- **Bust It** — the dealer busts on 3 cards 17.3% of the time, on 4 cards 9.0%, 5 cards 1.8%, 6 cards 0.18%. A ladder of 1:1 / 3:1 / 10:1 / 40:1 / 150:1 is fair; shade it to 1:1 / 3:1 / 9:1 / 35:1 / 120:1 for about −10%.
- **Exact rank** — 11:1.

Alternatively, keep the payouts and make the starting shoe two decks. That has a cost though: it halves mark velocity, and §3 leans on shoe size as a strategic dial.

---

## 6. Cooling only keeps pace with the bottom rung of the knowledge menu

Rounds available from a clean table before being backed off at 90, one action per round, no cooling:

| Action | Clean (×1) | Watched (×1.5) | Marked (×2) | Total rounds |
|---|---|---|---|---|
| Partial reveal | 10 | 6 | 5 | **21** |
| Full reveal | 5 | 3 | 3 | **11** |
| Nudge | 3 | 2 | 2 | **7** |
| Switch | 2 | 1 | 1 | **4** |

Now the sawtooth from §2.3 — one action round alternating with one straight cooling round, net heat per pair of rounds:

| Action | Clean | Watched | Marked |
|---|---|---|---|
| Partial reveal | **−2** | 0 | +1 |
| Full reveal | +1 | +4 | +7 |
| Nudge | +5 | +10 | +15 |
| Switch | +11 | +19 | +27 |

The intended rhythm — "cheat hard, lay low, cheat hard again, stand up before 90" — only exists for partial reveal, and there it works too well: at a clean table it is **net negative**, so a player who only ever partial-reveals never accumulates heat at all. Their session is bounded by money, standing up costs them nothing, and the whole rollover tension in §2.3 never engages. That is the Grinder archetype discovering it can idle indefinitely.

Everything above the bottom rung outruns cooling by 1 to 27 per cycle, so for those players cooling isn't a rhythm, it's a rounding error — a straight round buys back a third of one Nudge. The asymmetry the plan wants (marking rewards staying, rollover rewards leaving) never gets to matter because the manipulator menu ends the session long before either force does.

Two directions: make cooling scale with the heat you are carrying (cool by 10% of table heat rather than a flat 5, so it stays relevant at high heat and stops being free at low heat), or put a floor under it so the bottom rung can't be net negative.

---

## 7. Smaller notes from implementation

- **Baccarat is a 3-window game, not 2.** Both sides can draw a third card, and each draw wants its own window (§6.3 lists one). The build offers a window before each. Worth confirming that's intended, since it moves baccarat's heat ceiling up by half.
- **High or Low locks the stake once a chain starts.** "Adjust the bet mid-round" and "the chain rides" are hard to reconcile — either the multiplier applies to a stake that changed mid-chain, or adjusts only happen before the first call. The build does the latter.
- **Nudge wraps.** King nudges up to Ace. This makes Nudge much stronger in blackjack (a King becomes an Ace) than the ±1 framing suggests. Non-wrapping is the more conservative choice.
- **Knowledge is per-round in the build, but the player's memory isn't.** Look Ahead sees two cards; if the round ends before both are dealt, the player carries genuine free information into the next round's stake window — where side bets are placed and cannot be adjusted. With the exact-rank bet at 0% edge this is a live exploit. The bridge §5.4 describes between marking and side bets works; it just needs the side bets to be priced for it.

---

## 8. What the build can now answer, and what it can't

Answerable from this prototype:

- **Does the ladder rescue baccarat?** Yes, via the adjust rather than the window.
- **Does partial reveal stay in use once full reveal exists?** Yes at high heat, for the reason §4 predicts — at 70 heat it is often the only affordable action. The sidegrade principle holds.
- **Is money-as-both too punishing?** Not yet visible; at one table with no shop there is nothing to spend on, so the sacrifice never bites.

Still out of reach without the run layer: whether the archetypes separate, whether 6 unlocks feel like progression, whether the pit boss and run heat create a second arc, and whether the economy closes by floor 5. The last one now looks harder than the plan assumes — if a single reveal in High or Low returns $5 per heat point while blackjack returns $0.26, floor 5 will be cleared by whichever game has the best rate, and the other two become scenery.

---

## Ranked recommendations

1. **Reprice High or Low's information ceiling**, or accept that it is the only game anyone plays.
2. **Retune quota gap against table maximum, not average bet.** Target a ratio near 12–20 on floor 1.
3. **Reprice all six side bets for a 52-card shoe**, or make the starting shoe two decks and accept slower marks.
4. **Make cooling proportional to current heat** so the sawtooth exists above the bottom rung and isn't free below it.
5. **Give the adjust ladder the same design attention as the window ladder.** It is doing more work than the plan credits it with.

## My findings
- Heat needs to be a measure of bet size (both heat reduction and heat increase) This is to prevent cooling with consecutive min bets, then using max bets with switches or palms to guarantee wins. 
- Repeating cooling with low bet sizes should decrease heat loss per consecutive attempt
- Wide range tables aren't good (too easy to cooldown with low bets and go all in and guarantee win by using heat), should just be high stakes table and low stakes table
- Quotas need to be higher
- Objective of The Game should be how do I maximize profit while minimizing heat gain. How do I use the partial information I have and the information I can gain to win while using the least amount of heat.
- Heat costs need to be adjusted a little with information being cheaper and manipulation being costlier. For good game balance, the player's focus should be on using information to manipulate bets instead of using manipulation to guarantee wins with max bets. The player should feel like they made a good play when they use minimal information to win big bets instead of just switching or changing cards.
- High or Low's differential scaling makes it easy to hit big by manipulating cards to guarantee low change events. Eg. User has a 2, they can bet low and guarantee low to get a large payout.
- Marking cards takes too long to reach payout. We should reshuffle on every play instead of playing out from the same deck. This will remove card counting from the game as well which is not our objective and it also makes marking more effective because players have a higher chance to actually see marked cards.
- The amount that you can change your bet should be based on your initial bet. There should be a limit to prevent min betting, then raising bet to max on a guaranteed win.
- Ways to scale difficulty: Heat scaling, payout scaling (tables give less of a payout), quota scaling