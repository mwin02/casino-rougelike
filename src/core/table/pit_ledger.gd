class_name PitLedger
extends RefCounted
## What the Pit Ledger item shows of a table (spec §1.4, §7.2, §9): its rolled
## base costs and the Marked consequence it rolled at sit-down.

var costs: TableCosts
var consequence: MarkedConsequence.Kind


func _init(p_costs: TableCosts, p_consequence: MarkedConsequence.Kind) -> void:
	costs = p_costs
	consequence = p_consequence
