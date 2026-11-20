extends RefCounted

const CFG_PATH := "res://addons/sui_sdk/plugin.cfg"
const PLUGIN_PATH := "res://addons/sui_sdk/plugin.gd"


func test_plugin_cfg_exists() -> bool:
	return FileAccess.file_exists(CFG_PATH)


func test_plugin_cfg_parses() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) != OK:
		return false
	return cfg.get_value("plugin", "name", "") == "Sui SDK"


func test_plugin_script_loads() -> bool:
	return load(PLUGIN_PATH) != null
