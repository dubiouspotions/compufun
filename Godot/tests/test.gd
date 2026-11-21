extends SceneTree
## The base of every test. A test is a file tests/test_<name>.gd that starts with
## `extends "res://tests/test.gd"`, overrides [method run] and asserts with [method check].
## It passes when every check holds, at least one check ran, and no script error happened.
## Run one: `godot --headless -s res://tests/test_<name>.gd`; run all: `res://tests/run.gd`.

## The line that a test prints when it passed; [code]run.gd[/code] looks for it, because a parse error exits 0.
const PASSED: String = "TEST PASSED"

## The Game autoload, in its start state, with its _process off: [method tick] moves time.
var game: Node

var _checks: int = 0
var _failures: int = 0
var _script_errors := ScriptErrors.new()


## Plays the test. May await, for example [code]await process_frame[/code].
func run() -> void:
	push_error("%s does not override run()" % get_script().resource_path)


## Fails the test, naming [param label], the caller's line, [param actual] and [param expected],
## when they differ by ==. The test goes on after a failed check.
func check(label: String, actual: Variant, expected: Variant) -> void:
	_checks += 1
	if actual == expected:
		return
	_failures += 1
	var caller: Dictionary = get_stack()[1] if get_stack().size() > 1 else {}
	printerr("FAIL %s:%s %s\n  expected: %s\n  actual:   %s" % [caller.get("source", "?"), caller.get("line", "?"), label, expected, actual])


## Runs Game's _process for [param seconds] of game time, in one step.
func tick(seconds: float) -> void:
	game.call("_process", seconds)


func _initialize() -> void:
	OS.add_logger(_script_errors)
	game = root.get_node("Game")  # by path: a script that names the autoload doesn't compile under -s
	game.set_process(false)
	await run()
	var path: String = get_script().resource_path
	if _checks == 0:
		_failures += 1
		printerr("FAIL %s: no check ran" % path)
	if _script_errors.count > 0:
		_failures += 1
		printerr("FAIL %s: %d script errors, see above" % [path, _script_errors.count])
	print("%s: %d checks, %d failed" % [path, _checks, _failures])
	if _failures == 0:
		print(PASSED)
	quit(1 if _failures > 0 else 0)


class ScriptErrors extends Logger:
	var count: int = 0

	func _log_error(_function: String, _file: String, _line: int, _code: String, _rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_SCRIPT:
			count += 1
