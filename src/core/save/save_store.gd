class_name SaveStore
extends RefCounted
## Writes GameState to disk with Godot's binary Variant format, which keeps
## 64-bit ints exact. Objects are never read back, so a doctored save file
## can't create one. A save is checked against the shape of a real one before
## anything is built from it.

const DEFAULT_PATH: String = "user://save.bin"


## Writes to a temp file first, so a failed or interrupted save never costs
## the previous one.
static func save(state: GameState, path: String = DEFAULT_PATH) -> Error:
	var temp_path: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_var(state.to_dict(), false)
	var err: Error = file.get_error()
	file.close()
	if err != OK:
		return err
	return DirAccess.rename_absolute(temp_path, path)


## Null if there is no save, or it's unreadable, damaged, or from another version.
static func load_from(path: String = DEFAULT_PATH) -> GameState:
	if not FileAccess.file_exists(path):
		return null
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var saved: Variant = file.get_var(false)
	if typeof(saved) != TYPE_DICTIONARY:
		push_warning("SaveStore: %s is not a save file" % path)
		return null
	var saved_dict: Dictionary = saved
	return from_saved(saved_dict)


## Builds a GameState from saved data, or null if it doesn't have the shape
## of a real save.
static func from_saved(saved: Dictionary) -> GameState:
	if saved.get("version") != GameState.VERSION:
		var found: Variant = saved.get("version")
		push_warning("SaveStore: save version %s, expected %d" % [found, GameState.VERSION])
		return null
	if not matches_shape(saved, _shape()):
		push_warning("SaveStore: save data is damaged")
		return null
	return GameState.from_dict(saved)


## True if value has template's types all the way down. A dictionary with
## String keys is a record: every key must be present. Any other dictionary,
## and any array, is a collection: each entry must match the template's first
## entry (an empty template collection accepts anything, e.g. event data).
static func matches_shape(value: Variant, template: Variant) -> bool:
	if typeof(value) != typeof(template):
		return false
	if template is Array:
		var items: Array = value
		var template_items: Array = template
		return template_items.is_empty() or items.all(
			func(item: Variant) -> bool: return matches_shape(item, template_items[0])
		)
	if template is Dictionary:
		var entries: Dictionary = value
		var template_entries: Dictionary = template
		if template_entries.is_empty():
			return true
		if typeof(template_entries.keys()[0]) == TYPE_STRING:
			return template_entries.keys().all(
				func(key: Variant) -> bool:
					return entries.has(key) and matches_shape(entries[key], template_entries[key])
			)
		var sample_key: Variant = template_entries.keys()[0]
		return entries.keys().all(
			func(key: Variant) -> bool:
				return (
					typeof(key) == typeof(sample_key)
					and matches_shape(entries[key], template_entries[sample_key])
				)
		)
	return true


## A real save with one of everything, used as the template for matches_shape.
static func _shape() -> Dictionary:
	var sample: GameState = GameState.new_run(0, 0)
	var card: Card = sample.deck.cards()[0]
	sample.deck.remove_card(sample.deck.cards()[1].id)
	sample.layer.change(card.id, 2, Card.Suit.CLUBS)
	sample.layer.tape(card.id)
	sample.layer.change(card.id, 3, Card.Suit.CLUBS)
	sample.events.append(&"sample")
	return sample.to_dict()
