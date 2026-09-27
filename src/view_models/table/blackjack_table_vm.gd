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
	var insure: bool = rnd.insurance_ahead()
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
