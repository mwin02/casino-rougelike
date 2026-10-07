class_name GameRng
extends RefCounted
## Every random draw in a run comes from here. One run seed feeds independent
## named streams, so drawing from one (buying a table roll, say) never shifts
## another (the shuffles).

enum Stream { SHUFFLE, TABLE_ROLLS, CONSEQUENCE, LOOT, SHOP, FLOOR }

## Fixed per-stream offsets. Written out rather than hashed, so a run's
## streams never change with the enum order or the engine's hash().
const STREAM_SALT: Dictionary[Stream, int] = {
	Stream.SHUFFLE: 0x1F83_D9AB_5BE0_CD19,
	Stream.TABLE_ROLLS: 0x2B7E_1516_28AE_D2A6,
	Stream.CONSEQUENCE: 0x3C6E_F372_FE94_F82B,
	Stream.LOOT: 0x510E_527F_ADE6_82D1,
	Stream.SHOP: 0x9B05_688C_2B3E_6C1F,
	Stream.FLOOR: 0xCBBB_9D5D_C105_9ED8,
}

var run_seed: int

var _streams: Array[RandomNumberGenerator] = []


func _init(p_run_seed: int) -> void:
	run_seed = p_run_seed
	for s: int in Stream.values():
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = run_seed ^ STREAM_SALT[s as Stream]
		_streams.append(rng)


func stream(s: Stream) -> RandomNumberGenerator:
	return _streams[s]


## Stream states by name, so a save survives reordering the enum.
func to_dict() -> Dictionary:
	var states: Dictionary = {}
	for s: int in Stream.values():
		states[Stream.keys()[s]] = _streams[s].state
	return {"run_seed": run_seed, "states": states}


static func from_dict(saved: Dictionary) -> GameRng:
	var saved_seed: int = saved["run_seed"]
	var rng: GameRng = GameRng.new(saved_seed)
	var states: Dictionary = saved["states"]
	for s: int in Stream.values():
		rng._streams[s].state = states[Stream.keys()[s]]
	return rng
