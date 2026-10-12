class_name LegendRow
extends RefCounted
## One of the player's symbols on the deck screen's legend (spec §4.4): how
## many cards carry it. What it means is up to the player (§4.3).

var symbol: int
## "Star".
var name: String
var count: int
## The legend's filter is on this symbol.
var chosen: bool


func _init(p_symbol: int, p_count: int, p_chosen: bool) -> void:
	symbol = p_symbol
	name = CardText.symbol_word(p_symbol)
	count = p_count
	chosen = p_chosen
