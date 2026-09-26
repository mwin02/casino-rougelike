class_name GameRng
extends RefCounted
## Every random draw in a run comes from here. One run seed feeds independent
## named streams, so drawing from one (buying a table roll, say) never shifts
## another (the shuffles).

enum Stream { SHUFFLE, TABLE_ROLLS, CONSEQUENCE, LOOT }

## Fixed per-stream offsets. Written out rather than hashed, so a run's
## streams never change with the enum order or the engine's hash().
const STREAM_SALT: Dictionary[Stream, int] = {
	Stream.SHUFFLE: 0x1F83_D9AB_5BE0_CD19,
	Stream.TABLE_ROLLS: 0x2B7E_1516_28AE_D2A6,
	Stream.CONSEQUENCE: 0x3C6E_F372_FE94_F82B,
	Stream.LOOT: 0x510E_527F_ADE6_82D1,
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
