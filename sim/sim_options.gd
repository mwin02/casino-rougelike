class_name SimOptions
extends RefCounted
## The harness's command-line flags, all written `--name=value`:
##
##   --mode=dph|floor|run dollars per heat per game (default), floor quota
##                        clearance, or whole runs (every game; --games ignored)
##   --games=a,b          blackjack, baccarat, high_low (default: all three)
##   --bots=a,b           bot names (default: every bot but the side-bet ones)
##   --sessions=N         sessions per bot and game (floor mode: floors; run
##                        mode: runs per bot)
##   --hands=N            hands per session in dph mode
##   --floor=N            1–5, sets the stakes and quota
##   --stakes=low|high
##   --seed=N             session i plays on seed + i
##   --shard=i/N          play only this shard's sessions
##   --bankroll=N         floor mode starting bankroll (default: the floor's)
##   --out=PATH           write the shard's results as JSON
##   --set=section.key=v  config override, repeatable (see SimConfig); a
##                        level's quotas and stakes are difficulty_N.key
##   --difficulty=N       every mode: play at difficulty level N (default:
##                        the config's default level)
##   --cash-out=N         run mode: every bot cashes out at N% of the quota,
##                        at least 100 (default: each bot's own share)
##   --items=a,b          floor and run modes: items the bot owns, e.g. side_pocket,sleight
##                        (one floor, so Comped Breakfast's carry never shows)

enum Mode { DOLLARS_PER_HEAT, FLOOR, RUN }

## The floor's own starting bankroll: start_bankroll on floor 1, else the
## previous floor's quota.
const DEFAULT_BANKROLL: int = -1
## Each bot cashes out at its own share of the quota.
const BOTS_CASH_OUT: int = -1

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
var cash_out_pct: int = BOTS_CASH_OUT
## Empty: print instead of writing.
var out_path: String = ""
var sets: Array[String] = []
## Run.CONFIG_LEVEL: the config's default level.
var difficulty: int = Run.CONFIG_LEVEL
## Floor mode: items added to the harness kit.
var items: Array[ItemKind.Kind] = []
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
				"run":
					mode = Mode.RUN
				_:
					problems.append("--mode must be dph, floor or run")
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
		"cash-out":
			cash_out_pct = _int(flag, value)
			if cash_out_pct < 100:
				problems.append("--cash-out must be at least 100")
		"out":
			out_path = value
		"set":
			sets.append(value)
		"difficulty":
			difficulty = _int(flag, value)
			if difficulty < 0:
				problems.append("--difficulty must be a level number")
		"items":
			_apply_items(value)
		_:
			problems.append("unknown flag --%s" % flag)


func _apply_items(value: String) -> void:
	items.clear()
	for name: String in value.split(","):
		var index: int = ItemKind.Kind.keys().find(name.to_upper())
		if index < 0:
			problems.append("unknown item %s" % name)
		else:
			items.append(index as ItemKind.Kind)


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
