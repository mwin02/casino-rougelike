class_name PlannedChange
extends RefCounted
## A manipulation before it's made (spec §8): the cards it rewrites, their
## new faces, and what the player will know after. HandActions prices its
## side-bet heat from it for the preview and again when it's made.

var action: ActionKind.Kind
var cards: Array[Card] = []
var ranks: Array[int] = []
var suits: Array[Card.Suit] = []
var view: SideBetView


func _init(p_action: ActionKind.Kind, p_view: SideBetView) -> void:
	action = p_action
	view = p_view


func add(card: Card, rank: int, suit: Card.Suit) -> void:
	cards.append(card)
	ranks.append(rank)
	suits.append(suit)
