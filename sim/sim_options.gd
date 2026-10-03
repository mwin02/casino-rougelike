class_name SimOptions
extends RefCounted
## The harness's command-line flags, all written `--name=value`:
##
##   --mode=dph|floor     dollars per heat per game (default), or floor quota clearance
##   --games=a,b          blackjack, baccarat, high_low (default: all three)
##   --bots=a,b           bot names (default: every bot but the side-bet ones)
##   --sessions=N         sessions per bot and game (floor mode: floors)
##   --hands=N            hands per session in dph mode
##   --floor=N            1–5, sets the stakes and quota
##   --stakes=low|high
##   --seed=N             session i plays on seed + i
##   --shard=i/N          play only this shard's sessions
##   --bankroll=N         floor mode starting bankroll (default: the floor's)
##   --out=PATH           write the shard's results as JSON
##   --set=section.key=v  config override, repeatable (see SimConfig)

enum Mode { DOLLARS_PER_HEAT, FLOOR }

## The floor's own starting bankroll: start_bankroll on floor 1, else the
## previous floor's quota.
const DEFAULT_BANKROLL: int = -1

const GAME_NAMES: Dictionary[String, GameKind.Kind] = {
	"blackjack": GameKind.Kind.BLACKJACK,
	"baccarat": GameKind.Kind.BACCARAT,
	"high_low": GameKind.Kind.HIGH_LOW,
}

var mode: Mode = Mode.DOLLARS_PER_HEAT
var games: Array[GameKind.Kind] = [
	GameKind.Kind.BLACKJACK, GameKind.Kind.BACCARAT, GameKind.Kind.HIGH_LOW
]
## Empty: every bot.
var bots: Array[String] = []
var sessions: int = 2000
var hands: int = 20
var floor_number: int = 1
var stakes: TableStakes.Kind = TableStakes.Kind.HIGH
var seed: int = 1
var shard_index: int = 0
var shard_count: int = 1
var bankroll: int = DEFAULT_BANKROLL
## Empty: print instead of writing.
var out_path: String = ""
var sets: Array[String] = []
var problems: PackedStringArray = []


static func parse(args: PackedStringArray) -> SimOptions:
	var options: SimOptions = SimOptions.new()
	for arg: String in args:
		var eq: int = arg.find("=")
		if not arg.begins_with("--") or eq < 0:
			options.problems.append("expected --name=value, got %s" % arg)
			continue
		options._apply(arg.substr(2, eq - 2), arg.substr(eq + 1))
	return options


## This shard's session indices: every shard_count-th from shard_index.
func shard_sessions() -> Array[int]:
	var result: Array[int] = []
	for index: int in range(shard_index, sessions, shard_count):
		result.append(index)
	return result


func game_name(game: GameKind.Kind) -> String:
	return GAME_NAMES.find_key(game)


func _apply(flag: String, value: String) -> void:
	match flag:
		"mode":
			match value:
				"dph":
					mode = Mode.DOLLARS_PER_HEAT
				"floor":
					mode = Mode.FLOOR
				_:
					problems.append("--mode must be dph or floor")
		"games":
			games.clear()
			for name: String in value.split(","):
				if GAME_NAMES.has(name):
					games.append(GAME_NAMES[name])
				else:
					problems.append("unknown game %s" % name)
		"bots":
			bots.assign(value.split(","))
		"sessions":
			sessions = _positive(flag, value)
		"hands":
			hands = _positive(flag, value)
		"floor":
			floor_number = _positive(flag, value)
			if floor_number > TuneSchema.FLOORS:
				problems.append("--floor must be 1–%d" % TuneSchema.FLOORS)
		"stakes":
			match value:
				"low":
					stakes = TableStakes.Kind.LOW
				"high":
					stakes = TableStakes.Kind.HIGH
				_:
					problems.append("--stakes must be low or high")
		"seed":
			seed = _int(flag, value)
		"shard":
			_apply_shard(value)
		"bankroll":
			bankroll = _positive(flag, value)
		"out":
			out_path = value
		"set":
			sets.append(value)
		_:
			problems.append("unknown flag --%s" % flag)


func _apply_shard(value: String) -> void:
	var parts: PackedStringArray = value.split("/")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		problems.append("--shard must be i/N")
		return
	shard_index = parts[0].to_int()
	shard_count = parts[1].to_int()
	if shard_count < 1 or shard_index < 0 or shard_index >= shard_count:
		problems.append("--shard needs 0 ≤ i < N")


func _int(flag: String, value: String) -> int:
	if not value.is_valid_int():
		problems.append("--%s must be a whole number" % flag)
		return 0
	return value.to_int()


func _positive(flag: String, value: String) -> int:
	var number: int = _int(flag, value)
	if number < 1:
		problems.append("--%s must be at least 1" % flag)
	return number
