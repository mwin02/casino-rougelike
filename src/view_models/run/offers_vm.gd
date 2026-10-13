class_name OffersVM
extends RefCounted
## A node of tables before sitting down (block U4, spec §5.2): each table's
## game, stakes, house rule and whether the pit boss watches it, never its
## cost rolls. The player sits at one, once, or goes back to the map, which
## leaves the node behind.

const PICK: String = "PICK A TABLE"
const HIDDEN: String = "Cost rolls hidden"
const SIT: String = "Sit"
const CLEAN: String = "Clean"
const WATCHED: String = "Watched"
const FOOT_NOTE: String = (
	"Pick a table: hands only tick once you play. Back to map skips this stop."
)

var _owner: RunVM
var _run: Run
var _floor: Floor
var _node: MapNode


## owner's run is at a node of tables, not yet seated.
func _init(owner: RunVM) -> void:
	_owner = owner
	_run = owner.run
	_floor = _run.floor
	_node = _floor.current


func hud() -> FloorHudVM:
	return FloorHudVM.new(_run)


## "High stakes".
func title() -> String:
	return TableSetupVM.STAKES_NAMES[_node.stakes]


func is_high_stakes() -> bool:
	return _node.is_high_stakes()


## "ROW 5 OF 10 · PICK A TABLE".
func row_text() -> String:
	return "ROW %d OF %d · %s" % [_node.row + 1, _floor.map.row_count(), PICK]


func offers() -> Array[TableOffer]:
	return TableOffer.of_node(_node)


## The tier the table opens in: "Clean", or "Watched" under the pit boss's
## eye (§7.5).
func tier_text(offer: TableOffer) -> String:
	return WATCHED if offer.watched else CLEAN


## What is known of the table's heat without its rolls: where the Marked
## consequence fires (§7.2), and that a watched table starts Watched.
func hidden_note(offer: TableOffer) -> String:
	var marked: int = roundi(HeatRules.from_config(_run.config()).marked_from())
	var note: String = "Something bad happens at %d." % marked
	return "Watched from the first hand. " + note if offer.watched else note


## True when the bankroll covers the table's minimum.
func can_sit(offer: TableOffer) -> bool:
	return _run.state.bankroll >= _node.tables[offer.index].table_min


## "Sit", or "Needs $5,000" when the bankroll is under the minimum.
func sit_label(offer: TableOffer) -> String:
	if can_sit(offer):
		return SIT
	return "Needs " + MoneyFormat.format(_node.tables[offer.index].table_min)


func sit(offer: TableOffer) -> void:
	if _floor.sit(offer.index) != null:
		_owner.step_done()


## Leaves the node without sitting.
func back() -> void:
	if _floor.leave():
		_owner.step_done()
