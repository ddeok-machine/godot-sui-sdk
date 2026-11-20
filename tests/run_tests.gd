extends SceneTree

const TESTS_DIR := "res://tests"


func _init() -> void:
	var passed := 0
	var failed := 0
	var dir := DirAccess.open(TESTS_DIR)
	if dir == null:
		printerr("Cannot open ", TESTS_DIR)
		quit(1)
		return
	var files: Array[String] = []
	for f in dir.get_files():
		if f.begins_with("test_") and f.ends_with(".gd"):
			files.append(f)
	files.sort()
	for f in files:
		var script = load(TESTS_DIR.path_join(f))
		if script == null:
			print("FAIL ", f, " (failed to load)")
			failed += 1
			continue
		var inst = script.new()
		for m in inst.get_method_list():
			var name: String = m["name"]
			if not name.begins_with("test_"):
				continue
			var ok = inst.call(name)
			if ok == true:
				print("PASS ", f, "::", name)
				passed += 1
			else:
				print("FAIL ", f, "::", name)
				failed += 1
		if inst is Object and not inst is RefCounted:
			inst.free()
	print("Total: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
