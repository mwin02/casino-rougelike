class_name FloorClock
extends RefCounted
## The floor's pool of hands (spec §6.1). Only a hand played at a table
## spends one; back-room stops and standing up cost nothing.

var hands_left: int


func _init(hands: int) -> void:
	hands_left = hands


## The floor's pool plus extra hands bought on the floor before (§6.4).
static func from_config(config: TuneConfig, extra_hands: int = 0) -> FloorClock:
	return FloorClock.new(config.get_int("clock", "hands_per_floor") + extra_hands)


func is_out() -> bool:
	return hands_left <= 0


func tick() -> void:
	hands_left = maxi(hands_left - 1, 0)
