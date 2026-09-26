class_name TuneConfig
extends RefCounted
## Reads [TUNE] values from config/tune.cfg. A missing or wrongly typed value
## is an error, never a silent default. Block 1 widens this.

const DEFAULT_PATH: String = "res://config/tune.cfg"

var _file: ConfigFile = ConfigFile.new()


static func load_default() -> TuneConfig:
	return load_from(DEFAULT_PATH)


static func load_from(path: String) -> TuneConfig:
	var config: TuneConfig = TuneConfig.new()
	var err: Error = config._file.load(path)
	if err != OK:
		push_error("TuneConfig: cannot load %s (error %d)" % [path, err])
	return config


func get_int(section: String, key: String) -> int:
	var value: Variant = _value_of(section, key)
	if typeof(value) != TYPE_INT:
		push_error("TuneConfig: %s/%s must be an int" % [section, key])
		return 0
	var result: int = value
	return result


func get_bool(section: String, key: String) -> bool:
	var value: Variant = _value_of(section, key)
	if typeof(value) != TYPE_BOOL:
		push_error("TuneConfig: %s/%s must be a bool" % [section, key])
		return false
	var result: bool = value
	return result


func _value_of(section: String, key: String) -> Variant:
	if not _file.has_section_key(section, key):
		push_error("TuneConfig: missing %s/%s" % [section, key])
		return null
	return _file.get_value(section, key)
