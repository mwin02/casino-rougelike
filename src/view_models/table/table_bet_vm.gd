class_name TableBetVM
extends RefCounted
## The bet buttons at one table session. Between hands they set the opening
## bet within the table and the bankroll, and pick baccarat's side. In a hand
## they move the bet in an adjust, within the adjust limits (spec §1.3), and
## Reset goes back to the opening bet. Each step is one table minimum.

enum Bet { DOWN, UP, MIN, MAX, RESET }

const BET_NAMES: Array[String] = ["-", "+", "Min", "Max", "Reset"]

var opening_bet: int
var side: BaccaratRound.BetSide = BaccaratRound.BetSide.PLAYER

var _session: TableSession
## The hand being played, or null between hands.
var _game: GameTableVM


func _init(session: TableSession) -> void:
	_session = session
	opening_bet = session.table.table_min


## A hand has been dealt.
func start_hand(game: GameTableVM) -> void:
	_game = game


## The hand has settled. The next opening bet still fits the bankroll.
func end_hand() -> void:
	_game = null
	opening_bet = clampi(opening_bet, _session.table.table_min, _max())


func choices() -> Array[Choice]:
	var bet: int = _bet()
	var low: int = _min()
	var high: int = _max()
	var live: bool = _game == null or _game.game_round().can_adjust()
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


func text() -> String:
	if _game != null:
		return _game.bet_text()
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


func _bet() -> int:
	return _game.game_round().total_bet() if _game != null else opening_bet


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
	if _game != null:
		_game.game_round().adjust(total)
	else:
		opening_bet = total
