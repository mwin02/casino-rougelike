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
const WINDOW_TAGS: Dictionary[BaccaratRound.WindowKind, String] = {
	BaccaratRound.WindowKind.INITIAL: "Second cards",
	BaccaratRound.WindowKind.PLAYER_THIRD: "Player's third",
	BaccaratRound.WindowKind.BANKER_THIRD: "Banker's third",
}
const WINDOW_NOTES: Dictionary[BaccaratRound.WindowKind, String] = {
	BaccaratRound.WindowKind.INITIAL: "Both second cards are down.",
	BaccaratRound.WindowKind.PLAYER_THIRD: "The player's third card is about to be dealt.",
	BaccaratRound.WindowKind.BANKER_THIRD: "The banker's third card is about to be dealt.",
}
const OUTCOME_TEXT: Dictionary[BaccaratRound.Outcome, String] = {
	BaccaratRound.Outcome.PLAYER: "Player wins",
	BaccaratRound.Outcome.BANKER: "Banker wins",
	BaccaratRound.Outcome.TIE: "Tie",
}


func card_lines() -> PackedStringArray:
	var rnd: BaccaratRound = _round
	return [_hand_line("Player", rnd.player_hand), _hand_line("Banker", rnd.banker_hand)]


func card_groups() -> Array[CardGroup]:
	var rnd: BaccaratRound = _round
	var groups: Array[CardGroup] = [
		CardGroup.new(CardGroup.Role.PLAYER, "Player", _views(rnd.player_hand.cards)),
		CardGroup.new(CardGroup.Role.BANKER, "Banker", _views(rnd.banker_hand.cards)),
	]
	if rnd.second_cards_shown:
		groups[0].total_text = str(rnd.player_hand.total())
		groups[1].total_text = str(rnd.banker_hand.total())
	# The bet sits under the side it's on; a tie bet gets a spot of its own.
	if rnd.side == BaccaratRound.BetSide.TIE:
		groups.append(CardGroup.new(CardGroup.Role.TIE, SIDE_NAMES[rnd.side], []))
	var on: CardGroup = groups[rnd.side]
	on.chips = rnd.stake * StakeVM.CHIPS_AT_MIN / rnd.limits.table_min
	on.bet_text = MoneyFormat.format(rnd.stake)
	return groups


func phase_text() -> String:
	var rnd: BaccaratRound = _round
	match rnd.phase:
		BaccaratRound.Phase.WINDOW:
			return WINDOW_TEXT[rnd.window]
		BaccaratRound.Phase.ADJUST:
			return "Adjust"
	return ""


func window_tag() -> String:
	var rnd: BaccaratRound = _round
	return WINDOW_TAGS.get(rnd.window, "")


func window_note() -> String:
	var rnd: BaccaratRound = _round
	return WINDOW_NOTES.get(rnd.window, "")


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


func proceed_label() -> String:
	var rnd: BaccaratRound = _round
	var initial: bool = rnd.window == BaccaratRound.WindowKind.INITIAL
	return "Turn cards" if initial or rnd.phase == BaccaratRound.Phase.ADJUST else "Deal card"


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
