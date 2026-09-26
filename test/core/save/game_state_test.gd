extends GdUnitTestSuite
## Save/load round-trips a run exactly (block 1).

const PATH: String = "user://test_save.bin"
const MIN_SIZE: int = 20

## Card ids in _busy_state, by role.
const REMOVED: int = 0
const REFORGED: int = 5
const MARKED: int = 9
const TAPED: int = 10
const TAPED_UNDER_HAND: int = 11
const SWITCH_A: int = 12
const SWITCH_B: int = 13
const EVENT_DATA: Dictionary = {
	"heat": 6,
	"rate": 1.5,
	"big": -9_000_000_000_000,
	"label": "straight hand",
	"tag": &"reveal",
	"lines": [{"name": "nudge", "heat": 12}, 3.25],
}


func after_test() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


## A run with some of everything: edits, marks, a taped change, a hand change
## over a taped one, a switch, events, and every RNG stream moved off its start.
func _busy_state() -> GameState:
	var state: GameState = GameState.new_run(42, MIN_SIZE)
	var deck: Deck = state.deck
	deck.remove_card(REMOVED)
	deck.add_card(1, Card.Suit.HEARTS)
	deck.reforge(REFORGED, 3, Card.Suit.CLUBS, DeckEdit.Kind.REFORGE_TOUCH_UP)
	deck.mark(MARKED, 1)
	state.layer.change(TAPED, 12, Card.Suit.DIAMONDS)
	state.layer.tape(TAPED)
	state.layer.change(TAPED_UNDER_HAND, 1, Card.Suit.CLUBS)
	state.layer.tape(TAPED_UNDER_HAND)
	state.layer.end_hand()
	state.layer.change(TAPED_UNDER_HAND, 2, Card.Suit.CLUBS)
	state.layer.switch_cards(deck.card(SWITCH_A), deck.card(SWITCH_B))
	state.events.append(&"test_event", EVENT_DATA)
	for s: int in GameRng.Stream.values():
		for i: int in s + 1:
			state.rng.stream(s as GameRng.Stream).randi()
	return state


func _file_round_trip(state: GameState) -> GameState:
	assert_int(SaveStore.save(state, PATH)).is_equal(OK)
	return SaveStore.load_from(MIN_SIZE, PATH)


func _reads(state: GameState, id: int) -> String:
	return state.layer.apply_to(state.deck.card(id)).short_name()


func test_file_round_trip_is_exact() -> void:
	var state: GameState = _busy_state()
	var restored: GameState = _file_round_trip(state)
	assert_object(restored).is_not_null()
	assert_dict(restored.to_dict()).is_equal(state.to_dict())


func test_loaded_deck_matches_card_by_card() -> void:
	var restored: GameState = _file_round_trip(_busy_state())
	assert_object(restored.deck.card(REMOVED)).is_null()
	assert_str(restored.deck.card(REFORGED).short_name()).is_equal("3C")
	assert_int(restored.deck.card(MARKED).symbol).is_equal(1)
	assert_int(restored.deck.size()).is_equal(52)
	assert_int(restored.deck.edit_count(DeckEdit.Kind.REMOVE)).is_equal(1)
	assert_int(restored.deck.edit_count(DeckEdit.Kind.ADD)).is_equal(1)
	assert_int(restored.deck.edit_count(DeckEdit.Kind.REFORGE_TOUCH_UP)).is_equal(1)


func test_loaded_deck_continues_the_same_ids() -> void:
	var state: GameState = _busy_state()
	var restored: GameState = _file_round_trip(state)
	var next_id: int = state.deck.add_card(2, Card.Suit.SPADES).id
	assert_int(restored.deck.add_card(2, Card.Suit.SPADES).id).is_equal(next_id)


func test_loaded_layer_keeps_every_change() -> void:
	var state: GameState = _busy_state()
	var restored: GameState = _file_round_trip(state)
	assert_str(_reads(restored, TAPED)).is_equal("QD")
	assert_bool(restored.layer.is_taped(TAPED)).is_true()
	assert_str(_reads(restored, TAPED_UNDER_HAND)).is_equal("2C")
	assert_bool(restored.layer.is_taped(TAPED_UNDER_HAND)).is_false()
	assert_str(_reads(restored, SWITCH_A)).is_equal(_reads(state, SWITCH_A))
	restored.layer.end_hand()
	assert_str(_reads(restored, TAPED_UNDER_HAND)).is_equal("AC")


func test_loaded_switch_still_pairs_its_cards() -> void:
	var state: GameState = _busy_state()
	var restored: GameState = _file_round_trip(state)
	restored.layer.tape(SWITCH_A)
	restored.layer.end_hand()
	assert_str(_reads(restored, SWITCH_A)).is_equal(_reads(state, SWITCH_A))
	assert_str(_reads(restored, SWITCH_B)).is_equal(_reads(state, SWITCH_B))


func test_loaded_events_keep_their_values_and_types() -> void:
	var restored: GameState = _file_round_trip(_busy_state())
	var event: GameEvent = restored.events.of_kind(&"test_event")[0]
	assert_that(event.kind).is_equal(&"test_event")
	assert_int(typeof(event.kind)).is_equal(TYPE_STRING_NAME)
	assert_dict(event.data).is_equal(EVENT_DATA)
	for key: String in EVENT_DATA:
		assert_int(typeof(event.data[key])).is_equal(typeof(EVENT_DATA[key]))
	assert_int(restored.events.append(&"next").seq).is_equal(1)


func test_loaded_run_continues_every_random_stream() -> void:
	var state: GameState = _busy_state()
	var restored: GameState = _file_round_trip(state)
	for s: int in GameRng.Stream.values():
		var stream: GameRng.Stream = s as GameRng.Stream
		assert_int(restored.rng.stream(stream).randi()).is_equal(state.rng.stream(stream).randi())


func test_wrong_version_is_refused() -> void:
	var data: Dictionary = _busy_state().to_dict()
	data["version"] = GameState.VERSION + 1
	assert_object(SaveStore.from_saved(data, MIN_SIZE)).is_null()


func test_damaged_saves_are_refused() -> void:
	var missing_key: Dictionary = _busy_state().to_dict()
	missing_key.erase("deck")
	assert_object(SaveStore.from_saved(missing_key, MIN_SIZE)).is_null()
	var wrong_type: Dictionary = _busy_state().to_dict()
	wrong_type["rng"]["states"]["LOOT"] = "seven"
	assert_object(SaveStore.from_saved(wrong_type, MIN_SIZE)).is_null()
	var bad_card: Dictionary = _busy_state().to_dict()
	var card: Dictionary = bad_card["deck"]["cards"][3]
	card.erase("rank")
	assert_object(SaveStore.from_saved(bad_card, MIN_SIZE)).is_null()


func test_non_save_file_is_refused() -> void:
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_var([1, 2, 3])
	file.close()
	assert_object(SaveStore.load_from(MIN_SIZE, PATH)).is_null()


func test_missing_file_loads_nothing() -> void:
	assert_object(SaveStore.load_from(MIN_SIZE, "user://no_such_save.bin")).is_null()


func test_min_size_comes_from_the_loader_not_the_save() -> void:
	SaveStore.save(_busy_state(), PATH)
	assert_int(SaveStore.load_from(30, PATH).deck.min_size).is_equal(30)


func test_saving_again_replaces_the_old_save() -> void:
	var state: GameState = _busy_state()
	SaveStore.save(state, PATH)
	state.deck.add_card(4, Card.Suit.DIAMONDS)
	SaveStore.save(state, PATH)
	assert_int(SaveStore.load_from(MIN_SIZE, PATH).deck.size()).is_equal(53)
	assert_bool(FileAccess.file_exists(PATH + ".tmp")).is_false()
