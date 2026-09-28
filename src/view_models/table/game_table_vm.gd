class_name GameTableVM
extends RefCounted
## What one game's hand looks like on the debug table: its cards, phase,
## outcome and game buttons. Each game fills these in. It keeps its round
## after the hand is settled, so the finished hand stays on screen.
##
## A card reads "??" unless it's face up, shows its mark even face down
## (spec §2.5) and wears tape when taped (§2.3).

## True while the table holds a pending bet (TableBetVM) that differs from
## the bet placed. Buttons priced on the placed bet wait or drop the price.
var bet_pending: bool = false

var _round: GameRound
var _layer: ManipulationLayer


func _init(p_round: GameRound, layer: ManipulationLayer) -> void:
	_round = p_round
	_layer = layer


## The view model for rnd's game.
static func for_round(rnd: GameRound, layer: ManipulationLayer) -> GameTableVM:
	if rnd is BaccaratRound:
		return BaccaratTableVM.new(rnd, layer)
	if rnd is BlackjackRound:
		return BlackjackTableVM.new(rnd, layer)
	if rnd is HighLowRound:
		return HighLowTableVM.new(rnd, layer)
	return GameTableVM.new(rnd, layer)


func game_round() -> GameRound:
	return _round


## How the table writes card, as ActionPicker's card label.
func card_label(card: Card) -> String:
	return CardText.name(card, not _is_face_up(card), _layer.is_taped(card.id))


## One line per hand or side, e.g. "Player: 9S KD (9)".
func card_lines() -> PackedStringArray:
	return []


func phase_text() -> String:
	return ""


## Empty until the hand settles.
func outcome_text() -> String:
	return ""


## The bet as the game puts it, e.g. "Bet $1,000 on Player".
func bet_text() -> String:
	return "Bet " + MoneyFormat.format(_round.total_bet())


## The game's own buttons, e.g. Hit and Stand, or a side switch.
func play_choices() -> Array[Choice]:
	return []


func play(_id: int) -> void:
	pass


## True in a window or adjust that Next can close.
func can_proceed() -> bool:
	return false


func proceed() -> void:
	push_error("GameTableVM.proceed: not implemented for this game")


## True for a game button that closes the window before it acts (it acts
## in the adjust, or after it).
func closes_window(_id: int) -> bool:
	return false


## Closes the open window, if any, into the adjust after it.
func close_window() -> void:
	if _round.in_window() and _round.adjust_follows():
		proceed()


## Face-up cards. Cards not dealt yet are never face up.
func _is_face_up(_card: Card) -> bool:
	return true


func _cards_text(cards: Array[Card]) -> String:
	var names: PackedStringArray = []
	for card: Card in cards:
		names.append(card_label(card))
	return " ".join(names)
