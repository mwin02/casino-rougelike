class_name GameState
extends RefCounted
## Everything a run needs to resume. Saved between hands. Later blocks add
## their state here and bump VERSION.

const VERSION: int = 3

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
		"version": VERSION,
		"deck": deck.to_dict(),
		"layer": layer.to_dict(),
		"rng": rng.to_dict(),
		"events": events.to_dict(),
	}


## Builds from well-formed data. Loading from disk goes through
## SaveStore.from_saved, which checks the version and shape first.
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
