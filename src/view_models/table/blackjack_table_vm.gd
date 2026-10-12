class_name BlackjackTableVM
extends GameTableVM
## A blackjack hand on the debug table (spec §3.1). The hole card is face
## down until the hand resolves. With split hands, each gets a line and the
## one being played is marked. Insurance takes the largest stake allowed or
## half of it; it's offered from the hole-card window too, and pressing it
## there closes the window first.

enum Play { HIT, STAND, DOUBLE, SPLIT, INSURE_MAX, INSURE_HALF }

const OUTCOME_TEXT: Dictionary[BlackjackHand.Outcome, String] = {
	BlackjackHand.Outcome.NONE: "",
	BlackjackHand.Outcome.NATURAL: "Blackjack!",
	BlackjackHand.Outcome.WIN: "You win",
	BlackjackHand.Outcome.LOSE: "You lose",
	BlackjackHand.Outcome.PUSH: "Push",
	BlackjackHand.Outcome.PLAYER_BUST: "Bust",
	BlackjackHand.Outcome.DEALER_BUST: "Dealer busts",
}
const WINDOW_TEXT: Dictionary[BlackjackRound.WindowKind, String] = {
	BlackjackRound.WindowKind.HOLE_CARD: "Window: hole card",
	BlackjackRound.WindowKind.BEFORE_HIT: "Window: next card",
	BlackjackRound.WindowKind.FINAL: "Window: final",
}
const WINDOW_TAGS: Dictionary[BlackjackRound.WindowKind, String] = {
	BlackjackRound.WindowKind.HOLE_CARD: "Hole card",
	BlackjackRound.WindowKind.BEFORE_HIT: "Incoming card",
	BlackjackRound.WindowKind.FINAL: "Final",
}
const WINDOW_NOTES: Dictionary[BlackjackRound.WindowKind, String] = {
	BlackjackRound.WindowKind.HOLE_CARD: "The dealer's hole card is down.",
	BlackjackRound.WindowKind.BEFORE_HIT: "Your next card is about to be dealt.",
	BlackjackRound.WindowKind.FINAL: "The hole card and the next card off the deck are down.",
}
const PROCEED_LABELS: Dictionary[BlackjackRound.WindowKind, String] = {
	BlackjackRound.WindowKind.HOLE_CARD: "Play hand",
	BlackjackRound.WindowKind.BEFORE_HIT: "Deal card",
	BlackjackRound.WindowKind.FINAL: "Dealer plays",
}
const ACTIVE_MARK: String = "> "
const IDLE_MARK: String = "  "
const SEPARATOR: String = " | "


## The dealer, then each player hand.
func card_lines() -> PackedStringArray:
	var rnd: BlackjackRound = _round
	var dealer: String = "Dealer: " + _cards_text(rnd.dealer_hand.cards)
	if rnd.is_resolved():
		dealer += " (%s)" % _total(rnd.dealer_hand)
	var lines: PackedStringArray = [dealer]
	var several: bool = rnd.hands.size() > 1
	for i: int in rnd.hands.size():
		var hand: BlackjackHand = rnd.hands[i]
		var text: String = "%s (%s)" % [_cards_text(hand.cards), _total(hand)]
		if not several:
			lines.append("You: " + text)
			continue
		var mark: String = ""
		if not rnd.is_resolved():
			mark = ACTIVE_MARK if i == rnd.active_hand_index else IDLE_MARK
		lines.append("%sHand %d: %s" % [mark, i + 1, text])
	return lines


## The dealer, then each player hand; the one being played is active.
func card_groups() -> Array[CardGroup]:
	var rnd: BlackjackRound = _round
	var dealer: CardGroup = CardGroup.new(
		CardGroup.Role.DEALER, "Dealer", _views(rnd.dealer_hand.cards)
	)
	if rnd.is_resolved():
		dealer.total_text = _total(rnd.dealer_hand)
	var groups: Array[CardGroup] = [dealer]
	var several: bool = rnd.hands.size() > 1
	for i: int in rnd.hands.size():
		var hand: BlackjackHand = rnd.hands[i]
		var label: String = "Hand %d" % (i + 1) if several else "You"
		var group: CardGroup = CardGroup.new(CardGroup.Role.PLAYER, label, _views(hand.cards))
		group.total_text = _total(hand)
		group.bet = hand.stake
		group.active = several and not rnd.is_resolved() and i == rnd.active_hand_index
		groups.append(group)
	var final: bool = rnd.window == BlackjackRound.WindowKind.FINAL
	_incoming(groups, "Next card" if final else "Incoming card")
	return groups


func phase_text() -> String:
	var rnd: BlackjackRound = _round
	match rnd.phase:
		BlackjackRound.Phase.WINDOW:
			return WINDOW_TEXT[rnd.window]
		BlackjackRound.Phase.ADJUST:
			return "Adjust"
		BlackjackRound.Phase.PLAYER_TURN:
			return "Your turn"
	return ""


func window_tag() -> String:
	var rnd: BlackjackRound = _round
	return WINDOW_TAGS.get(rnd.window, "")


func window_note() -> String:
	var rnd: BlackjackRound = _round
	return WINDOW_NOTES.get(rnd.window, "")


## One outcome per hand.
func outcome_text() -> String:
	var rnd: BlackjackRound = _round
	if not rnd.is_resolved():
		return ""
	var outcomes: PackedStringArray = []
	for hand: BlackjackHand in rnd.hands:
		outcomes.append(OUTCOME_TEXT[hand.outcome])
	return SEPARATOR.join(outcomes)


func bet_text() -> String:
	var rnd: BlackjackRound = _round
	var text: String = super()
	if rnd.insurance_stake > 0:
		text += " (insurance %s)" % MoneyFormat.format(rnd.insurance_stake)
	return text


func play_choices() -> Array[Choice]:
	var rnd: BlackjackRound = _round
	# Insurance is sized on the placed bet, so it waits for a pending one.
	var insure: bool = rnd.insurance_ahead() and not bet_pending
	return [
		Choice.new("Hit", rnd.can_hit(), Play.HIT),
		Choice.new("Stand", rnd.can_stand(), Play.STAND),
		Choice.new("Double", rnd.can_double(), Play.DOUBLE),
		Choice.new("Split", rnd.can_split(), Play.SPLIT),
		Choice.new("Insure " + MoneyFormat.format(_insurance(Play.INSURE_MAX)), insure, Play.INSURE_MAX),
		Choice.new(
			"Insure " + MoneyFormat.format(_insurance(Play.INSURE_HALF)),
			insure and _insurance(Play.INSURE_HALF) > 0,
			Play.INSURE_HALF,
		),
	]


## On the player's turn Hit, Stand, Double and Split all show, pressable or
## not; insurance shows only while it can be taken.
func shown_choices() -> Array[Choice]:
	var rnd: BlackjackRound = _round
	var shown: Array[Choice] = []
	for choice: Choice in play_choices():
		var core: bool = choice.id <= Play.SPLIT and rnd.phase == BlackjackRound.Phase.PLAYER_TURN
		if choice.enabled or core:
			shown.append(choice)
	return shown


func proceed_label() -> String:
	var rnd: BlackjackRound = _round
	if rnd.phase == BlackjackRound.Phase.WINDOW:
		return PROCEED_LABELS.get(rnd.window, "Next")
	return "Play hand"


func play(id: int) -> void:
	var rnd: BlackjackRound = _round
	match id:
		Play.HIT:
			rnd.hit()
		Play.STAND:
			rnd.stand()
		Play.DOUBLE:
			rnd.double()
		Play.SPLIT:
			rnd.split()
		Play.INSURE_MAX, Play.INSURE_HALF:
			if rnd.insurance_ahead():
				var amount: int = _insurance(id)
				close_window()
				rnd.insure(amount)


func closes_window(id: int) -> bool:
	return id in [Play.INSURE_MAX, Play.INSURE_HALF]


func can_proceed() -> bool:
	var rnd: BlackjackRound = _round
	return rnd.phase in [BlackjackRound.Phase.WINDOW, BlackjackRound.Phase.ADJUST]


func proceed() -> void:
	var rnd: BlackjackRound = _round
	rnd.proceed()


## Everything dealt is face up but the hole card, until the hand resolves.
func _is_face_up(card: Card) -> bool:
	var rnd: BlackjackRound = _round
	if card == rnd.dealer_hand.cards[1]:
		return rnd.is_resolved()
	if card in rnd.dealer_hand.cards:
		return true
	for hand: BlackjackHand in rnd.hands:
		if card in hand.cards:
			return true
	return false


## The largest insurance stake, or half of it (rounded down).
func _insurance(id: int) -> int:
	var rnd: BlackjackRound = _round
	var most: int = rnd.insurance_max()
	return most if id == Play.INSURE_MAX else most / 2


func _total(hand: BlackjackHand) -> String:
	return ("soft %d" if hand.is_soft() else "%d") % hand.total()
