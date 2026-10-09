class_name GameState
extends RefCounted
## The run's deck, manipulation layer, RNG streams and event log. Saved
## with the rest of the run by Run, which holds the save version.

var deck: Deck
var layer: ManipulationLayer
var rng: GameRng
var events: EventLog


static func new_run(run_seed: int, min_deck_size: int) -> GameState:
	var state: GameState = GameState.new()
	state.deck = Deck.standard(min_deck_size)
	state.layer = ManipulationLayer.new()
	state.rng = GameRng.new(run_seed)
	state.events = EventLog.new()
	return state


func to_dict() -> Dictionary:
	return {
		"deck": deck.to_dict(),
		"layer": layer.to_dict(),
		"rng": rng.to_dict(),
		"events": events.to_dict(),
	}


## Builds from well-formed data.
static func from_dict(saved: Dictionary, min_deck_size: int) -> GameState:
	var saved_deck: Dictionary = saved["deck"]
	var saved_layer: Dictionary = saved["layer"]
	var saved_rng: Dictionary = saved["rng"]
	var saved_events: Dictionary = saved["events"]
	var state: GameState = GameState.new()
	state.deck = Deck.from_dict(saved_deck, min_deck_size)
	state.layer = ManipulationLayer.from_dict(saved_layer)
	state.rng = GameRng.from_dict(saved_rng)
	state.events = EventLog.from_dict(saved_events)
	return state
