class_name ShopStop
extends RefCounted
## A shop stop (spec §6.4): extra hands for the next floor's clock, at most
## extra_hands_cap a floor, plus deck services when the stop offers them.
## Both draw on one bankroll, which the caller reads back, and never spend
## it below the reserve. Items and consumables arrive in block 13.

## The stop's deck services, or null.
var services: DeckServices
## Extra hands bought this floor, this stop's included.
var extra_hands: int

var _pricing: ShopPricing
var _extra_hand_pct: int
var _cap: int
var _reserve: int
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
	_pricing = pricing
	_extra_hand_pct = config.get_int("shop", "extra_hand_pct")
	_cap = config.get_int("clock", "extra_hands_cap")
	_reserve = reserve
	_bankroll = p_bankroll
	extra_hands = extra_hands_bought
	services = p_services
	if services != null:
		services.reserve = reserve


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
