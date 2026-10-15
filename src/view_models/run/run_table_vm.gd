class_name RunTableVM
extends TableScreenVM
## The real table screen at a table of a run's floor: the session is the
## one the floor sat, on the floor's clock and under its signature, with the
## run's deck, kit and bankroll. Every settled hand saves the run. Leaving
## the table leaves its node (one session a node, spec §5.2), once the last
## hand's result has been read.

var _owner: RunVM
var _floor: Floor
## The session is over; the node is left once the settled hand is put away.
var _leaving: bool = false


## owner's run is seated at a table.
func _init(owner: RunVM) -> void:
	var run: Run = owner.run
	super(run.config(), run.game.deck, run.game.rng)
	_owner = owner
	_floor = run.floor
	_layer = run.game.layer
	_kit = run.kit
	setup.kit = run.kit
	run_heat = run.state.run_heat
	_seat(_floor.session)
	bankroll = _session.bankroll


## "27 hands left".
func clock_text() -> String:
	var hands: int = _floor.clock.hands_left
	return "%d %s left" % [hands, "hand" if hands == 1 else "hands"]


## "Quota $140,000 · $35,200 to go", or "Quota $140,000 · reached".
func quota_text() -> String:
	var gap: int = _floor.quota - bankroll
	var state: String = "reached" if gap <= 0 else MoneyFormat.format(gap) + " to go"
	return "Quota %s · %s" % [MoneyFormat.format(_floor.quota), state]


func continue_after_hand() -> void:
	super()
	if _leaving and _summary == null:
		_leave_node()


func _hand_settled() -> void:
	super()
	_owner.hand_settled()


func _leave(ended: SessionEnd) -> void:
	super(ended)
	_leaving = true
	if _summary == null:
		_leave_node()


## Banks the session with the floor and moves the run on.
func _leave_node() -> void:
	_leaving = false
	_floor.leave()
	_owner.step_done()
