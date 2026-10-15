class_name EndShopVM
extends RefCounted
## The end of a floor on screen (block U4, spec §6.2, §6.5, §11): how the
## quota check went, read from the floor's record; the bankroll over the
## reserve, the next floor's low-stakes minimum; the shop and deck services
## under tabs; and the elevator out.

enum Tab { ITEMS, CONSUMABLES, HANDS, SERVICES }

const TAB_NAMES: Dictionary[Tab, String] = {
	Tab.ITEMS: "Items",
	Tab.CONSUMABLES: "Consumables",
	Tab.HANDS: "Hands",
	Tab.SERVICES: "Services",
}
const MET: String = "Quota met"
const COVERED: String = "Short, marker covered it"
const ELEVATOR: String = "Take the elevator"

var tab: Tab = Tab.ITEMS

var _owner: RunVM
var _run: Run
var _floor: Floor
var _record: FloorRecord
var _shop: ShopVM
var _services: ServicesVM


## owner's run is at the end shop.
func _init(owner: RunVM) -> void:
	_owner = owner
	_run = owner.run
	_floor = _run.floor
	_record = _run.state.records[-1]
	_shop = ShopVM.new(owner, _floor.next_floor_min)
	_services = ServicesVM.new(owner, _floor.shop.services)


func shop() -> ShopVM:
	return _shop


func services() -> ServicesVM:
	return _services


## True while a deck service is being worked: the bench takes the shop's
## place.
func service_open() -> bool:
	return _services.selected() != ServicesVM.NONE


func check() -> QuotaStrip:
	var strip: QuotaStrip = QuotaStrip.new()
	strip.heading = "FLOOR %d · QUOTA CHECK" % _record.floor_number
	strip.short = _record.bankroll < _record.quota
	strip.title = COVERED if strip.short else MET
	strip.bankroll_text = MoneyFormat.format(_record.bankroll)
	strip.quota_text = "/ " + MoneyFormat.format(_record.quota)
	if _record.loan > 0:
		strip.lead = "Marker: house fronted " + MoneyFormat.format(_record.loan)
		strip.detail = _marker_detail()
	else:
		strip.lead = "Passed"
		strip.detail = (
			"%s over the quota · elevator key card awarded"
			% MoneyFormat.format(_record.bankroll - _record.quota)
		)
	return strip


func money() -> ReserveMoney:
	return ReserveMoney.new(
		_floor.shop.bankroll(), _floor.next_floor_min,
		maxi(_record.bankroll, _record.quota), _record.quota
	)


## One per tab, the open one selected; ids are Tab values.
func tabs() -> Array[Choice]:
	var result: Array[Choice] = []
	for each: Tab in TAB_NAMES:
		result.append(Choice.new(TAB_NAMES[each], true, each, each == tab))
	return result


func pick_tab(picked: Tab) -> void:
	tab = picked


## What the kit holds beside its items: "TAPE", "SEALS", "FLOOR 2 HANDS".
func held_labels() -> Array[String]:
	return ["TAPE", "SEALS", "FLOOR %d HANDS" % _next_floor()]


## Each held_labels count: "1", "0", "+3".
func held_values() -> Array[String]:
	return [
		str(_run.kit.masking_tape), str(_run.kit.cold_seals), "+%d" % _floor.shop.extra_hands,
	]


func elevator_text() -> String:
	return ELEVATOR


## "TO FLOOR 2 · QUOTA $714,375".
func next_text() -> String:
	return "TO FLOOR %d · QUOTA %s" % [_next_floor(), MoneyFormat.format(_next_quota())]


## Leaves the end shop and the floor for the elevator. An open Rummage is
## skipped.
func take_elevator() -> void:
	_services.cancel()
	if _floor.finish():
		_owner.step_done()


func _next_floor() -> int:
	return _record.floor_number + 1


## The next floor's quota, this floor's marker debt included (§11).
func _next_quota() -> int:
	var quotas: Array[int] = _run.config().get_int_list("floors", "quotas")
	return quotas[_record.floor_number] + Marker.owed(_run.config(), _record.loan)


## "repay $14,375 (loan + 25%) on floor 2 · floor 2 quota $714,375".
func _marker_detail() -> String:
	return "repay %s (loan + %d%%) on floor %d · floor %d quota %s" % [
		MoneyFormat.format(Marker.owed(_run.config(), _record.loan)),
		_run.config().get_int("marker", "interest_pct"),
		_next_floor(),
		_next_floor(),
		MoneyFormat.format(_next_quota()),
	]
