class_name CardView
extends RefCounted
## One card as the real table draws it. A face-down card carries no rank or
## suit, so the screen can't show them. Its mark still shows (spec §2.5);
## its tape doesn't (§2.3), or tape would mark the card for free.

const NO_RANK: int = 0

var id: int
## NO_RANK while face down.
var rank: int = NO_RANK
var suit: Card.Suit
var face_down: bool
## The player's mark, or Card.NO_SYMBOL.
var symbol: int
## Wears masking tape: its change lasts the table session. Never while
## face down.
var taped: bool
## Out of play but still on the table, e.g. a High or Low chain's past cards.
var dimmed: bool = false
## Face down on the table, but shown: the player has seen it this hand.
var peeked: bool = false


func _init(card: Card, p_face_down: bool, p_taped: bool) -> void:
	id = card.id
	face_down = p_face_down
	symbol = card.symbol
	taped = p_taped and not face_down
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
