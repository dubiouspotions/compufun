extends SceneTree
## Runs every tests/test_*.gd, each in its own Godot process so that each starts from a fresh Game.
## Prints the output of each test that fails, and exits 1 when any failed.
## Usage, from Godot/: godot --headless -s res://tests/run.gd

const TEST := preload("res://tests/test.gd")


func _initialize() -> void:
	var dir := "res://tests"
	var names := Array(DirAccess.get_files_at(dir)).filter(func(f: String) -> bool: return f.begins_with("test_") and f.ends_with(".gd"))
	names.sort()
	if names.is_empty():
		printerr("FAIL no %s/test_*.gd found" % dir)
		quit(1)
		return
	var failed: Array[String] = []
	for file_name: String in names:
		var path := "%s/%s" % [dir, file_name]
		var output: Array = []
		var code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", path], output, true)
		var text: String = "".join(output)
		if code == 0 and text.strip_edges().ends_with(TEST.PASSED):
			print("ok   %s" % path)
		else:
			failed.append(path)
			print("FAIL %s (exit code %d)\n%s" % [path, code, text.strip_edges()])
	print("%d of %d tests passed" % [names.size() - failed.size(), names.size()])
	if not failed.is_empty():
		print("Failed: %s" % ", ".join(failed))
	quit(1 if not failed.is_empty() else 0)
