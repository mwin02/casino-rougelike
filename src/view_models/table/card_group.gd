class_name CardGroup
extends RefCounted
## A set of cards the real table draws together: a hand, a baccarat side,
## or one spot in a High or Low chain.

enum Role { DEALER, PLAYER, BANKER, CHAIN_PAST, CARD_UP, NEXT_CARD }

var role: Role
var label: String
var cards: Array[CardView] = []
## "17", "soft 17", or empty while the total isn't showing.
var total_text: String = ""
## The hand being played, when there are several.
var active: bool = false


func _init(p_role: Role, p_label: String, p_cards: Array[CardView]) -> void:
	role = p_role
	label = p_label
	cards = p_cards
