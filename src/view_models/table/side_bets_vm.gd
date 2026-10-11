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
const NONE: String = "—"

var _session: TableSession
var _kinds: Array[SideBetKind.Kind]
var _stakes: Dictionary[SideBetKind.Kind, int] = {}
var _sides: Dictionary[SideBetKind.Kind, BaccaratRound.BetSide] = {}
var _rank: int = 1


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
