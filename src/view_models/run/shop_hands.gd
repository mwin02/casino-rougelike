class_name ShopHands
extends RefCounted
## Extra hands for the next floor's clock, as a shop sells them (spec §6.4).

## "Extra hands for floor 2".
var title: String
var bought: int
var cap: int
var price_text: String
var can_buy: bool
## "Buy", or why not.
var verb: String


## "+3 of 10 bought".
func text() -> String:
	return "+%d of %d bought" % [bought, cap]
