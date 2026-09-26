class_name TableCosts
extends RefCounted
## One table's base cost for every action (spec §1.2). Each action rolls on
## its own within its family's range for the table's stakes; marks roll as
## information. Mark's per-mark step scales with its roll. Hidden from the
## player unless the Pit Ledger shows them (§9).

var game: GameKind.Kind
var stakes: TableStakes.Kind

var _base: Dictionary[ActionKind.Kind, float] = {}
var _mark_step: float


func _init(p_game: GameKind.Kind, p_stakes: TableStakes.Kind) -> void:
	game = p_game
	stakes = p_stakes


## Rolls a table's costs from the TABLE_ROLLS stream.
static func roll(
	rules: HeatRules, p_game: GameKind.Kind, p_stakes: TableStakes.Kind, rng: RandomNumberGenerator
) -> TableCosts:
	var costs: TableCosts = TableCosts.new(p_game, p_stakes)
	for action: ActionKind.Kind in ActionKind.Kind.values():
		var bounds: Vector2 = rules.roll_range(p_stakes, action in ActionKind.MANIPULATION)
		costs._set_factor(rules, action, 1.0 + rng.randf_range(bounds.x, bounds.y))
	return costs


## Every cost at its center, unrolled. For tests and the simulation harness.
static func centered(rules: HeatRules, p_game: GameKind.Kind) -> TableCosts:
	var costs: TableCosts = TableCosts.new(p_game, TableStakes.Kind.LOW)
	for action: ActionKind.Kind in ActionKind.Kind.values():
		costs._set_factor(rules, action, 1.0)
	return costs


## The action's base cost here. A mark adds the step for each mark already
## made this session.
func base_cost(action: ActionKind.Kind, marks_made: int) -> float:
	if action == ActionKind.Kind.MARK:
		return _base[action] + _mark_step * marks_made
	return _base[action]


func _set_factor(rules: HeatRules, action: ActionKind.Kind, factor: float) -> void:
	_base[action] = rules.center(game, action) * factor
	if action == ActionKind.Kind.MARK:
		_mark_step = rules.mark_step * factor
