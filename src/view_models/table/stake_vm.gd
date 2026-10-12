class_name StakeVM
extends RefCounted
## What Deal would put on the table at the stake window: the opening bet
## plus the side bets on, against the bankroll.

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
