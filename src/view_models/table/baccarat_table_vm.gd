class_name BaccaratTableVM
extends GameTableVM
## A baccarat hand on the debug table (spec §3.2). Both second cards are
## face down until the initial adjust closes; totals show once they turn
## over. The one game button switches Player ↔ Banker in an adjust; pressed
## in the window before it, it closes the window first.

enum Play { SWITCH_SIDE }

const SIDE_NAMES: Array[String] = ["Player", "Banker", "Tie"]
const WINDOW_TEXT: Dictionary[BaccaratRound.WindowKind, String] = {
	BaccaratRound.WindowKind.INITIAL: "Window: second cards",
	BaccaratRound.WindowKind.PLAYER_THIRD: "Window: player's third card",
	BaccaratRound.WindowKind.BANKER_THIRD: "Window: banker's third card",
}
const OUTCOME_TEXT: Dictionary[BaccaratRound.Outcome, String] = {
	BaccaratRound.Outcome.PLAYER: "Player wins",
	BaccaratRound.Outcome.BANKER: "Banker wins",
	BaccaratRound.Outcome.TIE: "Tie",
}


func card_lines() -> PackedStringArray:
	var rnd: BaccaratRound = _round
	return [_hand_line("Player", rnd.player_hand), _hand_line("Banker", rnd.banker_hand)]


func phase_text() -> String:
	var rnd: BaccaratRound = _round
	match rnd.phase:
		BaccaratRound.Phase.WINDOW:
			return WINDOW_TEXT[rnd.window]
		BaccaratRound.Phase.ADJUST:
			return "Adjust"
	return ""


func outcome_text() -> String:
	var rnd: BaccaratRound = _round
	if not rnd.is_resolved():
		return ""
	return OUTCOME_TEXT[rnd.outcome]


func bet_text() -> String:
	var rnd: BaccaratRound = _round
	return "Bet %s on %s" % [MoneyFormat.format(rnd.stake), SIDE_NAMES[rnd.side]]


func play_choices() -> Array[Choice]:
	var rnd: BaccaratRound = _round
	return [Choice.new("Switch side", rnd.switch_side_ahead(), Play.SWITCH_SIDE)]


func play(id: int) -> void:
	var rnd: BaccaratRound = _round
	if id == Play.SWITCH_SIDE and rnd.switch_side_ahead():
		close_window()
		rnd.switch_side()


func closes_window(id: int) -> bool:
	return id == Play.SWITCH_SIDE


func can_proceed() -> bool:
	var rnd: BaccaratRound = _round
	return rnd.phase in [BaccaratRound.Phase.WINDOW, BaccaratRound.Phase.ADJUST]


func proceed() -> void:
	var rnd: BaccaratRound = _round
	rnd.proceed()


## The second cards are face down until they turn over; a third card isn't
## dealt until its window closes.
func _is_face_up(card: Card) -> bool:
	var rnd: BaccaratRound = _round
	for hand: BaccaratHand in [rnd.player_hand, rnd.banker_hand]:
		var index: int = hand.cards.find(card)
		if index != -1:
			return index != 1 or rnd.second_cards_shown
	return false


func _hand_line(side: String, hand: BaccaratHand) -> String:
	var rnd: BaccaratRound = _round
	var line: String = "%s: %s" % [side, _cards_text(hand.cards)]
	if rnd.second_cards_shown:
		line += " (%d)" % hand.total()
	return line
