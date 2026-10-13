class_name CardText
extends RefCounted
## Cards as the debug table writes them: letter codes such as "7D", "??" face
## down, a mark's symbol even face down (spec §2.5), and "[T]" on a taped
## card (§2.3), which shows its tape whenever it's on screen.

const FACE_DOWN: String = "??"
const TAPE: String = "[T]"
const SUIT_WORDS: Array[String] = ["clubs", "diamonds", "hearts", "spades"]
const SYMBOL_WORDS: Array[String] = ["Star", "Moon", "Bolt", "Drop", "Ring"]


static func name(card: Card, face_down: bool, taped: bool) -> String:
	var text: String = FACE_DOWN if face_down else card.short_name()
	if card.is_marked():
		text += symbol_name(card.symbol)
	if taped:
		text += TAPE
	return text


## A card said aloud: "K of spades".
static func spoken(card: Card) -> String:
	return "%s of %s" % [Card.RANK_CODES[card.rank], SUIT_WORDS[card.suit]]


## A symbol by name on the real table: "Star". Past the named ones, "*6".
static func symbol_word(symbol: int) -> String:
	return SYMBOL_WORDS[symbol] if symbol < SYMBOL_WORDS.size() else symbol_name(symbol)


## A symbol's art, as Choice.icon names it: "cards/mark_1_star". Empty for a
## symbol with none.
static func symbol_icon(symbol: int) -> String:
	if symbol < 0 or symbol >= SYMBOL_WORDS.size():
		return ""
	return "cards/mark_%d_%s" % [symbol + 1, SYMBOL_WORDS[symbol].to_lower()]


## Symbols are numbered from 0; the screen counts them from 1: "*1".
static func symbol_name(symbol: int) -> String:
	return "*%d" % (symbol + 1)
