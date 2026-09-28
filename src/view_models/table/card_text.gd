class_name CardText
extends RefCounted
## Cards as the debug table writes them: letter codes such as "7D", "??" face
## down, a mark's symbol even face down (spec §2.5), and "[T]" on a taped
## card (§2.3), which shows its tape whenever it's on screen.

const FACE_DOWN: String = "??"
const TAPE: String = "[T]"


static func name(card: Card, face_down: bool, taped: bool) -> String:
	var text: String = FACE_DOWN if face_down else card.short_name()
	if card.is_marked():
		text += symbol_name(card.symbol)
	if taped:
		text += TAPE
	return text


## Symbols are numbered from 0; the screen counts them from 1: "*1".
static func symbol_name(symbol: int) -> String:
	return "*%d" % (symbol + 1)
