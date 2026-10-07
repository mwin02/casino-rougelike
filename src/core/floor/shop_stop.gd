class_name ShopStop
extends RefCounted
## A shop stop (spec §6.4): extra hands for the next floor's clock, at most
## extra_hands_cap a floor, plus deck services when the stop offers them.
## All of it draws on one bankroll, which the caller reads back, and never
## spends it below the reserve.
##
## Once stocked (§9), it also sells a few items the player doesn't own,
## drawn by rarity weight with no item twice, each at its rarity's price and
## only into a free slot; and Masking Tape and Cold Seals, a small stock
## of each.

## §6.4: each rarity's price key in the shop section.
const PRICE_KEYS: Dictionary[ItemKind.Rarity, String] = {
	ItemKind.Rarity.COMMON: "common_pct",
	ItemKind.Rarity.UNCOMMON: "uncommon_pct",
	ItemKind.Rarity.RARE: "rare_pct",
}

## The stop's deck services, or null.
var services: DeckServices
## Extra hands bought this floor, this stop's included.
var extra_hands: int
## Items on sale, unbought. Empty until stocked.
var offers: Array[ItemKind.Kind] = []
## Consumables left to sell.
var tape_stock: int = 0
var seal_stock: int = 0

var _pricing: ShopPricing
var _extra_hand_pct: int
var _cap: int
var _reserve: int
var _config: TuneConfig
var _kit: ActionKit
var _item_rules: ItemRules
## The bankroll while there are no deck services to hold it.
var _bankroll: int


## extra_hands_bought: bought at earlier stops this floor. A stop with deck
## services takes their bankroll and gives them its reserve.
func _init(
	config: TuneConfig,
	pricing: ShopPricing,
	p_bankroll: int,
	reserve: int,
	extra_hands_bought: int,
	p_services: DeckServices = null
) -> void:
	_config = config
	_pricing = pricing
	_extra_hand_pct = config.get_int("shop", "extra_hand_pct")
	_cap = config.get_int("clock", "extra_hands_cap")
	_reserve = reserve
	_bankroll = p_bankroll
	extra_hands = extra_hands_bought
	services = p_services
	if services != null:
		services.reserve = reserve


## Draws the items on sale for kit's owner and fills the consumable stock.
func stock(kit: ActionKit, rules: ItemRules, rng: RandomNumberGenerator) -> void:
	_kit = kit
	_item_rules = rules
	tape_stock = rules.masking_tape_stock
	seal_stock = rules.cold_seal_stock
	offers.clear()
	var pool: Array[ItemKind.Kind] = []
	for item: ItemKind.Kind in ItemKind.Kind.values():
		if not kit.has_item(item) and _weight(item) > 0:
			pool.append(item)
	while offers.size() < rules.shop_item_offers and not pool.is_empty():
		var item: ItemKind.Kind = _draw(pool, rng)
		offers.append(item)
		pool.erase(item)


func item_price(item: ItemKind.Kind) -> int:
	return _pricing.price(_config.get_int("shop", PRICE_KEYS[ItemKind.RARITY[item]]))


func can_buy_item(item: ItemKind.Kind) -> bool:
	return (
		item in offers
		and _kit.has_free_slot(_item_rules)
		and bankroll() - item_price(item) >= _reserve
	)


func buy_item(item: ItemKind.Kind) -> bool:
	if not can_buy_item(item) or not _kit.add_item(item, _item_rules):
		return false
	_set_bankroll(bankroll() - item_price(item))
	offers.erase(item)
	return true


func tape_price() -> int:
	return _pricing.price(_config.get_int("shop", "masking_tape_pct"))


func seal_price() -> int:
	return _pricing.price(_config.get_int("shop", "cold_seal_pct"))


func can_buy_tape() -> bool:
	return tape_stock > 0 and bankroll() - tape_price() >= _reserve


func can_buy_seal() -> bool:
	return seal_stock > 0 and bankroll() - seal_price() >= _reserve


func buy_tape() -> bool:
	if not can_buy_tape():
		return false
	_set_bankroll(bankroll() - tape_price())
	tape_stock -= 1
	_kit.masking_tape += 1
	return true


func buy_seal() -> bool:
	if not can_buy_seal():
		return false
	_set_bankroll(bankroll() - seal_price())
	seal_stock -= 1
	_kit.cold_seals += 1
	return true


func bankroll() -> int:
	return services.bankroll if services != null else _bankroll


func extra_hand_price() -> int:
	return _pricing.price(_extra_hand_pct)


func can_buy_extra_hand() -> bool:
	return extra_hands < _cap and bankroll() - extra_hand_price() >= _reserve


func buy_extra_hand() -> bool:
	if not can_buy_extra_hand():
		return false
	_set_bankroll(bankroll() - extra_hand_price())
	extra_hands += 1
	return true


func _set_bankroll(value: int) -> void:
	if services != null:
		services.bankroll = value
	else:
		_bankroll = value


func _weight(item: ItemKind.Kind) -> int:
	return _item_rules.offer_weights[ItemKind.RARITY[item]]


## One item from pool, each as likely as its rarity's weight.
func _draw(pool: Array[ItemKind.Kind], rng: RandomNumberGenerator) -> ItemKind.Kind:
	var total: int = 0
	for item: ItemKind.Kind in pool:
		total += _weight(item)
	var roll: int = rng.randi_range(1, total)
	for item: ItemKind.Kind in pool:
		roll -= _weight(item)
		if roll <= 0:
			return item
	return pool[-1]
