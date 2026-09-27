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

enum Step { ACTION, CARD, OPTION, OTHER_CARD, PALM_SUIT }

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
			return _card_choices(_hand.targets(_action), _card_id)
		Step.OPTION:
			return _option_choices()
		Step.PALM_SUIT:
			return _suit_choices()
	return []


func pick(id: int) -> void:
	match _step:
		Step.ACTION:
			_pick_action(id as ActionKind.Kind)
		Step.CARD:
			_card_id = id
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
			for question: PartialQuestion.Kind in _hand.questions(_card_id):
				var text: String = QUESTION_TEXT[question]
				result.append(Choice.new(text[0].to_upper() + text.substr(1), true, question))
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
			var question: PartialQuestion.Kind = id as PartialQuestion.Kind
			var answers: Array[bool] = _hand.partial_reveal(_card_id, [question])
			if answers.is_empty():
				_log("Partial reveal refused")
			else:
				_log("%s: %s %s" % [label, QUESTION_TEXT[question], "yes" if answers[0] else "no"])
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
