class_name SimConfig
extends RefCounted
## The configs a harness run covers (spec §12): config/tune.cfg with
## `section.key=value` overrides. A top-level comma list sweeps the key
## (`blackjack.bet_change_base=0,1,4`); commas inside brackets belong to a list
## value. Several sweeps multiply. An int given for a float key is read as a
## float. Every override is checked against TuneSchema before anything runs.
## A level's own values are difficulty_N.key, its optional keys included.


## One overridden key and the values it takes.
class Override:
	var section: String
	var key: String
	var values: Array = []


var _base: ConfigFile = ConfigFile.new()
var _overrides: Array[Override] = []
var _problems: PackedStringArray = []


static func from_default() -> SimConfig:
	var config: SimConfig = SimConfig.new()
	var err: Error = config._base.load(TuneConfig.DEFAULT_PATH)
	if err != OK:
		config._problems.append("cannot load %s (error %d)" % [TuneConfig.DEFAULT_PATH, err])
	return config


## Everything wrong with the overrides so far. Empty when they all apply.
func problems() -> PackedStringArray:
	return _problems


## Adds `section.key=value[,value...]`. False, with a problem noted, when it
## is malformed, names an unknown key, or a value has the wrong type.
func add_override(spec: String) -> bool:
	var eq: int = spec.find("=")
	var dot: int = spec.find(".")
	if eq < 0 or dot < 0 or dot > eq:
		_problems.append("override %s is not section.key=value" % spec)
		return false
	var override: Override = Override.new()
	override.section = spec.substr(0, dot)
	override.key = spec.substr(dot + 1, eq - dot - 1)
	var existing: Variant = _existing(override.section, override.key)
	if existing == null:
		_problems.append("override %s.%s is not a config key" % [override.section, override.key])
		return false
	for text: String in _split_top_level(spec.substr(eq + 1)):
		var value: Variant = _coerce(str_to_var(text.strip_edges()), existing)
		# A string key takes its value as written, quotes or not.
		if typeof(existing) == TYPE_STRING and typeof(value) != TYPE_STRING:
			value = text.strip_edges()
		if not _same_shape(value, existing):
			_problems.append("override %s: %s has the wrong type" % [spec, text])
			return false
		override.values.append(value)
	_overrides.append(override)
	return true


## The key's value in the file, or null if it can't be overridden. A level
## section's optional key it doesn't set yet takes the shared value's type.
func _existing(section: String, key: String) -> Variant:
	if _base.has_section_key(section, key):
		return _base.get_value(section, key)
	if not section.begins_with("difficulty_") or not _base.has_section(section):
		return null
	if not TuneSchema.DIFFICULTY.has(key):
		return null
	var spec: Array = TuneSchema.DIFFICULTY[key]
	var target: String = spec[0]
	return _base.get_value(target, key, null)


## One variant per combination of override values, first override slowest.
func variants() -> Array[SimVariant]:
	var result: Array[SimVariant] = []
	var total: int = 1
	for override: Override in _overrides:
		total *= override.values.size()
	for index: int in total:
		var file: ConfigFile = ConfigFile.new()
		file.parse(_base.encode_to_text())
		var parts: PackedStringArray = []
		var rest: int = index
		for i: int in range(_overrides.size() - 1, -1, -1):
			var override: Override = _overrides[i]
			var value: Variant = override.values[rest % override.values.size()]
			rest /= override.values.size()
			file.set_value(override.section, override.key, value)
			parts.insert(0, "%s.%s=%s" % [override.section, override.key, var_to_str(value)])
		var config: TuneConfig = TuneConfig.parse(file.encode_to_text())
		for problem: String in config.problems():
			_problems.append(problem)
		result.append(SimVariant.new(" ".join(parts) if parts.size() > 0 else "default", config))
	return result


## Splits on commas outside brackets.
static func _split_top_level(text: String) -> PackedStringArray:
	var parts: PackedStringArray = []
	var depth: int = 0
	var start: int = 0
	for i: int in text.length():
		match text[i]:
			"[":
				depth += 1
			"]":
				depth -= 1
			",":
				if depth == 0:
					parts.append(text.substr(start, i - start))
					start = i + 1
	parts.append(text.substr(start))
	return parts


## Ints become floats where the config holds a float, list items included.
static func _coerce(value: Variant, existing: Variant) -> Variant:
	if typeof(value) == TYPE_INT and typeof(existing) == TYPE_FLOAT:
		var as_int: int = value
		return float(as_int)
	if typeof(value) == TYPE_ARRAY and typeof(existing) == TYPE_ARRAY:
		var items: Array = value
		var old: Array = existing
		if old.size() > 0:
			return items.map(func(item: Variant) -> Variant: return _coerce(item, old[0]))
	return value


static func _same_shape(value: Variant, existing: Variant) -> bool:
	if typeof(value) != typeof(existing):
		return false
	if typeof(value) != TYPE_ARRAY:
		return true
	var items: Array = value
	var old: Array = existing
	if old.is_empty():
		return true
	return items.all(func(item: Variant) -> bool: return typeof(item) == typeof(old[0]))
