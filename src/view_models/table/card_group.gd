class_name CardGroup
extends RefCounted
## A set of cards the real table draws together: a hand, a baccarat side,
## or one spot in a High or Low chain.

## TIE is baccarat's tie spot: it has no cards, only the bet when it's on.
enum Role { DEALER, PLAYER, BANKER, CHAIN_PAST, CARD_UP, NEXT_CARD, TIE }

var role: Role
var label: String
var cards: Array[CardView] = []
## "17", "soft 17", or empty while the total isn't showing.
var total_text: String = ""
## The hand being played, when there are several.
var active: bool = false
## Chips riding on this group: the bet, when it's on this side. 0 otherwise.
var chips: int = 0
## The bet those chips stand for, e.g. "$1,000". Empty without chips.
var bet_text: String = ""


func _init(p_role: Role, p_label: String, p_cards: Array[CardView]) -> void:
	role = p_role
	label = p_label
	cards = p_cards
