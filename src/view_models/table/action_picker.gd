class_name ActionPicker
extends RefCounted
## Picks and runs a window action in steps (spec §2.3, §2.5): the action,
## then its card, then what to do to it. Partial reveal picks a question,
## Mark a symbol, Nudge up or down, Recolour a suit, Switch the other card,
## Palm a rank and then a suit. Look ahead runs at once. When the last step
## is picked the action runs through HandActions, its result goes to
## info_lines, and the picker is back at the actions.
##
## Every option is offered, even one the card can't take (up on a King), so
## the screen shows nothing the player can't see; HandActions refuses it and
## the refusal is logged. The table labels cards (face down, marks, tape).
## A manipulation's last step shows its full cost on any option whose
## side-bet heat (§8) raises it above the action's cost.
##
## With Loaded Question (§9) a partial reveal asks up to the kit's
## questions_per_reveal: the player ticks them, then asks. Separately, any
## card changed this hand can be kept with Masking Tape, a Cold Seal or an
## Ink charge (§2.3).

enum Step { ACTION, CARD, OPTION, OTHER_CARD, PALM_SUIT }
## How a change is kept (§2.3, §9).
enum Keep { TAPE, SEAL, INK }

const QUESTION_TEXT: Dictionary[PartialQuestion.Kind, String] = {
	PartialQuestion.Kind.BUSTS_ME: "busts me?",
	PartialQuestion.Kind.TEN_CARD: "ten-card?",
	PartialQuestion.Kind.RED: "red?",
	PartialQuestion.Kind.HIGH: "high?",
	PartialQuestion.Kind.FACE_CARD: "face card?",
	PartialQuestion.Kind.WITHIN_THREE: "within three?",
}
const SUIT_NAMES: Array[String] = ["clubs", "diamonds", "hearts", "spades"]
## Nudge options: their ids are the step.
const UP: int = 1
const DOWN: int = -1
## The choice that asks the ticked questions.
const ASK: int = -1
const KEEP_NAMES: Array[String] = ["Tape", "Seal", "Ink"]
const KEPT_TEXT: Array[String] = ["taped", "sealed", "inked"]

## What the actions found or did this hand, oldest first.
var info_lines: PackedStringArray = []

var _hand: HandActions
var _kit: ActionKit
## Card -> String: how the table writes a card.
var _card_label: Callable
var _reveal_costs: bool
var _step: Step = Step.ACTION
var _action: ActionKind.Kind
var _card_id: int = Card.NO_ID
var _palm_rank: int = 0
## Questions ticked so far, with Loaded Question.
var _ticked: Array[PartialQuestion.Kind] = []


func _init(hand: HandActions, kit: ActionKit, card_label: Callable, reveal_costs: bool) -> void:
	_hand = hand
	_kit = kit
	_card_label = card_label
	_reveal_costs = reveal_costs


## The buttons for the current step.
func choices() -> Array[Choice]:
	match _step:
		Step.ACTION:
			return _action_choices()
		Step.CARD:
			return _card_choices(_hand.targets(_action), Card.NO_ID)
		Step.OTHER_CARD:
			return _with_costs(_card_choices(_hand.targets(_action), _card_id))
		Step.OPTION:
			return _with_costs(_option_choices())
		Step.PALM_SUIT:
			return _with_costs(_suit_choices())
	return []


func pick(id: int) -> void:
	match _step:
		Step.ACTION:
			_pick_action(id as ActionKind.Kind)
		Step.CARD:
			_card_id = id
			_ticked.clear()
			if _action == ActionKind.Kind.FULL_REVEAL:
				_run_full_reveal()
			else:
				_step = Step.OTHER_CARD if _action == ActionKind.Kind.SWITCH else Step.OPTION
		Step.OTHER_CARD:
			_run_switch(id)
		Step.OPTION:
			_pick_option(id)
		Step.PALM_SUIT:
			_run_palm(id as Card.Suit)


## One step out: suit to rank, option or other card to card, card to action.
func back() -> void:
	match _step:
		Step.PALM_SUIT:
			_step = Step.OPTION
		Step.OPTION, Step.OTHER_CARD:
			_step = Step.CARD
		Step.CARD:
			_step = Step.ACTION


## Tape, Seal and Ink for each card changed this hand, with what's left.
func keep_choices() -> Array[Choice]:
	var counts: Array[int] = [_kit.masking_tape, _kit.cold_seals, _kit.ink_charges]
	var result: Array[Choice] = []
	for card: Card in _hand.keepable_cards():
		var label: String = _card_label.call(card)
		for keep_kind: int in Keep.values():
			var text: String = "%s %s (%d)" % [KEEP_NAMES[keep_kind], label, counts[keep_kind]]
			result.append(Choice.new(text, counts[keep_kind] > 0, card.id * KEEP_NAMES.size() + keep_kind))
	return result


func keep(id: int) -> void:
	var card_id: int = id / KEEP_NAMES.size()
	var keep_kind: int = id % KEEP_NAMES.size()
	var before: Array[Card] = _hand.keepable_cards()
	var kept: bool = false
	match keep_kind:
		Keep.TAPE:
			kept = _hand.tape(card_id)
		Keep.SEAL:
			kept = _hand.seal(card_id)
		Keep.INK:
			kept = _hand.ink(card_id)
	if not kept:
		info_lines.append(KEEP_NAMES[keep_kind] + " refused")
		return
	# A Switch's two cards are kept together (§2.3), so name every card kept.
	var after: Array[Card] = _hand.keepable_cards()
	var labels: PackedStringArray = []
	for card: Card in before:
		if card not in after:
			var label: String = _card_label.call(card)
			labels.append(label)
	info_lines.append("%s %s" % [" and ".join(labels), KEPT_TEXT[keep_kind]])


func can_go_back() -> bool:
	return _step != Step.ACTION


## Back to the actions, e.g. when a window closes or opens.
func reset() -> void:
	_step = Step.ACTION


func prompt_text() -> String:
	var action: String = HeatText.action_name(_action)
	match _step:
		Step.CARD:
			return action + ": choose a card"
		Step.OTHER_CARD:
			return "%s %s: choose the other card" % [action, _label_of(_card_id)]
		Step.OPTION:
			if _action == ActionKind.Kind.PALM:
				return "Palm %s: choose a rank" % _label_of(_card_id)
			return "%s %s: choose" % [action, _label_of(_card_id)]
		Step.PALM_SUIT:
			return "Palm %s to %s: choose a suit" % [_label_of(_card_id), Card.RANK_CODES[_palm_rank]]
	return "Choose an action"


func _action_choices() -> Array[Choice]:
	var result: Array[Choice] = []
	for action: ActionKind.Kind in ActionKind.Kind.values():
		var label: String = HeatText.action_name(action)
		var cost: String = HeatText.cost_preview(_hand, action, _reveal_costs)
		if not cost.is_empty():
			label += " " + cost
		result.append(Choice.new(label, _hand.can_use(action), action))
	return result


## Adds the full cost to each last-step choice that side-bet heat raises.
func _with_costs(choices: Array[Choice]) -> Array[Choice]:
	if not _reveal_costs:
		return choices
	var base: float = _hand.cost_of(_action)
	for choice: Choice in choices:
		var cost: float = _cost_if_picked(choice.id)
		if snappedf(cost, HeatText.STEP) > snappedf(base, HeatText.STEP):
			choice.label += " " + HeatText.number(cost)
	return choices


## The full cost of the manipulation this choice would make, or 0 for a
## choice that isn't a manipulation's last step.
func _cost_if_picked(id: int) -> float:
	match _step:
		Step.OTHER_CARD:
			return _hand.switch_cost(_card_id, id)
		Step.PALM_SUIT:
			return _hand.palm_cost(_card_id, _palm_rank, id as Card.Suit)
		Step.OPTION:
			match _action:
				ActionKind.Kind.NUDGE:
					return _hand.nudge_cost(_card_id, id)
				ActionKind.Kind.RECOLOUR:
					return _hand.recolour_cost(_card_id, id as Card.Suit)
	return 0.0


func _card_choices(cards: Array[Card], skip_id: int) -> Array[Choice]:
	var result: Array[Choice] = []
	for card: Card in cards:
		if card.id != skip_id:
			var label: String = _card_label.call(card)
			result.append(Choice.new(label, true, card.id))
	return result


func _option_choices() -> Array[Choice]:
	var result: Array[Choice] = []
	match _action:
		ActionKind.Kind.PARTIAL_REVEAL:
			result = _question_choices()
		ActionKind.Kind.MARK:
			for symbol: int in _kit.symbols:
				result.append(Choice.new(CardText.symbol_name(symbol), true, symbol))
		ActionKind.Kind.NUDGE:
			result.append(Choice.new("Up", true, UP))
			result.append(Choice.new("Down", true, DOWN))
		ActionKind.Kind.RECOLOUR:
			result = _suit_choices()
		ActionKind.Kind.PALM:
			for rank: int in range(1, Card.RANK_CODES.size()):
				result.append(Choice.new(Card.RANK_CODES[rank], true, rank))
	return result


## One question: pick it and it's asked. More: tick up to the limit, then Ask.
func _question_choices() -> Array[Choice]:
	var result: Array[Choice] = []
	var limit: int = _kit.questions_per_reveal
	for question: PartialQuestion.Kind in _hand.questions(_card_id):
		var text: String = QUESTION_TEXT[question]
		text = text[0].to_upper() + text.substr(1)
		if limit <= 1:
			result.append(Choice.new(text, true, question))
			continue
		var ticked: bool = question in _ticked
		var box: String = "[x] " if ticked else "[ ] "
		result.append(Choice.new(box + text, ticked or _ticked.size() < limit, question))
	if limit > 1:
		result.append(Choice.new("Ask", not _ticked.is_empty(), ASK))
	return result


func _suit_choices() -> Array[Choice]:
	var result: Array[Choice] = []
	for suit: Card.Suit in Card.Suit.values():
		result.append(Choice.new(SUIT_NAMES[suit].capitalize(), true, suit))
	return result


func _pick_action(action: ActionKind.Kind) -> void:
	if not _hand.can_use(action):
		return
	_action = action
	if action != ActionKind.Kind.LOOK_AHEAD:
		_step = Step.CARD
		return
	var names: PackedStringArray = []
	for card: Card in _hand.look_ahead():
		names.append(card.short_name())
	_log("Next: " + " ".join(names))


func _pick_option(id: int) -> void:
	var label: String = _label_of(_card_id)
	match _action:
		ActionKind.Kind.PARTIAL_REVEAL:
			if _kit.questions_per_reveal <= 1:
				_ask(label, [id as PartialQuestion.Kind])
			elif id == ASK:
				_ask(label, _ticked)
			elif (id as PartialQuestion.Kind) in _ticked:
				_ticked.erase(id as PartialQuestion.Kind)
			else:
				_ticked.append(id as PartialQuestion.Kind)
		ActionKind.Kind.MARK:
			_log_result(_hand.mark(_card_id, id), "%s marked %s" % [label, CardText.symbol_name(id)])
		ActionKind.Kind.NUDGE:
			var way: String = "up" if id == UP else "down"
			_log_result(_hand.nudge(_card_id, id), "%s nudged %s" % [label, way])
		ActionKind.Kind.RECOLOUR:
			_log_result(_hand.recolour(_card_id, id as Card.Suit), "%s now %s" % [label, SUIT_NAMES[id]])
		ActionKind.Kind.PALM:
			_palm_rank = id
			_step = Step.PALM_SUIT


func _ask(label: String, asked: Array[PartialQuestion.Kind]) -> void:
	var answers: Array[bool] = _hand.partial_reveal(_card_id, asked)
	if answers.is_empty():
		_log("Partial reveal refused")
		return
	var parts: PackedStringArray = []
	for i: int in asked.size():
		parts.append("%s %s" % [QUESTION_TEXT[asked[i]], "yes" if answers[i] else "no"])
	_log("%s: %s" % [label, ", ".join(parts)])


func _run_full_reveal() -> void:
	var label: String = _label_of(_card_id)
	var card: Card = _hand.full_reveal(_card_id)
	if card == null:
		_log(HeatText.action_name(_action) + " refused")
	else:
		_log("%s is %s" % [label, card.short_name()])


func _run_switch(other_id: int) -> void:
	var text: String = "%s and %s switched" % [_label_of(_card_id), _label_of(other_id)]
	_log_result(_hand.switch_cards(_card_id, other_id), text)


func _run_palm(suit: Card.Suit) -> void:
	var label: String = _label_of(_card_id)
	var card: Card = Card.new(_palm_rank, suit)
	_log_result(_hand.palm(_card_id, _palm_rank, suit), "%s now %s" % [label, card.short_name()])


func _log_result(done: bool, text: String) -> void:
	_log(text if done else HeatText.action_name(_action) + " refused")


## Records a line and goes back to the actions.
func _log(text: String) -> void:
	info_lines.append(text)
	_step = Step.ACTION


func _label_of(card_id: int) -> String:
	for card: Card in _hand.targets(_action):
		if card.id == card_id:
			var label: String = _card_label.call(card)
			return label
	return "?"
