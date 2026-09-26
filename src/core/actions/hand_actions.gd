class_name HandActions
extends RefCounted
## The window actions for one hand (spec §2, §2.5). Actions work only while
## the round has a window open and the kit has them unlocked. Reveals target
## the window's face-down subject cards; marks and manipulation can target
## any card in play. Every action taken is recorded in used for heat (block 6).

## §2.3: look ahead shows this many cards.
const LOOK_AHEAD_CARDS: int = 2

var used: Array[ActionUse] = []

var _round: GameRound
var _deck: Deck
var _layer: ManipulationLayer
var _kit: ActionKit
var _session: ActionSession


func _init(
	p_round: GameRound, deck: Deck, layer: ManipulationLayer, kit: ActionKit, session: ActionSession
) -> void:
	_round = p_round
	_deck = deck
	_layer = layer
	_kit = kit
	_session = session


func can_use(action: ActionKind.Kind) -> bool:
	if not _round.in_window() or not _kit.has(action):
		return false
	match action:
		ActionKind.Kind.MARK:
			return _kit.symbols > 0
		ActionKind.Kind.PALM:
			return not _session.palm_used
		ActionKind.Kind.LOOK_AHEAD:
			return not _round.upcoming(1).is_empty()
	return true


## The cards action can target now. Empty for look ahead, which has no target.
func targets(action: ActionKind.Kind) -> Array[Card]:
	if not can_use(action):
		return []
	match action:
		ActionKind.Kind.PARTIAL_REVEAL, ActionKind.Kind.FULL_REVEAL:
			return _round.window_subjects()
		ActionKind.Kind.LOOK_AHEAD:
			return []
	return _round.cards_in_play()


## The questions a partial reveal can ask about the card with this id.
func questions(card_id: int) -> Array[PartialQuestion.Kind]:
	var card: Card = _target(ActionKind.Kind.PARTIAL_REVEAL, card_id)
	if card == null:
		return []
	return _round.questions(card)


## Answers each question about the card, in order. Asks at most the kit's
## questions per reveal, and only questions this game offers on the card.
## Empty when refused.
func partial_reveal(card_id: int, asked: Array[PartialQuestion.Kind]) -> Array[bool]:
	var card: Card = _target(ActionKind.Kind.PARTIAL_REVEAL, card_id)
	if card == null or asked.is_empty() or asked.size() > _kit.questions_per_reveal:
		return []
	var offered: Array[PartialQuestion.Kind] = _round.questions(card)
	for question: PartialQuestion.Kind in asked:
		if question not in offered:
			return []
	var answers: Array[bool] = []
	for question: PartialQuestion.Kind in asked:
		answers.append(_round.answer(question, card))
	_record(ActionKind.Kind.PARTIAL_REVEAL, [card_id])
	return answers


## A copy of the card as it reads now, or null when refused.
func full_reveal(card_id: int) -> Card:
	var card: Card = _target(ActionKind.Kind.FULL_REVEAL, card_id)
	if card == null:
		return null
	_record(ActionKind.Kind.FULL_REVEAL, [card_id])
	return card.copy()


## Copies of the next cards off the pile, this hand only. Empty when refused.
func look_ahead() -> Array[Card]:
	if not can_use(ActionKind.Kind.LOOK_AHEAD):
		return []
	var seen: Array[Card] = []
	var ids: Array[int] = []
	for card: Card in _round.upcoming(LOOK_AHEAD_CARDS):
		seen.append(card.copy())
		ids.append(card.id)
	_record(ActionKind.Kind.LOOK_AHEAD, ids)
	return seen


## Puts symbol on the card for the rest of the run (spec §4.3), overwriting
## any old one. The owned deck keeps it; the card in play shows it now.
func mark(card_id: int, symbol: int) -> bool:
	var card: Card = _target(ActionKind.Kind.MARK, card_id)
	if card == null or symbol < 0 or symbol >= _kit.symbols:
		return false
	if not _deck.mark(card_id, symbol):
		return false
	_round.mark_card(card_id, symbol)
	_session.marks_made += 1
	_record(ActionKind.Kind.MARK, [card_id])
	return true


## Symbol by card id for every marked card in play, face-down ones included
## (spec §4.3, §2.5).
func visible_marks() -> Dictionary[int, int]:
	var marks: Dictionary[int, int] = {}
	for card: Card in _round.cards_in_play():
		if card.is_marked():
			marks[card.id] = card.symbol
	return marks


## The targetable card with this id, or null.
func _target(action: ActionKind.Kind, card_id: int) -> Card:
	for card: Card in targets(action):
		if card.id == card_id:
			return card
	return null


func _record(action: ActionKind.Kind, card_ids: Array[int]) -> void:
	used.append(ActionUse.new(action, _round.window_number, card_ids))
