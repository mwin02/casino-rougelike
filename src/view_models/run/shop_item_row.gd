class_name ShopItemRow
extends RefCounted
## One item on a shop's shelf (spec §9): what it is, its price, what buying
## it would leave short of the quota, and whether it can be bought now.

var info: ItemInfo
var price: int
## "$14,000".
var price_text: String
## Short of the quota after buying: "$57,500". "$0" at or over it.
var gap_after_text: String
var can_buy: bool
## "Buy", or why not: "No free slot".
var verb: String
## The one whose purchase the screen previews.
var picked: bool
