class_name StakeVM
extends RefCounted
## What Deal would put on the table at the stake window: the opening bet
## plus the side bets on, against the bankroll.

## Chips shown for an opening bet at the table minimum; more as it grows.
const CHIPS_AT_MIN: int = 2

var _session: TableSession
var _bets: TableBetVM
var _side_bets: SideBetsVM


func _init(session: TableSession, bets: TableBetVM, side_bets: SideBetsVM) -> void:
	_session = session
	_bets = bets
	_side_bets = side_bets


func total() -> int:
	return _bets.opening_bet + _side_bets.total()


## What the bankroll has left once the stake is on the table. Never below 0.
func room() -> int:
	return maxi(_session.bankroll - total(), 0)


## The opening bet and the side bets as shares of the bankroll, for its bar.
func shares() -> Vector2:
	var bankroll: float = _session.bankroll
	if bankroll <= 0.0:
		return Vector2.ZERO
	var bet: float = minf(_bets.opening_bet / bankroll, 1.0)
	return Vector2(bet, minf(_side_bets.total() / bankroll, 1.0 - bet))


## "$500–$3,000": where an adjust can take this opening bet (spec §1.3).
func adjust_range_text() -> String:
	var table: Table = _session.table
	var limits: BetLimits = BetLimits.from_config(
		_session.rules_config(), _bets.opening_bet, table.table_min, table.table_max
	)
	return "%s–%s" % [
		MoneyFormat.format(limits.min_total()), MoneyFormat.format(limits.max_total())
	]


## The side bet rows, each knowing whether the bankroll covers it.
func side_rows() -> Array[SideBetRow]:
	return _side_bets.rows(room())


## Chips in the opening bet's pile: it grows with the bet.
func bet_chips() -> int:
	return _bets.opening_bet * CHIPS_AT_MIN / _session.table.table_min


## True once a hand has been dealt, while the bankroll and the table still
## cover that hand's opening bet and side bets.
func can_use_previous() -> bool:
	var whole: int = _bets.previous_bet + _side_bets.previous_total()
	return _bets.can_use_previous() and whole <= _session.bankroll


## Prev bet: the opening bet, side and side bets of the hand dealt last.
func use_previous() -> void:
	if can_use_previous():
		_bets.use_previous()
		_side_bets.use_previous()


## "$2,300": what Prev bet would put down. Empty before the first hand.
func previous_text() -> String:
	if _bets.previous_bet <= 0:
		return ""
	return MoneyFormat.format(_bets.previous_bet + _side_bets.previous_total())
