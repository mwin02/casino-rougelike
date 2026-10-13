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
## questions_per_reveal: the player ticks them, then asks. Separately, a
## Nudge, Recolour or Palm made this hand can be kept with Masking Tape, a
## Cold Seal or an Ink charge (§2.3). A Switch can't.

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
## A question as a card's tag: "TEN? NO".
const QUESTION_TAG: Dictionary[PartialQuestion.Kind, String] = {
	PartialQuestion.Kind.BUSTS_ME: "BUST",
	PartialQuestion.Kind.TEN_CARD: "TEN",
	PartialQuestion.Kind.RED: "RED",
	PartialQuestion.Kind.HIGH: "HIGH",
	PartialQuestion.Kind.FACE_CARD: "FACE",
	PartialQuestion.Kind.WITHIN_THREE: "±3",
}
const SUIT_NAMES: Array[String] = ["clubs", "diamonds", "hearts", "spades"]
## Nudge options: their ids are the step.
const UP: int = 1
const DOWN: int = -1
## The choice that asks the ticked questions.
const ASK: int = -1
const KEEP_NAMES: Array[String] = ["Tape", "Seal", "Ink"]
const KEEP_ICONS: Array[String] = ["icons/tape", "icons/seal", "icons/ink"]
const ACTION_ICONS: Dictionary[ActionKind.Kind, String] = {
	ActionKind.Kind.PARTIAL_REVEAL: "icons/partial_reveal",
	ActionKind.Kind.MARK: "icons/mark",
	ActionKind.Kind.FULL_REVEAL: "icons/full_reveal",
	ActionKind.Kind.LOOK_AHEAD: "icons/look_ahead",
	ActionKind.Kind.RECOLOUR: "icons/recolour",
	ActionKind.Kind.NUDGE: "icons/nudge",
	ActionKind.Kind.SWITCH: "icons/switch",
	ActionKind.Kind.PALM: "icons/palm",
}
const KEPT_TEXT: Array[String] = ["taped", "sealed", "inked"]

## What the actions found or did this hand, oldest first.
var info_lines: PackedStringArray = []
## Set for the real table: names without letter codes, each cost as a whole
## number in the choice's detail, ticks as the choice's selected flag.
var for_screen: bool = false
## Ids of the cards a full reveal or look ahead showed this hand. The table
## draws them face up for the player, as they read now.
var peeked: Array[int] = []
## What partial reveals found this hand, by card id, as tags the table
## draws on the card: "TEN? NO". A card's go when it is changed.
var card_tags: Dictionary[int, PackedStringArray] = {}
## The cards the last look ahead showed, in order off the deck.
var shown_cards: Array[Card] = []

var _hand: HandActions
var _kit: ActionKit
## Card -> String: how the table writes a card.
var _card_label: Callable
var _step: Step = Step.ACTION
var _action: ActionKind.Kind
var _card_id: int = Card.NO_ID
var _palm_rank: int = 0
## Questions ticked so far, with Loaded Question.
var _ticked: Array[PartialQuestion.Kind] = []
## info_lines as rows, each with the cards its action touched.
var _rows: Array[TrickRow] = []


func _init(hand: HandActions, kit: ActionKit, card_label: Callable) -> void:
	_hand = hand
	_kit = kit
	_card_label = card_label


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
			var id: int = card.id * KEEP_NAMES.size() + keep_kind
			var text: String = "%s %s (%d)" % [KEEP_NAMES[keep_kind], label, counts[keep_kind]]
			var choice: Choice = Choice.new(text, counts[keep_kind] > 0, id)
			if for_screen:
				choice.label = KEEP_NAMES[keep_kind]
				choice.detail = "×%d" % counts[keep_kind]
				choice.icon = KEEP_ICONS[keep_kind]
			result.append(choice)
	return result


func keep(id: int) -> void:
	var card_id: int = id / KEEP_NAMES.size()
	var keep_kind: int = id % KEEP_NAMES.size()
	var label: String = "?"
	for card: Card in _hand.keepable_cards():
		if card.id == card_id:
			label = _card_label.call(card)
	var kept: bool = false
	match keep_kind:
		Keep.TAPE:
			kept = _hand.tape(card_id)
		Keep.SEAL:
			kept = _hand.seal(card_id)
		Keep.INK:
			kept = _hand.ink(card_id)
	var text: String = KEEP_NAMES[keep_kind] + " refused"
	if kept:
		text = "%s %s" % [label, KEPT_TEXT[keep_kind]]
	info_lines.append(text)
	_rows.append(TrickRow.new(text, [card_id]))


## What was done this hand, newest first. A change that can still be kept
## has its keeps on the newest row about the card now showing it: its own
## row, or the Switch's that moved it.
func history() -> Array[TrickRow]:
	for row: TrickRow in _rows:
		row.keeps = []
		row.keep_card = ""
	var keeps: Array[Choice] = keep_choices()
	var cards: Array[Card] = _hand.keepable_cards()
	var newest_first: Array[TrickRow] = _rows.duplicate()
	newest_first.reverse()
	for i: int in cards.size():
		for row: TrickRow in newest_first:
			if cards[i].id in row.card_ids and row.keeps.is_empty():
				row.keeps = keeps.slice(i * KEEP_NAMES.size(), (i + 1) * KEEP_NAMES.size())
				row.keep_card = _card_label.call(cards[i])
				break
	return newest_first


func step() -> Step:
	return _step


## The action being picked. Only meaningful past the first step.
func action() -> ActionKind.Kind:
	return _action


## The heat the action being picked would add, so the meter can show where
## it lands. 0 while no action is picked.
func weighed_cost() -> float:
	return _hand.cost_of(_action) if _step != Step.ACTION else 0.0


## The card being worked on, once it's picked: the table keeps it outlined
## while its rank, suit, question or other card is chosen. Card.NO_ID before.
func chosen_card() -> int:
	return _card_id if _step in [Step.OPTION, Step.OTHER_CARD, Step.PALM_SUIT] else Card.NO_ID


## True while several questions are being ticked for one partial reveal:
## the real table then shows Ask beside Back, not among the questions.
func asks_many() -> bool:
	var asking: bool = _step == Step.OPTION and _action == ActionKind.Kind.PARTIAL_REVEAL
	return asking and _kit.questions_per_reveal > 1


func can_ask() -> bool:
	return asks_many() and not _ticked.is_empty()


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
		var choice: Choice = Choice.new(HeatText.action_name(action), _hand.can_use(action), action)
		if for_screen:
			choice.detail = _whole(_hand.cost_of(action))
			choice.icon = ACTION_ICONS[action]
		else:
			choice.label += " " + HeatText.cost_preview(_hand, action)
		result.append(choice)
	return result


## Adds the full cost to each last-step choice that side-bet heat raises.
func _with_costs(choices: Array[Choice]) -> Array[Choice]:
	var base: float = _hand.cost_of(_action)
	for choice: Choice in choices:
		var cost: float = _cost_if_picked(choice.id)
		if for_screen and roundi(cost) > roundi(base):
			choice.detail = _whole(cost)
		elif not for_screen and snappedf(cost, HeatText.STEP) > snappedf(base, HeatText.STEP):
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
				var mark: Choice = Choice.new(_symbol(symbol), true, symbol)
				mark.icon = _art(CardText.symbol_icon(symbol))
				result.append(mark)
		ActionKind.Kind.NUDGE:
			result.append(Choice.new("Up", true, UP))
			result.append(Choice.new("Down", true, DOWN))
			result[0].icon = _art("icons/up")
			result[1].icon = _art("icons/down")
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
		var box: String = "" if for_screen else ("[x] " if ticked else "[ ] ")
		result.append(Choice.new(box + text, ticked or _ticked.size() < limit, question, ticked))
	if limit > 1 and not for_screen:
		result.append(Choice.new("Ask", not _ticked.is_empty(), ASK))
	return result


func _suit_choices() -> Array[Choice]:
	var result: Array[Choice] = []
	for suit: Card.Suit in Card.Suit.values():
		var choice: Choice = Choice.new(SUIT_NAMES[suit].capitalize(), true, suit)
		choice.icon = _art("cards/suit_" + SUIT_NAMES[suit])
		result.append(choice)
	return result


func _pick_action(action: ActionKind.Kind) -> void:
	if not _hand.can_use(action):
		return
	_action = action
	if action != ActionKind.Kind.LOOK_AHEAD:
		_step = Step.CARD
		return
	var names: PackedStringArray = []
	shown_cards = _hand.look_ahead()
	for card: Card in shown_cards:
		names.append(card.short_name())
		peeked.append(card.id)
	_log("Next cards shown" if for_screen else "Next: " + " ".join(names))


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
			_log_result(_hand.mark(_card_id, id), "%s marked %s" % [label, _symbol(id)])
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
	var tags: PackedStringArray = card_tags.get(_card_id, PackedStringArray())
	for i: int in asked.size():
		parts.append("%s %s" % [QUESTION_TEXT[asked[i]], "yes" if answers[i] else "no"])
		tags.append("%s? %s" % [QUESTION_TAG[asked[i]], "YES" if answers[i] else "NO"])
	card_tags[_card_id] = tags
	_log("%s: %s" % [label, ", ".join(parts)])


func _run_full_reveal() -> void:
	var label: String = _label_of(_card_id)
	var card: Card = _hand.full_reveal(_card_id)
	if card == null:
		_log(HeatText.action_name(_action) + " refused")
	else:
		peeked.append(card.id)
		_log("%s revealed" % label if for_screen else "%s is %s" % [label, card.short_name()])


func _run_switch(other_id: int) -> void:
	var text: String = "%s and %s switched" % [_label_of(_card_id), _label_of(other_id)]
	_log_result(_hand.switch_cards(_card_id, other_id), text, other_id)


func _run_palm(suit: Card.Suit) -> void:
	var label: String = _label_of(_card_id)
	var card: Card = Card.new(_palm_rank, suit)
	var name: String = CardText.spoken(card) if for_screen else card.short_name()
	_log_result(_hand.palm(_card_id, _palm_rank, suit), "%s now %s" % [label, name])


func _log_result(done: bool, text: String, other_id: int = Card.NO_ID) -> void:
	# What was learned about a card no longer holds once it's changed.
	if done and _action != ActionKind.Kind.MARK:
		card_tags.erase(_card_id)
		card_tags.erase(other_id)
	_log(text if done else HeatText.action_name(_action) + " refused", other_id)


## Records a line about the card being picked, and other_id if there is
## one, and goes back to the actions.
func _log(text: String, other_id: int = Card.NO_ID) -> void:
	var ids: Array[int] = []
	for id: int in [_card_id, other_id]:
		if id != Card.NO_ID and _action != ActionKind.Kind.LOOK_AHEAD:
			ids.append(id)
	info_lines.append(text)
	_rows.append(TrickRow.new(text, ids))
	_step = Step.ACTION


## "+12": a cost as the real table shows it.
static func _whole(cost: float) -> String:
	return "+%d" % roundi(cost)


## An icon for the real table; none for the debug one.
func _art(icon: String) -> String:
	return icon if for_screen else ""


func _symbol(symbol: int) -> String:
	return CardText.symbol_word(symbol) if for_screen else CardText.symbol_name(symbol)


func _label_of(card_id: int) -> String:
	for card: Card in _hand.targets(_action):
		if card.id == card_id:
			var label: String = _card_label.call(card)
			return label
	return "?"
