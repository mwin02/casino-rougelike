class_name MarkerVM
extends RefCounted
## The marker's notice (block U4, spec §11): the player left a table with
## less than the floor's low-stakes minimum, and the house fronted money to
## keep the run going, once. It shows the loan, its interest, and what both
## do to the bankroll and the next floor's quota.

const STAMP: String = "CALLED IN"
const ONCE: String = "ONE PER RUN"
const USED: String = "Your marker is used."
const WARNING: String = (
	"Go broke again, or come up short at the quota check, and the run ends."
)
const DONE: String = "Back to the floor"

var _owner: RunVM
var _config: TuneConfig
var _state: RunState
var _loan: int


## owner's run has just had its marker called mid-floor.
func _init(owner: RunVM) -> void:
	_owner = owner
	_config = owner.run.config()
	_state = owner.run.state
	_loan = owner.run.floor.marker_loan


## "The house fronts you $70,000."
func title() -> String:
	return "The house fronts you %s." % MoneyFormat.format(_loan)


func reason() -> String:
	var low_min: int = _config.get_int_list("floors", "low_stakes_min")[_state.floor_number - 1]
	return (
		"You left the table with less than this floor's %s low-stakes minimum."
		% MoneyFormat.format(low_min)
		+ " The house keeps you playing, once."
	)


func fronted_text() -> String:
	return MoneyFormat.format(_loan)


## "Interest, 25%".
func interest_label() -> String:
	return "Interest, %d%%" % _interest_pct()


func interest_text() -> String:
	return MoneyFormat.format(_owed() - _loan)


## "Added to floor 2's quota".
func owed_label() -> String:
	return "Added to floor %d's quota" % (_state.floor_number + 1)


## "+$87,500".
func owed_text() -> String:
	return "+" + MoneyFormat.format(_owed())


## "BROKE MID-FLOOR · FLOOR 1".
func footer() -> String:
	return "BROKE MID-FLOOR · FLOOR %d" % _state.floor_number


func bankroll_before_text() -> String:
	return MoneyFormat.format(_state.bankroll - _loan)


func bankroll_after_text() -> String:
	return MoneyFormat.format(_state.bankroll)


## "+$70,000".
func fronted_gain_text() -> String:
	return "+" + MoneyFormat.format(_loan)


## "FLOOR 2 QUOTA".
func quota_label() -> String:
	return "FLOOR %d QUOTA" % (_state.floor_number + 1)


func quota_before_text() -> String:
	return MoneyFormat.format(_next_quota())


func quota_after_text() -> String:
	return MoneyFormat.format(_next_quota() + _owed())


func quota_note() -> String:
	return "The loan plus %d%% interest. Shop prices don't rise." % _interest_pct()


## Puts the notice away.
func done() -> void:
	_owner.marker_seen()


func _interest_pct() -> int:
	return _config.get_int("marker", "interest_pct")


func _owed() -> int:
	return Marker.owed(_config, _loan)


## The next floor's quota before the debt joins it.
func _next_quota() -> int:
	return _config.get_int_list("floors", "quotas")[_state.floor_number]
