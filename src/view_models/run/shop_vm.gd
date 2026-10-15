class_name ShopVM
extends RefCounted
## A shop's shelf (block U4, spec §6.4, §9): three items the player doesn't
## own, Masking Tape and Cold Seals, and extra hands for the next floor,
## each priced at this floor; the bankroll against the quota, and what a
## picked item would do to it; and the kit's slots. The mid-floor shop and
## the end shop both stand on it; the end shop never spends below its
## reserve (§6.5).

const BUY: String = "Buy"
const NO_SLOT: String = "No free slot"
const SHORT: String = "Can't afford"
const OVER_RESERVE: String = "Over floor"
const SOLD_OUT: String = "Sold out"

var _owner: RunVM
var _run: Run
var _floor: Floor
var _shop: ShopStop
## Purchases never take the bankroll below this.
var _reserve: int
var _picked: ItemKind.Kind
var _has_pick: bool = false


## owner's run is at a shop.
func _init(owner: RunVM, reserve: int = 0) -> void:
	_owner = owner
	_run = owner.run
	_floor = _run.floor
	_shop = _floor.shop
	_reserve = reserve
	if not _shop.offers.is_empty():
		pick(_shop.offers[0])


func hud() -> FloorHudVM:
	return FloorHudVM.new(_run)


## "FLOOR 1 PRICES".
func prices_text() -> String:
	return "FLOOR %d PRICES" % _run.state.floor_number


## The bankroll as the shop holds it, against the quota.
func money() -> ShopMoney:
	return ShopMoney.new(_shop.bankroll(), _floor.quota)


func items() -> Array[ShopItemRow]:
	var rows: Array[ShopItemRow] = []
	for item: ItemKind.Kind in _shop.offers:
		var row: ShopItemRow = ShopItemRow.new()
		row.info = ItemInfo.of(item, _run.config())
		row.price = _shop.item_price(item)
		row.price_text = MoneyFormat.format(row.price)
		row.gap_after_text = money().short_text(row.price)
		row.can_buy = _shop.can_buy_item(item)
		row.verb = BUY if row.can_buy else _item_block(row.price)
		row.picked = _has_pick and item == _picked
		rows.append(row)
	return rows


## Picks the item whose purchase is previewed.
func pick(item: ItemKind.Kind) -> void:
	if item in _shop.offers:
		_picked = item
		_has_pick = true


## The picked item's row, or null once it's bought or with nothing on sale.
func picked() -> ShopItemRow:
	for row: ShopItemRow in items():
		if row.picked:
			return row
	return null


## "IF YOU BUY POKER FACE". Empty with nothing picked.
func preview_title() -> String:
	var row: ShopItemRow = picked()
	return "" if row == null else "IF YOU BUY " + row.info.name.to_upper()


## The bankroll after the picked purchase.
func preview_bankroll_text() -> String:
	var row: ShopItemRow = picked()
	return "" if row == null else MoneyFormat.format(money().bankroll - row.price)


## Short of the quota after the picked purchase.
func preview_gap_text() -> String:
	var row: ShopItemRow = picked()
	return "" if row == null else row.gap_after_text


## The bankroll bar with the picked purchase striped (ShopMoney.shares).
func preview_shares() -> Vector2:
	var row: ShopItemRow = picked()
	return money().shares(0 if row == null else row.price)


func buy_item(item: ItemKind.Kind) -> void:
	if _shop.buy_item(item):
		_has_pick = false
		if not _shop.offers.is_empty():
			pick(_shop.offers[0])
		_owner.step_done()


func consumables() -> Array[ConsumableRow]:
	var rules: ItemRules = ItemRules.from_config(_run.config())
	return [
		_consumable(
			ConsumableRow.Kind.TAPE, _shop.tape_price(), _shop.tape_stock,
			rules.masking_tape_stock, _run.kit.masking_tape, _shop.can_buy_tape()
		),
		_consumable(
			ConsumableRow.Kind.SEAL, _shop.seal_price(), _shop.seal_stock,
			rules.cold_seal_stock, _run.kit.cold_seals, _shop.can_buy_seal()
		),
	]


func buy_consumable(kind: ConsumableRow.Kind) -> void:
	var bought: bool = _shop.buy_tape() if kind == ConsumableRow.Kind.TAPE else _shop.buy_seal()
	if bought:
		_owner.step_done()


func hands() -> ShopHands:
	var hands: ShopHands = ShopHands.new()
	hands.title = "Extra hands for floor %d" % (_run.state.floor_number + 1)
	hands.bought = _shop.extra_hands
	hands.cap = _run.config().get_int("clock", "extra_hands_cap")
	hands.price_text = MoneyFormat.format(_shop.extra_hand_price())
	hands.can_buy = _shop.can_buy_extra_hand()
	hands.verb = BUY
	if not hands.can_buy:
		hands.verb = SOLD_OUT if hands.bought >= hands.cap else _money_block()
	return hands


func buy_hand() -> void:
	if _shop.buy_extra_hand():
		_owner.step_done()


func slots() -> Array[ItemSlot]:
	return ItemSlot.of(_run.kit, _run.config())


func slots_text() -> String:
	return ItemSlot.count_text(_run.kit, _run.config())


## Leaves the shop for the map.
func leave() -> void:
	if _floor.leave():
		_owner.step_done()


func _consumable(
	kind: ConsumableRow.Kind, price: int, stock: int, opened_with: int, held: int, can_buy: bool
) -> ConsumableRow:
	var row: ConsumableRow = ConsumableRow.new()
	row.kind = kind
	row.name = ConsumableRow.NAMES[kind]
	row.effect = ConsumableRow.EFFECTS[kind]
	row.price_text = MoneyFormat.format(price)
	row.stock_text = "%d / %d" % [stock, opened_with]
	row.held = held
	row.can_buy = can_buy
	row.verb = BUY if can_buy else (SOLD_OUT if stock <= 0 else _money_block())
	return row


## Why an item can't be bought.
func _item_block(_price: int) -> String:
	if not _run.kit.has_free_slot(ItemRules.from_config(_run.config())):
		return NO_SLOT
	return _money_block()


## Why money stops a purchase: the reserve at the end shop, else the bankroll.
func _money_block() -> String:
	return OVER_RESERVE if _reserve > 0 else SHORT
