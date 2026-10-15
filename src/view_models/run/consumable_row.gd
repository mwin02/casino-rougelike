class_name ConsumableRow
extends RefCounted
## A consumable on a shop's shelf (spec §9): its price, the stock left of
## what the shop opened with, and how many the player holds.

enum Kind { TAPE, SEAL }

const NAMES: Dictionary[Kind, String] = { Kind.TAPE: "Masking Tape", Kind.SEAL: "Cold Seal" }
const EFFECTS: Dictionary[Kind, String] = {
	Kind.TAPE: "The change lasts the rest of the table session",
	Kind.SEAL: "The change becomes permanent, a deck edit",
}

var kind: Kind
var name: String
var effect: String
var price_text: String
## "3 / 4".
var stock_text: String
var held: int
var can_buy: bool
## "Buy", or why not: "Sold out".
var verb: String
