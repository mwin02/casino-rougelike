class_name TuneConfig
extends RefCounted
## Reads [TUNE] values from config/tune.cfg. The whole file is checked against
## TuneSchema on load and every problem is reported. A missing or wrongly
## typed value read later is an error too, never a silent default.

const DEFAULT_PATH: String = "res://config/tune.cfg"

var _file: ConfigFile = ConfigFile.new()
var _problems: PackedStringArray = []


static func load_default() -> TuneConfig:
	return load_from(DEFAULT_PATH)


static func load_from(path: String) -> TuneConfig:
	var config: TuneConfig = TuneConfig.new()
	var err: Error = config._file.load(path)
	if err != OK:
		config._problems.append("cannot load %s (error %d)" % [path, err])
	else:
		config._check()
	config._report()
	return config


## Reads config text directly, e.g. a test's variant of the default file.
static func parse(text: String) -> TuneConfig:
	var config: TuneConfig = TuneConfig.new()
	var err: Error = config._file.parse(text)
	if err != OK:
		config._problems.append("cannot parse config text (error %d)" % err)
	else:
		config._check()
	return config


## Every mismatch with TuneSchema found on load. Empty for a good file.
func problems() -> PackedStringArray:
	return _problems


func has(section: String, key: String) -> bool:
	return _file.has_section_key(section, key)


func get_int(section: String, key: String) -> int:
	var value: Variant = _value_of(section, key)
	if typeof(value) != TYPE_INT:
		push_error("TuneConfig: %s/%s must be an int" % [section, key])
		return 0
	var result: int = value
	return result


func get_float(section: String, key: String) -> float:
	var value: Variant = _value_of(section, key)
	if typeof(value) != TYPE_FLOAT:
		push_error("TuneConfig: %s/%s must be a float" % [section, key])
		return 0.0
	var result: float = value
	return result


func get_bool(section: String, key: String) -> bool:
	var value: Variant = _value_of(section, key)
	if typeof(value) != TYPE_BOOL:
		push_error("TuneConfig: %s/%s must be a bool" % [section, key])
		return false
	var result: bool = value
	return result


func get_int_list(section: String, key: String) -> Array[int]:
	var result: Array[int] = []
	var value: Variant = _value_of(section, key)
	if not _is_list_of(value, TYPE_INT):
		push_error("TuneConfig: %s/%s must be a list of ints" % [section, key])
		return result
	var items: Array = value
	result.assign(items)
	return result


func get_float_list(section: String, key: String) -> Array[float]:
	var result: Array[float] = []
	var value: Variant = _value_of(section, key)
	if not _is_list_of(value, TYPE_FLOAT):
		push_error("TuneConfig: %s/%s must be a list of floats" % [section, key])
		return result
	var items: Array = value
	result.assign(items)
	return result


func _check() -> void:
	for section: String in TuneSchema.KEYS:
		var keys: Dictionary = TuneSchema.KEYS[section]
		for key: String in keys:
			var spec: Array = keys[key]
			var kind: TuneSchema.Kind = spec[0]
			var length: int = spec[1]
			_check_key(section, key, kind, length)
	for pair: Array in TuneSchema.PAIRED:
		var pair_section: String = pair[0]
		var first: String = pair[1]
		var second: String = pair[2]
		var minimum: int = pair[3]
		_check_pair(pair_section, first, second, minimum)
	for section: String in _file.get_sections():
		for key: String in _file.get_section_keys(section):
			if not TuneSchema.KEYS.has(section) or not TuneSchema.KEYS[section].has(key):
				_problems.append("%s/%s is not in TuneSchema" % [section, key])


func _check_key(section: String, key: String, kind: TuneSchema.Kind, length: int) -> void:
	var name: String = "%s/%s" % [section, key]
	if not has(section, key):
		_problems.append("%s is missing" % name)
		return
	var value: Variant = _file.get_value(section, key)
	var ok: bool = false
	match kind:
		TuneSchema.Kind.INT:
			ok = typeof(value) == TYPE_INT
		TuneSchema.Kind.FLOAT:
			ok = typeof(value) == TYPE_FLOAT
		TuneSchema.Kind.BOOL:
			ok = typeof(value) == TYPE_BOOL
		TuneSchema.Kind.INT_LIST:
			ok = _is_list_of(value, TYPE_INT)
		TuneSchema.Kind.FLOAT_LIST:
			ok = _is_list_of(value, TYPE_FLOAT)
	if not ok:
		_problems.append("%s must be %s" % [name, TuneSchema.Kind.keys()[kind]])
		return
	if length > 0 and typeof(value) == TYPE_ARRAY:
		var items: Array = value
		if items.size() != length:
			_problems.append("%s must have %d entries" % [name, length])


func _check_pair(section: String, first: String, second: String, minimum: int) -> void:
	var a: Variant = _file.get_value(section, first, null)
	var b: Variant = _file.get_value(section, second, null)
	if typeof(a) != TYPE_ARRAY or typeof(b) != TYPE_ARRAY:
		return
	var a_items: Array = a
	var b_items: Array = b
	if a_items.size() != b_items.size() or a_items.size() < minimum:
		_problems.append(
			"%s/%s and %s must match in length, at least %d" % [section, first, second, minimum]
		)


func _report() -> void:
	for problem: String in _problems:
		push_error("TuneConfig: " + problem)


func _is_list_of(value: Variant, type: Variant.Type) -> bool:
	if typeof(value) != TYPE_ARRAY:
		return false
	var items: Array = value
	return items.all(func(item: Variant) -> bool: return typeof(item) == type)


func _value_of(section: String, key: String) -> Variant:
	if not has(section, key):
		push_error("TuneConfig: missing %s/%s" % [section, key])
		return null
	return _file.get_value(section, key)
