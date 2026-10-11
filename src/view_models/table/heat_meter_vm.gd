class_name HeatMeterVM
extends RefCounted
## The table's heat meter (spec §7.1): the heat as a whole number, its tier,
## and where things sit on the bar as fractions of its length. The tier
## edges come from the rules, so the bar follows config. With heat pending
## (this hand's heat so far, plus an action being weighed) it also shows
## where the table would land.

## Where the last edge (Backed off) sits on the bar; the rest is headroom.
const TOP_EDGE_AT: float = 0.9

var _rules: HeatRules
var _heat: float
var _heat_floor: float
var _pending: float


class Band:
	extends RefCounted
	var name: String
	## "0–45", or "135+" for the last.
	var range_text: String
	var from_fraction: float
	var to_fraction: float


func _init(rules: HeatRules, heat: float, heat_floor: float, pending: float = 0.0) -> void:
	_rules = rules
	_heat = heat
	_heat_floor = heat_floor
	_pending = pending


func heat_text() -> String:
	return str(roundi(_heat))


func tier() -> HeatTier.Kind:
	return _rules.tier_of(_heat)


func tier_name() -> String:
	return HeatText.tier_name(tier())


func fill_fraction() -> float:
	return _fraction(_heat)


## The tier edges, lowest first.
func edge_fractions() -> Array[float]:
	var edges: Array[float] = []
	for threshold: float in _rules.tier_thresholds:
		edges.append(_fraction(threshold))
	return edges


## A deck with edits or marks can't cool below its floor (§4.2).
func has_floor() -> bool:
	return _heat_floor > 0.0


func floor_fraction() -> float:
	return _fraction(_heat_floor)


func has_projection() -> bool:
	return roundi(_heat + _pending) != roundi(_heat)


## "→ 27", or empty with nothing pending.
func projected_text() -> String:
	return "→ %d" % roundi(_heat + _pending) if has_projection() else ""


func projected_fraction() -> float:
	return _fraction(_heat + _pending)


func projected_tier_name() -> String:
	return HeatText.tier_name(_rules.tier_of(_heat + _pending))


## True when the pending heat would move the table into another tier.
func crosses_tier() -> bool:
	return _rules.tier_of(_heat + _pending) != tier()


## Every tier with its range, lowest first, for the settle panel's meter.
func bands() -> Array[Band]:
	var result: Array[Band] = []
	var from: float = 0.0
	for kind: int in HeatTier.Kind.values():
		var band: Band = Band.new()
		band.name = HeatText.tier_name(kind as HeatTier.Kind)
		band.from_fraction = _fraction(from)
		if kind < _rules.tier_thresholds.size():
			var to: float = _rules.tier_thresholds[kind]
			band.range_text = "%d–%d" % [roundi(from), roundi(to)]
			band.to_fraction = _fraction(to)
			from = to
		else:
			band.range_text = "%d+" % roundi(from)
			band.to_fraction = 1.0
		result.append(band)
	return result


func _fraction(heat: float) -> float:
	var top: float = _rules.tier_thresholds[-1] / TOP_EDGE_AT
	return clampf(heat / top, 0.0, 1.0)
