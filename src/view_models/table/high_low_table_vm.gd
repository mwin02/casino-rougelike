class_name HighLowTableVM
extends GameTableVM
## A High or Low chain on the debug table (spec §3.3): the card up, the cards
## drawn before it, and the next card face down until it's called, so its
## mark stays in view (spec §2.5). Each call button
## shows how many of the remaining owned cards win it and what the chain is
## worth if it does. A call can be made from the window and adjust before it,
## which it closes first. A correct call leads to Bank or Continue.

enum Play { HIGHER, LOWER, BANK, CONTINUE }

const OUTCOME_TEXT: Dictionary[HighLowRound.Outcome, String] = {
	HighLowRound.Outcome.NONE: "",
	HighLowRound.Outcome.BANKED: "Banked",
	HighLowRound.Outcome.LOST: "Lost",
	HighLowRound.Outcome.TIE: "Tie: half kept",
}
const PHASE_TEXT: Dictionary[HighLowRound.Phase, String] = {
	HighLowRound.Phase.READY: "",
	HighLowRound.Phase.WINDOW: "Window: next card",
	HighLowRound.Phase.ADJUST: "Adjust",
	HighLowRound.Phase.CALL: "Call it",
	HighLowRound.Phase.DECIDE: "Bank or continue",
	HighLowRound.Phase.RESOLVED: "",
}


func card_lines() -> PackedStringArray:
	var rnd: HighLowRound = _round
	var lines: PackedStringArray = ["Up: " + card_label(rnd.current())]
	if rnd.cards.size() > 1:
		lines.append("Before: " + _cards_text(rnd.cards.slice(0, -1)))
	var upcoming: Array[Card] = rnd.upcoming(1)
	if rnd.call_ahead() and not upcoming.is_empty():
		lines.append("Next: " + card_label(upcoming[0]))
	return lines


func phase_text() -> String:
	var rnd: HighLowRound = _round
	return PHASE_TEXT[rnd.phase]


func outcome_text() -> String:
	var rnd: HighLowRound = _round
	return OUTCOME_TEXT[rnd.outcome]


func bet_text() -> String:
	var rnd: HighLowRound = _round
	return "Bet %s, chain %s" % [MoneyFormat.format(rnd.stake), MoneyFormat.format(rnd.chain_value)]


func play_choices() -> Array[Choice]:
	var rnd: HighLowRound = _round
	var deciding: bool = rnd.phase == HighLowRound.Phase.DECIDE
	return [
		_call_choice("Higher", HighLowRound.Direction.HIGHER, Play.HIGHER),
		_call_choice("Lower", HighLowRound.Direction.LOWER, Play.LOWER),
		Choice.new("Bank", deciding, Play.BANK),
		Choice.new("Continue", deciding, Play.CONTINUE),
	]


func play(id: int) -> void:
	var rnd: HighLowRound = _round
	match id:
		Play.HIGHER, Play.LOWER:
			if not rnd.call_ahead():
				return
			while rnd.phase != HighLowRound.Phase.CALL:
				rnd.proceed()
			var higher: bool = id == Play.HIGHER
			rnd.call_next(HighLowRound.Direction.HIGHER if higher else HighLowRound.Direction.LOWER)
		Play.BANK:
			rnd.bank()
		Play.CONTINUE:
			rnd.continue_chain()


func can_proceed() -> bool:
	var rnd: HighLowRound = _round
	return rnd.phase in [HighLowRound.Phase.WINDOW, HighLowRound.Phase.ADJUST]


func proceed() -> void:
	var rnd: HighLowRound = _round
	rnd.proceed()


## The card up and the chain's earlier cards are face up; the next isn't.
func _is_face_up(card: Card) -> bool:
	var rnd: HighLowRound = _round
	return card in rnd.cards


## "Higher 3/4 pays $1,240": winners of the remaining owned cards, and the
## chain value if it wins.
func _call_choice(label: String, direction: HighLowRound.Direction, id: int) -> Choice:
	var rnd: HighLowRound = _round
	if not rnd.call_ahead():
		return Choice.new(label, false, id)
	var text: String = "%s %d/%d pays %s" % [
		label,
		rnd.winners(direction),
		rnd.remaining(),
		MoneyFormat.format(rnd.value_if_won(direction)),
	]
	return Choice.new(text, true, id)
