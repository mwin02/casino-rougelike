class_name MapRules
extends RefCounted
## Floor map [TUNE] values (spec §5.2).

const SECTION: String = "map"

var rows: int
var lanes: int
## [min, max], inclusive.
var nodes_per_row: Array[int]
var tables_per_node: Array[int]
## Weights for a middle row's node kinds.
var table_weight: int
var shop_weight: int
var deck_services_weight: int
## Chance a table node is high stakes, percent.
var high_stakes_pct: int
## Every path from the first row to the last passes at least these.
var min_tables_per_path: int
var min_high_per_path: int
var min_low_per_path: int
var min_back_room_per_path: int
## Chance a table plays under a house rule, percent, from this floor on.
var house_rule_pct: int
var house_rule_from_floor: int


static func from_config(config: TuneConfig) -> MapRules:
	var rules: MapRules = MapRules.new()
	rules.rows = config.get_int(SECTION, "rows")
	rules.lanes = config.get_int(SECTION, "lanes")
	rules.nodes_per_row = config.get_int_list(SECTION, "nodes_per_row")
	rules.tables_per_node = config.get_int_list(SECTION, "tables_per_node")
	rules.table_weight = config.get_int(SECTION, "table_weight")
	rules.shop_weight = config.get_int(SECTION, "shop_weight")
	rules.deck_services_weight = config.get_int(SECTION, "deck_services_weight")
	rules.high_stakes_pct = config.get_int(SECTION, "high_stakes_pct")
	rules.min_tables_per_path = config.get_int(SECTION, "min_tables_per_path")
	rules.min_high_per_path = config.get_int(SECTION, "min_high_per_path")
	rules.min_low_per_path = config.get_int(SECTION, "min_low_per_path")
	rules.min_back_room_per_path = config.get_int(SECTION, "min_back_room_per_path")
	rules.house_rule_pct = config.get_int(SECTION, "house_rule_pct")
	rules.house_rule_from_floor = config.get_int(SECTION, "house_rule_from_floor")
	return rules
