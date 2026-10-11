class_name TableBetVM
extends RefCounted
## The bet buttons at one table session. Between hands they set the opening
## bet within the table and the bankroll, and pick baccarat's side. In a hand
## they move the bet in an adjust, within the adjust limits (spec §1.3), and
## Reset goes back to the opening bet. Each step is one table minimum.
##
## A window and the adjust after it are one step on screen: in such a window
## the buttons set a pending bet and the window stays open, so actions can
## still be taken. commit() makes the pending bet as the window closes into
## its adjust. A pending bet moved back to where it started changes nothing,
## and a manipulation drops it (the bet locks, spec §2.2).

enum Bet { DOWN, UP, MIN, MAX, RESET }

const BET_NAMES: Array[String] = ["-", "+", "Min", "Max", "Reset"]
const NO_PENDING: int = -1
const CHIPS: int = 4

var opening_bet: int
var side: BaccaratRound.BetSide = BaccaratRound.BetSide.PLAYER
## The opening bet and side of the hand dealt last; 0 before the first.
var previous_bet: int = 0
var previous_side: BaccaratRound.BetSide = BaccaratRound.BetSide.PLAYER

var _session: TableSession
## The hand being played, or null between hands.
var _game: GameTableVM
## The bet set in the window, made on commit(); NO_PENDING when none.
var _pending: int = NO_PENDING


func _init(session: TableSession) -> void:
	_session = session
	opening_bet = session.table.table_min


## A hand has been dealt.
func start_hand(game: GameTableVM) -> void:
	_game = game
	_pending = NO_PENDING
	previous_bet = opening_bet
	previous_side = side


## Between hands, once a hand has been dealt, while the table still takes
## that bet.
func can_use_previous() -> bool:
	return _game == null and previous_bet >= _min() and previous_bet <= _max()


## Back to the opening bet and side of the hand dealt last.
func use_previous() -> void:
	if can_use_previous():
		opening_bet = previous_bet
		side = previous_side


## The hand has settled. The next opening bet still fits the bankroll.
func end_hand() -> void:
	_game = null
	_pending = NO_PENDING
	opening_bet = clampi(opening_bet, _session.table.table_min, _max())


func choices() -> Array[Choice]:
	var bet: int = _bet()
	var low: int = _min()
	var high: int = _max()
	var live: bool = _game == null or _game.game_round().adjust_ahead()
	var result: Array[Choice] = [
		Choice.new(BET_NAMES[Bet.DOWN], live and bet > low, Bet.DOWN),
		Choice.new(BET_NAMES[Bet.UP], live and bet < high, Bet.UP),
		Choice.new(BET_NAMES[Bet.MIN], live and bet != low, Bet.MIN),
		Choice.new(BET_NAMES[Bet.MAX], live and bet != high, Bet.MAX),
	]
	if _game != null:
		var opening: int = _game.game_round().opening_bet
		var reset: bool = live and bet != opening and opening >= low and opening <= high
		result.append(Choice.new(BET_NAMES[Bet.RESET], reset, Bet.RESET))
	return result


func press(id: int) -> void:
	for choice: Choice in choices():
		if choice.id == id and choice.enabled:
			_apply(_target(id as Bet))
			return


## Opening bets to jump to between hands: four, evenly from the table
## minimum to its maximum. One the bankroll can't cover is disabled.
func chips() -> Array[Choice]:
	var low: int = _session.table.table_min
	var high: int = _session.table.table_max
	var result: Array[Choice] = []
	for i: int in CHIPS:
		var amount: int = low + (high - low) * i / (CHIPS - 1)
		amount -= amount % low
		var label: String = "$%sK" % String.num(amount / 1000.0).trim_suffix(".0")
		var fits: bool = _game == null and amount <= _max()
		result.append(Choice.new(label, fits, amount, amount == opening_bet))
	return result


## A chip: the opening bet becomes amount.
func press_chip(amount: int) -> void:
	for chip: Choice in chips():
		if chip.id == amount and chip.enabled:
			opening_bet = amount


## Where the opening bet sits between the table's minimum (0) and maximum (1).
func opening_fraction() -> float:
	var table: Table = _session.table
	return inverse_lerp(float(table.table_min), float(table.table_max), float(opening_bet))


## The window has closed into its adjust: make the pending bet, if any.
func commit() -> void:
	var total: int = _pending
	_set_pending(NO_PENDING)
	if _game != null and total != NO_PENDING and _game.game_round().can_adjust():
		_game.game_round().adjust(total)


func text() -> String:
	if _game != null:
		var text: String = _game.bet_text()
		if _in_window() and _pending != NO_PENDING and _pending != _placed():
			text += " (adjust to %s)" % MoneyFormat.format(_pending)
		return text
	return "Opening bet " + MoneyFormat.format(opening_bet)


## Baccarat's side for the next hand. Empty at other games.
func side_choices() -> Array[Choice]:
	var result: Array[Choice] = []
	if _session.table.game != GameKind.Kind.BACCARAT:
		return result
	for option: int in BaccaratRound.BetSide.values():
		var name: String = BaccaratTableVM.SIDE_NAMES[option]
		result.append(Choice.new(name, _game == null, option, option == side))
	return result


func choose_side(id: int) -> void:
	if _game == null:
		side = id as BaccaratRound.BetSide


## The bet the buttons move: the pending one in a window, else the bet.
func _bet() -> int:
	if _game == null:
		return opening_bet
	if _in_window() and _pending != NO_PENDING:
		return _pending
	return _placed()


func _set_pending(total: int) -> void:
	_pending = total
	if _game != null:
		_game.bet_pending = total != NO_PENDING and total != _placed()


func _placed() -> int:
	return _game.game_round().total_bet()


## In a window an adjust follows, while the bet can still move.
func _in_window() -> bool:
	var rnd: GameRound = _game.game_round()
	return rnd.in_window() and rnd.adjust_ahead()


func _min() -> int:
	return _game.game_round().adjust_min() if _game != null else _session.table.table_min


func _max() -> int:
	if _game != null:
		return _game.game_round().adjust_max()
	return mini(_session.table.table_max, maxi(_session.bankroll, _session.table.table_min))


func _target(step: Bet) -> int:
	var step_size: int = _session.table.table_min
	match step:
		Bet.DOWN:
			return maxi(_bet() - step_size, _min())
		Bet.UP:
			return mini(_bet() + step_size, _max())
		Bet.MIN:
			return _min()
		Bet.MAX:
			return _max()
	return _game.game_round().opening_bet


func _apply(total: int) -> void:
	if _game == null:
		opening_bet = total
	elif _in_window():
		_set_pending(total)
	else:
		_game.game_round().adjust(total)
