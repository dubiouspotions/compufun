extends SceneTree
## Runs the tests/test_*.gd, each in its own Godot process so that each starts from a fresh Game, as
## many at a time as the machine has cores, at a fixed frame rate (see test.gd's FPS). Prints the
## output of each test that fails, and exits 1 when any failed.
## Usage, from Godot/: godot --headless -s res://tests/run.gd [-- WORD...]
## With words, it runs only the tests whose file name or source mentions one of them, for example
## `-- crt_tube bench` after a change to crt_tube.gd and bench.gd.

const TEST := preload("res://tests/test.gd")
const DIR := "res://tests"

var _queue: Array[String] = []
var _failed: Array[String] = []
var _mutex := Mutex.new()


func _initialize() -> void:
	var names := Array(DirAccess.get_files_at(DIR)).filter(func(f: String) -> bool: return f.begins_with("test_") and f.ends_with(".gd"))
	if names.is_empty():
		printerr("FAIL no %s/test_*.gd found" % DIR)
		quit(1)
		return
	var words := OS.get_cmdline_user_args()
	if not words.is_empty():
		names = names.filter(func(f: String) -> bool: return _mentions(f, words))
		if names.is_empty():
			printerr("FAIL no test mentions any of %s" % [words])
			quit(1)
			return
	names.sort()
	for file_name: String in names:
		_queue.append("%s/%s" % [DIR, file_name])
	var workers: Array[Thread] = []
	for i in mini(OS.get_processor_count(), names.size()):
		var worker := Thread.new()
		worker.start(_work)
		workers.append(worker)
	for worker: Thread in workers:
		worker.wait_to_finish()
	print("%d of %d tests passed" % [names.size() - _failed.size(), names.size()])
	if not _failed.is_empty():
		_failed.sort()
		print("Failed: %s" % ", ".join(_failed))
	quit(1 if not _failed.is_empty() else 0)


func _mentions(file_name: String, words: PackedStringArray) -> bool:
	var source := FileAccess.get_file_as_string("%s/%s" % [DIR, file_name])
	for word: String in words:
		if word in file_name or word in source:
			return true
	return false


# One worker: runs tests from the queue until it is empty.
func _work() -> void:
	while true:
		_mutex.lock()
		var path: String = _queue.pop_front() if not _queue.is_empty() else ""
		_mutex.unlock()
		if path == "":
			return
		var output: Array = []
		var code := OS.execute(OS.get_executable_path(), ["--headless", "--fixed-fps", str(TEST.FPS), "--path", ProjectSettings.globalize_path("res://"), "-s", path], output, true)
		var text: String = "".join(output)
		_mutex.lock()
		if code == 0 and TEST.PASSED in text.replace("\r", "").split("\n"):
			print("ok   %s" % path)
		else:
			_failed.append(path)
			print("FAIL %s (exit code %d)\n%s" % [path, code, text.strip_edges()])
		_mutex.unlock()
