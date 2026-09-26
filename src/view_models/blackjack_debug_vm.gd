class_name BlackjackDebugVM
extends RefCounted
## Everything the block 0 debug table shows. Deals each round from a fresh
## shuffle of the player's deck.

const HIDDEN_CARD: String = "??"
const OUTCOME_TEXT: Dictionary[BlackjackRound.Outcome, String] = {
	BlackjackRound.Outcome.NONE: "",
	BlackjackRound.Outcome.NATURAL: "Blackjack!",
	BlackjackRound.Outcome.WIN: "You win",
	BlackjackRound.Outcome.LOSE: "You lose",
	BlackjackRound.Outcome.PUSH: "Push",
	BlackjackRound.Outcome.PLAYER_BUST: "Bust",
	BlackjackRound.Outcome.DEALER_BUST: "Dealer busts",
}

var _rules: BlackjackRules
var _bet: int
var _deck: Deck
var _layer: ManipulationLayer = ManipulationLayer.new()
var _rng: GameRng
var _round: BlackjackRound
var _session_net: int = 0


func _init(rules: BlackjackRules, bet: int, deck: Deck, rng: GameRng) -> void:
	_rules = rules
	_bet = bet
	_deck = deck
	_rng = rng


func deal() -> void:
	deal_from(CardShuffle.shuffled(_deck.dealing_cards(_layer), _rng.stream(GameRng.Stream.SHUFFLE)))


func deal_from(pile: Array[Card]) -> void:
	if not can_deal():
		return
	_round = BlackjackRound.new(_rules, _bet, pile)
	_round.deal()
	_settle()


func hit() -> void:
	if can_hit():
		_round.hit()
		_settle()


func stand() -> void:
	if can_stand():
		_round.stand()
		_settle()


func can_deal() -> bool:
	return _round == null or _is_resolved()


func can_hit() -> bool:
	return _round != null and _round.state == BlackjackRound.State.PLAYER_TURN


func can_stand() -> bool:
	return can_hit()


func player_cards_text() -> String:
	if _round == null:
		return ""
	return _cards_text(_round.player_hand, false)


func dealer_cards_text() -> String:
	if _round == null:
		return ""
	return _cards_text(_round.dealer_hand, not _is_resolved())


func player_total_text() -> String:
	if _round == null:
		return ""
	return _total_text(_round.player_hand)


func dealer_total_text() -> String:
	if _round == null:
		return ""
	if not _is_resolved():
		return "?"
	return _total_text(_round.dealer_hand)


func outcome_text() -> String:
	if _round == null:
		return ""
	return OUTCOME_TEXT[_round.outcome]


func net_text() -> String:
	if _round == null or not _is_resolved():
		return ""
	return MoneyFormat.format_signed(_round.net())


func session_net_text() -> String:
	return MoneyFormat.format_signed(_session_net)


func bet_text() -> String:
	return "Bet " + MoneyFormat.format(_bet)


func _settle() -> void:
	if _is_resolved():
		_session_net += _round.net()
		_layer.end_hand()


func _is_resolved() -> bool:
	return _round.state == BlackjackRound.State.RESOLVED


func _cards_text(hand: BlackjackHand, hide_hole: bool) -> String:
	var names: PackedStringArray = []
	for i: int in hand.cards.size():
		names.append(HIDDEN_CARD if hide_hole and i == 1 else hand.cards[i].short_name())
	return " ".join(names)


func _total_text(hand: BlackjackHand) -> String:
	return ("soft %d" if hand.is_soft() else "%d") % hand.total()
