class_name Card
extends RefCounted
## A playing card. Rank 1 is the ace; 11, 12, 13 are J, Q, K.
## Block 1 extends this with edits and marks.

enum Suit { CLUBS, DIAMONDS, HEARTS, SPADES }

const RANK_CODES: Array[String] = [
	"", "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"
]
const SUIT_CODES: Array[String] = ["C", "D", "H", "S"]

var rank: int
var suit: Suit


func _init(p_rank: int, p_suit: Suit) -> void:
	rank = p_rank
	suit = p_suit


## Parses "A", "10", "KH", "10S". A missing suit means spades. Returns null on bad input.
static func parse(code: String) -> Card:
	var rank_code: String = code
	var suit_value: Suit = Suit.SPADES
	var suit_index: int = SUIT_CODES.find(code.right(1))
	if code.length() > 1 and suit_index != -1:
		rank_code = code.left(-1)
		suit_value = suit_index as Suit
	var rank_value: int = RANK_CODES.find(rank_code)
	if rank_value < 1:
		push_error("Card.parse: bad card code '%s'" % code)
		return null
	return Card.new(rank_value, suit_value)


func is_ace() -> bool:
	return rank == 1


## Letter code such as "KS" or "10H", the same form parse() reads. Letters, not
## suit symbols: the debug UI has no font with suit glyphs on iOS.
func short_name() -> String:
	return RANK_CODES[rank] + SUIT_CODES[suit]
