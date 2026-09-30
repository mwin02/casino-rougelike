class_name SideBet
extends RefCounted
## One side bet placed at the stake window (spec §8). It rides the whole hand
## and can't be adjusted. It settles when the round resolves, on the cards as
## they read then.

## Before the round settles it.
const UNSETTLED: int = -2

var kind: SideBetKind.Kind
var stake: int
## Dragon Bonus and Pair: PLAYER or BANKER.
var side: BaccaratRound.BetSide = BaccaratRound.BetSide.PLAYER
## Exact rank: the rank called, 1–13.
var called_rank: int = 0
## SideBetPayout's result once settled, or UNSETTLED.
var pays: int = UNSETTLED


func _init(p_kind: SideBetKind.Kind, p_stake: int) -> void:
	kind = p_kind
	stake = p_stake


## Dragon Bonus or Pair on side.
static func on_side(
	p_kind: SideBetKind.Kind, p_stake: int, p_side: BaccaratRound.BetSide
) -> SideBet:
	var bet: SideBet = SideBet.new(p_kind, p_stake)
	bet.side = p_side
	return bet


static func exact_rank(p_stake: int, rank: int) -> SideBet:
	var bet: SideBet = SideBet.new(SideBetKind.Kind.EXACT_RANK, p_stake)
	bet.called_rank = rank
	return bet


func is_settled() -> bool:
	return pays != UNSETTLED


## Dollars won (positive) or lost (negative); 0 until settled.
func net() -> int:
	return SideBetPayout.net(stake, pays) if is_settled() else 0


## A copy for the round, so nothing outside it changes the bet mid-hand.
func copy() -> SideBet:
	var bet: SideBet = SideBet.new(kind, stake)
	bet.side = side
	bet.called_rank = called_rank
	return bet


## True when the bet can be placed at game, at most cap dollars.
func is_valid(game: GameKind.Kind, cap: int) -> bool:
	if SideBetKind.game_of(kind) != game or stake < 1 or stake > cap:
		return false
	match kind:
		SideBetKind.Kind.DRAGON_BONUS, SideBetKind.Kind.PAIR:
			return side != BaccaratRound.BetSide.TIE
		SideBetKind.Kind.EXACT_RANK:
			return Card.is_valid_rank(called_rank)
	return true
