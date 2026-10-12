class_name CardView
extends RefCounted
## One card as the real table draws it. A face-down card carries no rank or
## suit, so the screen can't show them; its mark still shows (spec §2.5),
## and so does its tape (§2.3).

const NO_RANK: int = 0

var id: int
## NO_RANK while face down.
var rank: int = NO_RANK
var suit: Card.Suit
var face_down: bool
## The player's mark, or Card.NO_SYMBOL.
var symbol: int
## Wears a strip of masking tape: its change lasts the table session.
var taped: bool
## Out of play but still on the table, e.g. a High or Low chain's past cards.
var dimmed: bool = false


func _init(card: Card, p_face_down: bool, p_taped: bool) -> void:
	id = card.id
	face_down = p_face_down
	symbol = card.symbol
	taped = p_taped
	if not face_down:
		rank = card.rank
		suit = card.suit


## "A", "10", "K"; empty while face down.
func rank_text() -> String:
	return Card.RANK_CODES[rank]


func is_red() -> bool:
	return not face_down and suit in [Card.Suit.DIAMONDS, Card.Suit.HEARTS]


func is_marked() -> bool:
	return symbol != Card.NO_SYMBOL
