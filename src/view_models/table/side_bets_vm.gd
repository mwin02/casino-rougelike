class_name SideBetsVM
extends RefCounted
## The side bet buttons at one table session (spec §8), set at the stake
## window only. Each side bet has one button stepping its stake by a quarter
## of the cap and back to none; Dragon Bonus and Pair add a side button, and
## exact rank a button for the rank called. The stakes stay for the next
## hand. A table that takes no side bets (a house rule) has no buttons.

enum Part { STAKE, SIDE, RANK }

const NAMES: Dictionary[SideBetKind.Kind, String] = {
	SideBetKind.Kind.PERFECT_PAIRS: "Perfect Pairs",
	SideBetKind.Kind.TWENTY_ONE_PLUS_THREE: "21+3",
	SideBetKind.Kind.BUST_IT: "Bust It",
	SideBetKind.Kind.DRAGON_BONUS: "Dragon Bonus",
	SideBetKind.Kind.PAIR: "Pair",
	SideBetKind.Kind.EXACT_RANK: "Exact rank",
}
## Stake steps up to the cap.
const STEPS: int = 4
## The real table's stepper moves a stake by a tenth of the cap.
const FINE_STEPS: int = 10
const WINS: Dictionary[SideBetKind.Kind, String] = {
	SideBetKind.Kind.PERFECT_PAIRS: "Your first two cards are the same rank",
	SideBetKind.Kind.TWENTY_ONE_PLUS_THREE: "Your two cards + dealer up card, as a poker hand",
	SideBetKind.Kind.BUST_IT: "Dealer busts · pays by dealer card count",
	SideBetKind.Kind.DRAGON_BONUS: "Your side wins · by margin",
	SideBetKind.Kind.PAIR: "The side's first two cards are the same rank",
	SideBetKind.Kind.EXACT_RANK: "The first card up is the rank you pick",
}
const OFF: String = "OFF"
const NOT_ENOUGH: String = "NOT ENOUGH"
const NONE: String = "—"

## The real table's rows show what wins each bet and its pay table only
## while this is set. It stays as set for the session.
var detailed: bool = false

var _session: TableSession
var _kinds: Array[SideBetKind.Kind]
var _stakes: Dictionary[SideBetKind.Kind, int] = {}
var _sides: Dictionary[SideBetKind.Kind, BaccaratRound.BetSide] = {}
var _rank: int = 1
var _previous_stakes: Dictionary[SideBetKind.Kind, int] = {}
var _previous_sides: Dictionary[SideBetKind.Kind, BaccaratRound.BetSide] = {}
var _previous_rank: int = 1
## The stake a switched-off side bet comes back with.
var _kept: Dictionary[SideBetKind.Kind, int] = {}


func _init(session: TableSession) -> void:
	_session = session
	_kinds = SideBetKind.for_game(session.table.game)
	for kind: SideBetKind.Kind in _kinds:
		_stakes[kind] = 0
		_sides[kind] = BaccaratRound.BetSide.PLAYER


func choices() -> Array[Choice]:
	var open: bool = not _session.in_hand()
	var result: Array[Choice] = []
	if not _session.side_bets_offered():
		return result
	for kind: SideBetKind.Kind in _kinds:
		var stake: String = MoneyFormat.format(_stakes[kind]) if _stakes[kind] > 0 else NONE
		result.append(Choice.new("%s %s" % [NAMES[kind], stake], open, _id(kind, Part.STAKE)))
		match kind:
			SideBetKind.Kind.DRAGON_BONUS, SideBetKind.Kind.PAIR:
				var side: String = BaccaratTableVM.SIDE_NAMES[_sides[kind]]
				result.append(Choice.new("on " + side, open, _id(kind, Part.SIDE)))
			SideBetKind.Kind.EXACT_RANK:
				result.append(Choice.new("call " + Card.RANK_CODES[_rank], open, _id(kind, Part.RANK)))
	return result


func press(id: int) -> void:
	if _session.in_hand():
		return
	var kind: SideBetKind.Kind = (id / Part.size()) as SideBetKind.Kind
	match (id % Part.size()) as Part:
		Part.STAKE:
			var cap: int = _session.side_bet_cap()
			var step: int = maxi(cap / STEPS, 1)
			_stakes[kind] = 0 if _stakes[kind] >= cap else mini(_stakes[kind] + step, cap)
		Part.SIDE:
			var banker: bool = _sides[kind] == BaccaratRound.BetSide.BANKER
			_sides[kind] = BaccaratRound.BetSide.PLAYER if banker else BaccaratRound.BetSide.BANKER
		Part.RANK:
			_rank = _rank % (Card.RANK_CODES.size() - 1) + 1


## One row per side bet for the real table. room is what the bankroll has
## left after the opening bet and the side bets already on.
func rows(room: int) -> Array[SideBetRow]:
	var result: Array[SideBetRow] = []
	if not _session.side_bets_offered():
		return result
	var open: bool = not _session.in_hand()
	var rules: SideBetRules = SideBetRules.from_config(_session.rules_config())
	var step: int = _fine_step()
	for kind: SideBetKind.Kind in _kinds:
		var row: SideBetRow = SideBetRow.new()
		row.kind = kind
		row.name = NAMES[kind]
		row.wins = WINS[kind]
		row.pays = SideBetRow.pays_of(kind, rules)
		row.on = _stakes[kind] > 0
		var comes_back: int = _kept.get(kind, step)
		row.stake_text = MoneyFormat.format(_stakes[kind] if row.on else comes_back)
		row.can_toggle = open and (row.on or comes_back <= room)
		row.off_text = OFF if row.on or comes_back <= room else NOT_ENOUGH
		row.can_lower = open and row.on and _stakes[kind] > step
		var under_cap: bool = _stakes[kind] + step <= _session.side_bet_cap()
		row.can_raise = open and row.on and under_cap and step <= room
		row.stake = _stakes[kind]
		row.picks_side = kind in [SideBetKind.Kind.DRAGON_BONUS, SideBetKind.Kind.PAIR]
		row.side = _sides[kind]
		row.picks_rank = kind == SideBetKind.Kind.EXACT_RANK
		row.rank = _rank
		result.append(row)
	return result


## Switches a side bet on at the stake it last had, or off.
func toggle(kind: SideBetKind.Kind) -> void:
	if _session.in_hand():
		return
	if _stakes[kind] > 0:
		_kept[kind] = _stakes[kind]
		_stakes[kind] = 0
	else:
		_stakes[kind] = _kept.get(kind, _fine_step())


## Moves a side bet's stake one step up (1) or down (-1), within the cap.
func step_stake(kind: SideBetKind.Kind, direction: int) -> void:
	if _session.in_hand() or _stakes[kind] <= 0:
		return
	var step: int = _fine_step()
	_stakes[kind] = clampi(_stakes[kind] + direction * step, step, _session.side_bet_cap())


func choose_side(kind: SideBetKind.Kind, side: BaccaratRound.BetSide) -> void:
	if not _session.in_hand():
		_sides[kind] = side


func choose_rank(rank: int) -> void:
	if not _session.in_hand() and Card.is_valid_rank(rank):
		_rank = rank


## A hand has been dealt: these stakes, sides and rank are the previous bet.
func remember() -> void:
	_previous_stakes = _stakes.duplicate()
	_previous_sides = _sides.duplicate()
	_previous_rank = _rank


## The side bets of the hand dealt last, in dollars.
func previous_total() -> int:
	var sum: int = 0
	for kind: SideBetKind.Kind in _previous_stakes:
		sum += _previous_stakes[kind]
	return sum


## Back to the side bets of the hand dealt last.
func use_previous() -> void:
	if _session.in_hand() or _previous_stakes.is_empty():
		return
	_stakes = _previous_stakes.duplicate()
	_sides = _previous_sides.duplicate()
	_rank = _previous_rank


## Every side bet now on, in dollars.
func total() -> int:
	var sum: int = 0
	for kind: SideBetKind.Kind in _kinds:
		sum += _stakes[kind]
	return sum


func toggle_detail() -> void:
	detailed = not detailed


## "UP TO $5,000 EACH", and with the detail " · NO HEAT · LOCKED ONCE DEALT".
func caption() -> String:
	var text: String = "UP TO %s EACH" % MoneyFormat.format(_session.side_bet_cap())
	return text + " · NO HEAT · LOCKED ONCE DEALT" if detailed else text


func _fine_step() -> int:
	return maxi(_session.side_bet_cap() / FINE_STEPS, 1)


## The side bets set now, for the next deal.
func bets() -> Array[SideBet]:
	var result: Array[SideBet] = []
	for kind: SideBetKind.Kind in _kinds:
		if _stakes[kind] <= 0:
			continue
		match kind:
			SideBetKind.Kind.DRAGON_BONUS, SideBetKind.Kind.PAIR:
				result.append(SideBet.on_side(kind, _stakes[kind], _sides[kind]))
			SideBetKind.Kind.EXACT_RANK:
				result.append(SideBet.exact_rank(_stakes[kind], _rank))
			_:
				result.append(SideBet.new(kind, _stakes[kind]))
	return result


## "Perfect Pairs +$6,000" for each side bet a settled hand carried.
static func result_lines(settled: Array[SideBet]) -> PackedStringArray:
	var lines: PackedStringArray = []
	for bet: SideBet in settled:
		lines.append("%s %s" % [NAMES[bet.kind], MoneyFormat.format_signed(bet.net())])
	return lines


static func _id(kind: SideBetKind.Kind, part: Part) -> int:
	return kind * Part.size() + part
