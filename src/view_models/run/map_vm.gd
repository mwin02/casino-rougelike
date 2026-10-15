class_name MapVM
extends RefCounted
## The floor map between tables (block U4, spec §5.2, §6.5): every node and
## how it stands to the walk, the node picked to look at with its table
## offers, walking to it, and cashing out once the quota is reached.

const KIND_NAMES: Dictionary[MapNodeView.Look, String] = {
	MapNodeView.Look.LOW: "Low stakes",
	MapNodeView.Look.HIGH: "High stakes",
	MapNodeView.Look.SHOP: "Shop",
	MapNodeView.Look.DECK: "Deck services",
}
const WALK_LABELS: Dictionary[MapNodeView.Status, String] = {
	MapNodeView.Status.REACHABLE: "Walk here",
	MapNodeView.Status.CURRENT: "You are here",
	MapNodeView.Status.VISITED: "Already walked",
	MapNodeView.Status.AHEAD: "Not linked yet",
	MapNodeView.Status.PAST: "Off your route",
}
const HIDDEN_ROLLS: String = "Cost rolls stay hidden until you sit."
const DECK_NOTE: String = "Work on the deck between tables. Costs no hands."

var _owner: RunVM
var _run: Run
var _floor: Floor
## The node looked at; null on a map with nowhere to go.
var _selected: MapNode
## Every node still on a route from here, the next row's included.
var _on_route: Array[MapNode] = []


func _init(owner: RunVM) -> void:
	_owner = owner
	_run = owner.run
	_floor = _run.floor
	var next: Array[MapNode] = _floor.choices()
	var edge: Array[MapNode] = next.duplicate()
	while not edge.is_empty():
		var node: MapNode = edge.pop_back()
		if node not in _on_route:
			_on_route.append(node)
			edge.append_array(_floor.map.next_of(node))
	_selected = next[0] if not next.is_empty() else _floor.current


func hud() -> FloorHudVM:
	return FloorHudVM.new(_run)


func row_count() -> int:
	return _floor.map.row_count()


func lane_count() -> int:
	return _run.config().get_int("map", "lanes")


## The row to bring into view: the one the player walks to next.
func focus_row() -> int:
	return 0 if _floor.current == null else mini(_floor.current.row + 1, row_count() - 1)


func nodes() -> Array[MapNodeView]:
	var views: Array[MapNodeView] = []
	for node: MapNode in _floor.map.nodes:
		views.append(MapNodeView.new(node, _status(node), node == _selected))
	return views


func select(row: int, lane: int) -> void:
	var node: MapNode = _floor.map.node_at(row, lane)
	if node != null:
		_selected = node


## The picked node, as the map draws it; null with none.
func selected() -> MapNodeView:
	if _selected == null:
		return null
	return MapNodeView.new(_selected, _status(_selected), true)


## "High stakes", "Shop".
func selected_title() -> String:
	return KIND_NAMES[selected().look]


## "ROW 5 OF 10".
func selected_row_text() -> String:
	return "ROW %d OF %d" % [_selected.row + 1, row_count()]


## "3 tables · bets $5,000–$20,000", or "Back room".
func selected_sub() -> String:
	if _selected.is_back_room():
		return "Back room"
	var offers: Array[TableOffer] = selected_offers()
	var count: String = "1 table" if offers.size() == 1 else "%d tables" % offers.size()
	return "%s · bets %s" % [count, offers[0].stakes_text]


## The picked node's tables; none at a back room.
func selected_offers() -> Array[TableOffer]:
	return TableOffer.of_node(_selected)


func selected_note() -> String:
	match _selected.kind:
		MapNode.Kind.SHOP:
			var floor_number: int = _run.state.floor_number
			return "Items and consumables at floor %d prices. Costs no hands." % floor_number
		MapNode.Kind.DECK_SERVICES:
			return DECK_NOTE
	var watched: PackedStringArray = []
	for offer: TableOffer in selected_offers():
		if offer.watched:
			watched.append(offer.name)
	if watched.is_empty():
		return HIDDEN_ROLLS
	var tables: String = " and ".join(watched) + (" table" if watched.size() == 1 else " tables")
	return "The pit boss watches the %s from the first hand. %s" % [tables, HIDDEN_ROLLS]


func walk_label() -> String:
	return WALK_LABELS[_status(_selected)]


func can_walk() -> bool:
	return _selected != null and _selected in _floor.choices()


## Walks to the picked node.
func walk() -> void:
	if can_walk() and _floor.enter(_selected):
		_owner.step_done()


func can_cash_out() -> bool:
	return _floor.can_cash_out()


## "−27 run heat": what cashing out now sheds (§6.5).
func cash_out_text() -> String:
	var config: TuneConfig = _run.config()
	var hands: int = _floor.clock.hands_left - mini(
		_floor.clock.hands_left, _run.kit.carry_hands_max
	)
	var shed: float = hands * config.get_float("run_heat", "cash_out_shed_per_hand")
	return "−%d run heat" % roundi(minf(shed, _run.state.run_heat))


## "Cash out opens at the $140,000 quota".
func cash_out_note() -> String:
	return "Cash out opens at the %s quota" % MoneyFormat.format(_floor.quota)


func cash_out() -> void:
	if _floor.cash_out():
		_owner.step_done()


func go_home() -> void:
	_owner.go_home()


func _status(node: MapNode) -> MapNodeView.Status:
	if node == _floor.current:
		return MapNodeView.Status.CURRENT
	if node in _floor.walked:
		return MapNodeView.Status.VISITED
	if node in _floor.choices():
		return MapNodeView.Status.REACHABLE
	if node in _on_route:
		return MapNodeView.Status.AHEAD
	return MapNodeView.Status.PAST
