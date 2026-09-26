class_name BlackjackDebugVM
extends RefCounted
## Everything the debug table shows. Deals each round from a fresh shuffle of
## the player's deck. Windows and adjusts have no actions yet (block 5), so
## Next passes them. Insure always takes the largest stake allowed.

## Every button on the table.
enum Action { DEAL, NEXT, HIT, STAND, DOUBLE, SPLIT, INSURE }

const HIDDEN_CARD: String = "??"
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
## Marks the hand being played when there is more than one.
const ACTIVE_MARK: String = "> "
const IDLE_MARK: String = "  "
const HAND_SEPARATOR: String = " | "

var _rules: BlackjackRules
var _limits: BetLimits
var _deck: Deck
var _layer: ManipulationLayer = ManipulationLayer.new()
var _rng: GameRng
var _round: BlackjackRound
var _session_net: int = 0


func _init(rules: BlackjackRules, limits: BetLimits, deck: Deck, rng: GameRng) -> void:
	_rules = rules
	_limits = limits
	_deck = deck
	_rng = rng


func press(action: Action) -> void:
	if not can(action):
		return
	match action:
		Action.DEAL:
			_deal()
		Action.NEXT:
			_round.proceed()
			_settle()
		Action.HIT:
			_round.hit()
		Action.STAND:
			_round.stand()
			_settle()
		Action.DOUBLE:
			_round.double()
		Action.SPLIT:
			_round.split()
		Action.INSURE:
			_round.insure(_round.insurance_max())


func can(action: Action) -> bool:
	if action == Action.DEAL:
		return _round == null or _is_resolved()
	if _round == null:
		return false
	var allowed: bool = false
	match action:
		Action.NEXT:
			allowed = _round.phase in [BlackjackRound.Phase.WINDOW, BlackjackRound.Phase.ADJUST]
		Action.HIT:
			allowed = _round.can_hit()
		Action.STAND:
			allowed = _round.can_stand()
		Action.DOUBLE:
			allowed = _round.can_double()
		Action.SPLIT:
			allowed = _round.can_split()
		Action.INSURE:
			allowed = _round.can_insure()
	return allowed


## Deals a set pile instead of a shuffle, for tests.
func deal_from(pile: Array[Card]) -> void:
	if not can(Action.DEAL):
		return
	_round = BlackjackRound.new(_rules, _limits, pile)
	_round.deal()
	_settle()


func phase_text() -> String:
	if _round == null:
		return ""
	match _round.phase:
		BlackjackRound.Phase.WINDOW:
			return WINDOW_TEXT[_round.window]
		BlackjackRound.Phase.ADJUST:
			return "Adjust"
		BlackjackRound.Phase.PLAYER_TURN:
			return "Your turn"
	return ""


## One line per hand. With several hands in play, the active one is marked.
func player_cards_text() -> String:
	if _round == null:
		return ""
	var marked: bool = _round.hands.size() > 1 and not _is_resolved()
	var lines: PackedStringArray = []
	for i: int in _round.hands.size():
		var mark: String = ""
		if marked:
			mark = ACTIVE_MARK if i == _round.active_hand_index else IDLE_MARK
		lines.append(mark + _cards_text(_round.hands[i], false))
	return "\n".join(lines)


func dealer_cards_text() -> String:
	if _round == null:
		return ""
	return _cards_text(_round.dealer_hand, not _is_resolved())


func player_total_text() -> String:
	if _round == null:
		return ""
	var totals: PackedStringArray = []
	for hand: BlackjackHand in _round.hands:
		totals.append(_total_text(hand))
	return HAND_SEPARATOR.join(totals)


func dealer_total_text() -> String:
	if _round == null:
		return ""
	if not _is_resolved():
		return "?"
	return _total_text(_round.dealer_hand)


func outcome_text() -> String:
	if _round == null or not _is_resolved():
		return ""
	var outcomes: PackedStringArray = []
	for hand: BlackjackHand in _round.hands:
		outcomes.append(OUTCOME_TEXT[hand.outcome])
	return HAND_SEPARATOR.join(outcomes)


func net_text() -> String:
	if _round == null or not _is_resolved():
		return ""
	return MoneyFormat.format_signed(_round.net())


func session_net_text() -> String:
	return MoneyFormat.format_signed(_session_net)


## The opening bet between rounds; everything on the table during one.
func bet_text() -> String:
	var total: int = _limits.opening if _round == null else _round.total_bet()
	return "Bet " + MoneyFormat.format(total)


func insurance_text() -> String:
	if _round == null or _round.insurance_stake == 0:
		return ""
	return "Insurance " + MoneyFormat.format(_round.insurance_stake)


func _deal() -> void:
	deal_from(CardShuffle.shuffled(_deck.dealing_cards(_layer), _rng.stream(GameRng.Stream.SHUFFLE)))


func _settle() -> void:
	if _is_resolved():
		_session_net += _round.net()
		_layer.end_hand()


func _is_resolved() -> bool:
	return _round.phase == BlackjackRound.Phase.RESOLVED


func _cards_text(hand: BlackjackHand, hide_hole: bool) -> String:
	var names: PackedStringArray = []
	for i: int in hand.cards.size():
		names.append(HIDDEN_CARD if hide_hole and i == 1 else hand.cards[i].short_name())
	return " ".join(names)


func _total_text(hand: BlackjackHand) -> String:
	return ("soft %d" if hand.is_soft() else "%d") % hand.total()
