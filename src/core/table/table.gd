class_name Table
extends RefCounted
## One table the player can sit at (spec §5.1, §5.2): its game, stakes type,
## floor, and bet range. Stakes follow the floor (§6.3). The pit boss may
## watch it (§7.5). It may play under a house rule (§5.2).

var game: GameKind.Kind
var stakes: TableStakes.Kind
## 1–5.
var floor_number: int
var table_min: int
var table_max: int
## §7.5: Watched applies from a lower table heat here.
var watched: bool = false
## §5.2: the house rule this table plays under, by its config name; empty
## for none.
var house_rule: String = ""


func _init(
	p_game: GameKind.Kind,
	p_stakes: TableStakes.Kind,
	p_floor_number: int,
	p_table_min: int,
	p_table_max: int
) -> void:
	game = p_game
	stakes = p_stakes
	floor_number = p_floor_number
	table_min = p_table_min
	table_max = p_table_max


## The table's bet range comes from its floor's stakes in config.
static func from_config(
	config: TuneConfig, p_game: GameKind.Kind, p_stakes: TableStakes.Kind, p_floor_number: int
) -> Table:
	var prefix: String = "low_stakes" if p_stakes == TableStakes.Kind.LOW else "high_stakes"
	var index: int = p_floor_number - 1
	return Table.new(
		p_game,
		p_stakes,
		p_floor_number,
		config.get_int_list("floors", prefix + "_min")[index],
		config.get_int_list("floors", prefix + "_max")[index],
	)


## The config this table's rules are read from: config with the table's house
## rule written in. A rule the config lacks, or one for another game, is
## ignored.
func rules_config(config: TuneConfig) -> TuneConfig:
	return config.for_table_rule(house_rule, GameKind.config_section(game))


func to_dict() -> Dictionary:
	return {
		"game": game,
		"stakes": stakes,
		"floor_number": floor_number,
		"table_min": table_min,
		"table_max": table_max,
		"watched": watched,
		"house_rule": house_rule,
	}


static func from_dict(saved: Dictionary) -> Table:
	var p_game: int = saved["game"]
	var p_stakes: int = saved["stakes"]
	var p_floor_number: int = saved["floor_number"]
	var p_table_min: int = saved["table_min"]
	var p_table_max: int = saved["table_max"]
	var table: Table = Table.new(
		p_game as GameKind.Kind, p_stakes as TableStakes.Kind, p_floor_number, p_table_min,
		p_table_max
	)
	table.watched = saved["watched"]
	table.house_rule = saved["house_rule"]
	return table
