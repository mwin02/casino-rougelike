class_name HandActions
extends RefCounted
## The window actions for one hand (spec §2, §2.5). Actions work only while
## the round has a window open and the kit has them unlocked. Reveals target
## the window's face-down subject cards; marks and manipulation can target
## any card in play. Every action taken is recorded in used and charged to
## heat as it lands (spec §1.4).
##
## A manipulation changes the round's card for this hand, records the change
## on the layer, and locks the bet (§2.2). Until the hand ends, a consumable
## can keep the change: Masking Tape for the session, a Cold Seal or an Ink
## charge for good. finish() ends the hand.

## §2.3: look ahead shows this many cards.
const LOOK_AHEAD_CARDS: int = 2

var used: Array[ActionUse] = []
var heat: HandHeat

var _round: GameRound
var _deck: Deck
var _layer: ManipulationLayer
var _kit: ActionKit
var _session: ActionSession
## Every card changed this hand, as the round's own card, first change first.
var _changed: Array[Card] = []
## Ids of cards the player has seen that aren't face up: revealed, looked
## ahead at, or palmed. Side-bet values read it (§8).
var _seen: Dictionary[int, bool] = {}


func _init(
	p_round: GameRound,
	deck: Deck,
	layer: ManipulationLayer,
	kit: ActionKit,
	session: ActionSession,
	p_heat: HandHeat
) -> void:
	_round = p_round
	heat = p_heat
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


## The heat action would cost if taken now.
func cost_of(action: ActionKind.Kind) -> float:
	return heat.cost_of(action, _round.window_number)


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
	_seen[card_id] = true
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
		_seen[card.id] = true
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
	_record(ActionKind.Kind.MARK, [card_id])
	_session.marks_made += 1
	return true


## Moves the card one rank up (step 1) or down (step -1). No wrap: a King
## can't go up, an Ace can't go down.
func nudge(card_id: int, step: int) -> bool:
	var card: Card = _target(ActionKind.Kind.NUDGE, card_id)
	if card == null or absi(step) != 1 or not Card.is_valid_rank(card.rank + step):
		return false
	return _change(ActionKind.Kind.NUDGE, card, card.rank + step, card.suit)


## Changes the card's suit to a different one.
func recolour(card_id: int, suit: Card.Suit) -> bool:
	var card: Card = _target(ActionKind.Kind.RECOLOUR, card_id)
	if card == null or card.suit == suit:
		return false
	return _change(ActionKind.Kind.RECOLOUR, card, card.rank, suit)


## Two cards in play trade identities. Marks stay on the physical cards.
func switch_cards(a_id: int, b_id: int) -> bool:
	var a: Card = _target(ActionKind.Kind.SWITCH, a_id)
	var b: Card = _target(ActionKind.Kind.SWITCH, b_id)
	if a == null or b == null or a_id == b_id:
		return false
	var a_rank: int = a.rank
	var a_suit: Card.Suit = a.suit
	# Each card now wears the other's face, and whether the player knew it.
	var a_seen: bool = _sees(a)
	_set_seen(a_id, _sees(b))
	_set_seen(b_id, a_seen)
	_layer.switch_cards(a, b)
	_round.rewrite_card(a_id, b.rank, b.suit)
	_round.rewrite_card(b_id, a_rank, a_suit)
	_manipulated(ActionKind.Kind.SWITCH, [a, b])
	return true


## The card becomes any card. Once per table session.
func palm(card_id: int, rank: int, suit: Card.Suit) -> bool:
	var card: Card = _target(ActionKind.Kind.PALM, card_id)
	if card == null or not Card.is_valid_rank(rank):
		return false
	_session.palm_used = true
	_seen[card_id] = true
	return _change(ActionKind.Kind.PALM, card, rank, suit)


## Masking Tape: this hand's change to the card lasts the table session.
func tape(card_id: int) -> bool:
	if _kit.masking_tape <= 0 or not _layer.tape(card_id):
		return false
	_kit.masking_tape -= 1
	return true


## Cold Seal: this hand's change to the card becomes a deck edit.
func seal(card_id: int) -> bool:
	if _kit.cold_seals <= 0:
		return false
	if not _layer.make_permanent(card_id, _deck, DeckEdit.Kind.COLD_SEAL):
		return false
	_kit.cold_seals -= 1
	return true


## A Permanent Ink charge: like a Cold Seal, recorded as an Ink edit.
func ink(card_id: int) -> bool:
	if _kit.ink_charges <= 0:
		return false
	if not _layer.make_permanent(card_id, _deck, DeckEdit.Kind.PERMANENT_INK):
		return false
	_kit.ink_charges -= 1
	return true


## Cards changed this hand that a consumable can still keep, as they read
## now. A card that has left play still counts: the change was made this hand.
func keepable_cards() -> Array[Card]:
	var result: Array[Card] = []
	for card: Card in _changed:
		if _layer.has_hand_change(card.id):
			result.append(card)
	return result


## The hand is over: this hand's untaped, unsealed changes revert.
func finish() -> void:
	_layer.end_hand()


## Symbol by card id for every marked card in play, face-down ones included
## (spec §4.3, §2.5).
func visible_marks() -> Dictionary[int, int]:
	var marks: Dictionary[int, int] = {}
	for card: Card in _round.cards_in_play():
		if card.is_marked():
			marks[card.id] = card.symbol
	return marks


## The side bets' value now (§8): their expected net in dollars from what
## the player can see.
func side_bets_value() -> float:
	var total: float = 0.0
	for bet: SideBet in _round.side_bets:
		total += _round.side_bet_value(bet, _seen)
	return total


func _sees(card: Card) -> bool:
	return _seen.has(card.id) or _round.is_face_up(card)


func _set_seen(card_id: int, value: bool) -> void:
	if value:
		_seen[card_id] = true
	else:
		_seen.erase(card_id)


## The targetable card with this id, or null.
func _target(action: ActionKind.Kind, card_id: int) -> Card:
	for card: Card in targets(action):
		if card.id == card_id:
			return card
	return null


func _change(action: ActionKind.Kind, card: Card, rank: int, suit: Card.Suit) -> bool:
	_layer.change(card.id, rank, suit)
	_round.rewrite_card(card.id, rank, suit)
	_manipulated(action, [card])
	return true


func _manipulated(action: ActionKind.Kind, cards: Array[Card]) -> void:
	_round.lock_bet()
	var ids: Array[int] = []
	for card: Card in cards:
		ids.append(card.id)
		if card not in _changed:
			_changed.append(card)
	_record(action, ids)


func _record(action: ActionKind.Kind, card_ids: Array[int]) -> void:
	var use: ActionUse = ActionUse.new(action, _round.window_number, card_ids)
	used.append(use)
	heat.charge(use)
