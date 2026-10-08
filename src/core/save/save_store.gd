class_name SaveStore
extends RefCounted
## Writes a Run to disk with Godot's binary Variant format, which keeps
## 64-bit ints exact. Objects are never read back, so a doctored save file
## can't create one. A save is checked against the shape of a real one before
## anything is built from it.

const DEFAULT_PATH: String = "user://save.bin"


## Writes to a temp file first, so a failed or interrupted save never costs
## the previous one. Refused (ERR_BUSY) when the run can't save right now.
static func save(run: Run, path: String = DEFAULT_PATH) -> Error:
	if not run.can_save():
		return ERR_BUSY
	var temp_path: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_var(run.to_dict(), false)
	var err: Error = file.get_error()
	file.close()
	if err != OK:
		return err
	return DirAccess.rename_absolute(temp_path, path)


## Null if there is no save, or it's unreadable, damaged, or from another version.
## Rules such as the deck's minimum size come from config, not the save.
static func load_from(config: TuneConfig, path: String = DEFAULT_PATH) -> Run:
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
	return from_saved(saved_dict, config)


## Builds a Run from saved data, or null if it doesn't have the shape of a
## real save.
static func from_saved(saved: Dictionary, config: TuneConfig) -> Run:
	if saved.get("version") != Run.VERSION:
		var found: Variant = saved.get("version")
		push_warning("SaveStore: save version %s, expected %d" % [found, Run.VERSION])
		return null
	if not matches_shape(saved, _shape(config)):
		push_warning("SaveStore: save data is damaged")
		return null
	return Run.from_dict(saved, config)


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


## A real save with one of everything, used as the template for matches_shape:
## an item and consumables, deck edits, a taped change and events, and a
## floor at its end shop with a Rummage open. Parts a run can't hold at once
## (elevator options, a deck-services stop) are filled in from samples.
static func _shape(config: TuneConfig) -> Dictionary:
	var sample: Run = Run.start(config, 0)
	var game: GameState = sample.game
	var card: Card = game.deck.cards()[0]
	game.deck.remove_card(game.deck.cards()[1].id)
	game.deck.mark(card.id, 0)
	game.layer.change(card.id, 2, Card.Suit.CLUBS)
	game.layer.tape(card.id)
	game.layer.change(card.id, 3, Card.Suit.CLUBS)
	game.events.append(&"sample")
	sample.kit.add_item(ItemKind.Kind.SLEIGHT, ItemRules.from_config(config))
	var floor: Floor = sample.floor
	floor.enter(floor.map.row(0)[0])
	floor.leave()
	sample.state.bankroll = floor.quota
	floor.cash_out()
	floor.check_quota()
	floor.shop.services.start_rummage()
	var shape: Dictionary = sample.to_dict()
	shape["options"] = [FloorSignature.Kind.BASELINE]
	var saved_floor: Dictionary = shape["floor"]
	saved_floor["services"] = saved_floor["shop_services"]
	return shape
