class_name SideBetPayout
extends RefCounted
## What each side bet pays (spec §8), from the cards it reads. Every function
## returns LOSE, PUSH, or n for a win at n:1.
##
## Blackjack: Perfect Pairs reads the player's first two cards; 21+3 those
## and the dealer's up card; Bust It the dealer's finished hand. Baccarat:
## Dragon Bonus reads the result on its side; Pair that side's first two
## cards. High or Low: exact rank reads the first card up.

const LOSE: int = -1
const PUSH: int = 0
## Dragon Bonus pays on a non-natural win by at least this much.
const DRAGON_MIN_MARGIN: int = 4
## Bust It's first tier: the fewest cards a dealer can bust on.
const BUST_IT_MIN_CARDS: int = 3


## Dollars won (positive) or lost (negative) on stake at pays.
static func net(stake: int, pays: int) -> int:
	return -stake if pays == LOSE else stake * pays


## Same rank: coloured if both are red or both black, else mixed.
static func perfect_pairs(rules: SideBetRules, a: Card, b: Card) -> int:
	if a.rank != b.rank:
		return LOSE
	var coloured: bool = PartialQuestion.is_red(a) == PartialQuestion.is_red(b)
	return rules.perfect_pairs[1] if coloured else rules.perfect_pairs[0]


## Poker hands on three cards. Aces play high or low (A-2-3, Q-K-A), never
## round the corner.
static func twenty_one_plus_three(rules: SideBetRules, a: Card, b: Card, up: Card) -> int:
	var ranks: Array[int] = [a.rank, b.rank, up.rank]
	ranks.sort()
	var flush: bool = a.suit == b.suit and b.suit == up.suit
	var straight: bool = (
		(ranks[0] + 1 == ranks[1] and ranks[1] + 1 == ranks[2]) or ranks == [1, 12, 13]
	)
	var tiers: Array[int] = rules.twenty_one_plus_three
	if straight and flush:
		return tiers[0]
	if ranks[0] == ranks[2]:
		return tiers[1]
	if straight:
		return tiers[2]
	if flush:
		return tiers[3]
	return LOSE


## By the number of cards the dealer busts on; the last tier covers more.
static func bust_it(rules: SideBetRules, dealer: BlackjackHand) -> int:
	if not dealer.is_bust():
		return LOSE
	var tier: int = mini(dealer.cards.size() - BUST_IT_MIN_CARDS, rules.bust_it.size() - 1)
	return rules.bust_it[maxi(tier, 0)]


## side is PLAYER or BANKER. natural: the hand ended on the first two cards
## with an 8 or 9 showing.
static func dragon_bonus(
	rules: SideBetRules,
	side: BaccaratRound.BetSide,
	player_total: int,
	banker_total: int,
	natural: bool
) -> int:
	var mine: int = player_total if side == BaccaratRound.BetSide.PLAYER else banker_total
	var theirs: int = banker_total if side == BaccaratRound.BetSide.PLAYER else player_total
	if mine == theirs:
		return PUSH if natural else LOSE
	if mine < theirs:
		return LOSE
	if natural:
		return rules.dragon_natural
	var margin: int = mine - theirs
	if margin < DRAGON_MIN_MARGIN:
		return LOSE
	return rules.dragon_bonus[margin - DRAGON_MIN_MARGIN]


## The side's first two cards are the same rank.
static func pair(rules: SideBetRules, first: Card, second: Card) -> int:
	return rules.pair if first.rank == second.rank else LOSE


static func exact_rank(rules: SideBetRules, called_rank: int, card: Card) -> int:
	return rules.exact_rank if card.rank == called_rank else LOSE
