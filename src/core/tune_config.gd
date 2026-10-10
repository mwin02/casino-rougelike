class_name TuneConfig
extends RefCounted
## Reads [TUNE] values from config/tune.cfg. The whole file is checked against
## TuneSchema on load and every problem is reported. A missing or wrongly
## typed value read later is an error too, never a silent default.
##
## A config is at one run difficulty (§6.3): that level's values are written
## over the shared sections, so readers never ask about the level. Loading
## gives the default level; for_difficulty() gives another, always built from
## the file as written.
##
## A config may also carry house rules (§5.2, §5.3): for_house_rule() writes
## a [house_rule_<name>] section's values over its game's section and
## [side_bets], after the level's, so a table's readers see the rules in play.

const DEFAULT_PATH: String = "res://config/tune.cfg"

## The file as written.
var _raw: ConfigFile = ConfigFile.new()
## The file with this config's level written in.
var _file: ConfigFile = ConfigFile.new()
var _difficulty: int = 0
## House rules written in, in the order applied.
var _house_rules: Array[String] = []
var _problems: PackedStringArray = []


static func load_default() -> TuneConfig:
	return load_from(DEFAULT_PATH)


static func load_from(path: String) -> TuneConfig:
	var config: TuneConfig = TuneConfig.new()
	var err: Error = config._raw.load(path)
	if err != OK:
		config._problems.append("cannot load %s (error %d)" % [path, err])
	else:
		config._at(config._default_level())
	config._report()
	return config


## Reads config text directly, e.g. a test's variant of the default file.
static func parse(text: String) -> TuneConfig:
	var config: TuneConfig = TuneConfig.new()
	var err: Error = config._raw.parse(text)
	if err != OK:
		config._problems.append("cannot parse config text (error %d)" % err)
	else:
		config._at(config._default_level())
	return config


## The same file at another difficulty level, or null if the file doesn't
## list that level.
func for_difficulty(level: int) -> TuneConfig:
	if not has_difficulty(level):
		return null
	var config: TuneConfig = TuneConfig.new()
	config._raw = _raw
	config._house_rules = _house_rules.duplicate()
	config._at(level)
	return config


## The same config with house rule name written in on top of any it already
## carries, or null if the file has no such rule.
func for_house_rule(name: String) -> TuneConfig:
	if not has_house_rule(name):
		return null
	var config: TuneConfig = TuneConfig.new()
	config._raw = _raw
	config._house_rules = _house_rules.duplicate()
	if name not in config._house_rules:
		config._house_rules.append(name)
	config._at(_difficulty)
	return config


## Every house rule the file holds, as written.
func house_rules() -> Array[String]:
	var result: Array[String] = []
	for section: String in _raw.get_sections():
		if section.begins_with(TuneSchema.HOUSE_RULE_PREFIX):
			result.append(section.trim_prefix(TuneSchema.HOUSE_RULE_PREFIX))
	return result


func has_house_rule(name: String) -> bool:
	return not name.is_empty() and _raw.has_section(_rule_section(name))


## The game a rule belongs to, as its config section, or TuneSchema.ANY_GAME.
func house_rule_game(name: String) -> String:
	var value: Variant = _raw.get_value(_rule_section(name), TuneSchema.HOUSE_RULE_GAME, "")
	return value if typeof(value) == TYPE_STRING else ""


## The house rules this config carries, in the order applied.
func applied_house_rules() -> Array[String]:
	return _house_rules.duplicate()


## The difficulty level this config is at.
func difficulty() -> int:
	return _difficulty


## Every level the file lists, easiest first as written.
func levels() -> Array[int]:
	var result: Array[int] = []
	var value: Variant = _raw.get_value("difficulty", "levels", [])
	if _is_list_of(value, TYPE_INT):
		var items: Array = value
		result.assign(items)
	return result


func has_difficulty(level: int) -> bool:
	return level in levels() and _raw.has_section(_level_section(level))


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


## Writes the level's values over the shared sections, then checks the result.
func _at(level: int) -> void:
	_difficulty = level
	_file = ConfigFile.new()
	_file.parse(_raw.encode_to_text())
	var section: String = _level_section(level)
	for key: String in TuneSchema.DIFFICULTY:
		if not _raw.has_section_key(section, key):
			continue
		var spec: Array = TuneSchema.DIFFICULTY[key]
		var target: String = spec[0]
		var value: Variant = _raw.get_value(section, key)
		if key == TuneSchema.ROLL_SHIFT:
			_shift_rolls(target, value)
		else:
			_file.set_value(target, key, value)
	for rule: String in _house_rules:
		_apply_house_rule(rule)
	_check()


## Writes the rule's well-formed overrides over their sections.
func _apply_house_rule(name: String) -> void:
	var section: String = _rule_section(name)
	for key: String in _raw.get_section_keys(section):
		if key != TuneSchema.HOUSE_RULE_GAME and _rule_key_problem(name, key).is_empty():
			var target: PackedStringArray = key.split(".")
			_file.set_value(target[0], target[1], _raw.get_value(section, key))


## Adds shift to both ends of every well-formed range in section.
func _shift_rolls(section: String, shift: Variant) -> void:
	if typeof(shift) != TYPE_FLOAT or not _file.has_section(section):
		return
	var amount: float = shift
	for key: String in _file.get_section_keys(section):
		var range_value: Variant = _file.get_value(section, key)
		if _is_list_of(range_value, TYPE_FLOAT):
			var ends: Array = range_value
			_file.set_value(section, key, ends.map(func(end: float) -> float: return end + amount))


func _default_level() -> int:
	var value: Variant = _raw.get_value("difficulty", "default", 0)
	return value if typeof(value) == TYPE_INT else 0


static func _level_section(level: int) -> String:
	return "difficulty_%d" % level


static func _rule_section(name: String) -> String:
	return TuneSchema.HOUSE_RULE_PREFIX + name


func _check() -> void:
	for section: String in TuneSchema.KEYS:
		var keys: Dictionary = TuneSchema.KEYS[section]
		for key: String in keys:
			var spec: Array = keys[key]
			var kind: TuneSchema.Kind = spec[0]
			var length: int = spec[1]
			_check_value(_file, section, key, kind, length)
	for pair: Array in TuneSchema.PAIRED:
		var pair_section: String = pair[0]
		var first: String = pair[1]
		var second: String = pair[2]
		var minimum: int = pair[3]
		_check_pair(pair_section, first, second, minimum)
	_check_difficulty()
	_check_house_rules()
	var level_sections: Array[String] = []
	for level: int in levels():
		level_sections.append(_level_section(level))
	for section: String in _raw.get_sections():
		if section in level_sections or section.begins_with(TuneSchema.HOUSE_RULE_PREFIX):
			continue
		for key: String in _raw.get_section_keys(section):
			if not TuneSchema.KEYS.has(section) or not TuneSchema.KEYS[section].has(key):
				_problems.append("%s/%s is not in TuneSchema" % [section, key])


## The default level is listed, and every listed level's section holds the
## keys TuneSchema.DIFFICULTY requires and no others. A key only a level
## sets is never also written in its shared section.
func _check_difficulty() -> void:
	if not _raw.has_section("difficulty"):
		return
	if not _default_level() in levels():
		_problems.append("difficulty/default must be one of difficulty/levels")
	for key: String in TuneSchema.DIFFICULTY:
		var spec: Array = TuneSchema.DIFFICULTY[key]
		var target: String = spec[0]
		var required: bool = spec[3]
		if required and _raw.has_section_key(target, key):
			_problems.append("%s/%s is set per difficulty" % [target, key])
	for level: int in levels():
		var section: String = _level_section(level)
		if not _raw.has_section(section):
			_problems.append("%s is missing" % section)
			continue
		for key: String in TuneSchema.DIFFICULTY:
			var spec: Array = TuneSchema.DIFFICULTY[key]
			var kind: TuneSchema.Kind = spec[1]
			var length: int = spec[2]
			var required: bool = spec[3]
			if required or _raw.has_section_key(section, key):
				_check_value(_raw, section, key, kind, length)
		for key: String in _raw.get_section_keys(section):
			if not TuneSchema.DIFFICULTY.has(key):
				_problems.append("%s/%s is not in TuneSchema" % [section, key])


## Every house rule names a game, and changes only keys TuneSchema lists in
## that game's section or [side_bets], each with a value of the key's type.
func _check_house_rules() -> void:
	for name: String in house_rules():
		var section: String = _rule_section(name)
		var game: String = house_rule_game(name)
		if game != TuneSchema.ANY_GAME and game not in TuneSchema.GAMES:
			_problems.append(
				"%s/%s must be a game or %s"
				% [section, TuneSchema.HOUSE_RULE_GAME, TuneSchema.ANY_GAME]
			)
			continue
		for key: String in _raw.get_section_keys(section):
			if key == TuneSchema.HOUSE_RULE_GAME:
				continue
			var problem: String = _rule_key_problem(name, key)
			if not problem.is_empty():
				_problems.append("%s/%s %s" % [section, key, problem])


## What is wrong with one `section.key` override of a rule; empty if nothing.
func _rule_key_problem(name: String, key: String) -> String:
	var target: PackedStringArray = key.split(".")
	var game: String = house_rule_game(name)
	if game != TuneSchema.ANY_GAME and game not in TuneSchema.GAMES:
		return "belongs to a rule with no game"
	var allowed: Array[String] = [TuneSchema.SIDE_BETS, game]
	if target.size() != 2 or target[0] not in allowed:
		return "is not a key of the rule's game or of %s" % TuneSchema.SIDE_BETS
	if not TuneSchema.KEYS.has(target[0]) or not TuneSchema.KEYS[target[0]].has(target[1]):
		return "is not in TuneSchema"
	var spec: Array = TuneSchema.KEYS[target[0]][target[1]]
	var kind: TuneSchema.Kind = spec[0]
	var length: int = spec[1]
	return _value_problem(_raw.get_value(_rule_section(name), key), kind, length)


func _check_value(
	file: ConfigFile, section: String, key: String, kind: TuneSchema.Kind, length: int
) -> void:
	var name: String = "%s/%s" % [section, key]
	if not file.has_section_key(section, key):
		_problems.append("%s is missing" % name)
		return
	var problem: String = _value_problem(file.get_value(section, key), kind, length)
	if not problem.is_empty():
		_problems.append("%s %s" % [name, problem])


## What is wrong with a value of this kind and list length; empty if nothing.
func _value_problem(value: Variant, kind: TuneSchema.Kind, length: int) -> String:
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
		return "must be %s" % TuneSchema.Kind.keys()[kind]
	if length > 0 and typeof(value) == TYPE_ARRAY:
		var items: Array = value
		if items.size() != length:
			return "must have %d entries" % length
	return ""


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
