extends SceneTree
## The base of every test. A test is a file tests/test_<name>.gd that starts with
## `extends "res://tests/test.gd"`, overrides [method run] and asserts with [method check].
## It passes when every check holds, at least one check ran, and no script error happened.
## Run one: `godot --headless --fixed-fps 60 -s res://tests/test_<name>.gd`; run all: `res://tests/run.gd`.

## The line that a test prints when it passed; [code]run.gd[/code] looks for it, because a parse error exits 0.
const PASSED: String = "TEST PASSED"
## The frames per second that a test runs at (--fixed-fps): each frame moves time by exactly 1/FPS,
## however fast the machine is, so timers, tweens and [method now] don't depend on it.
const FPS: int = 60

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


## Day [param number] with one errand per [code][customer, problem][/code] pair in [param errands],
## in order, with the errand codes of their places; a third item is the errand's conversations. The
## first customer comes in at once, and each next one a minute after the last left.
func make_day(number: int, errands: Array) -> Day:
	var d := Day.new()
	d.number = number
	for pair: Array in errands:
		var errand := Errand.new()
		errand.customer = pair[0]
		errand.problem = pair[1]
		if pair.size() > 2:
			errand.conversations.assign(pair[2])
		errand.code = "%02d%02d" % [number, d.errands.size() + 1]
		d.errands.append(errand)
	d.first_wait_seconds = Vector2.ZERO
	d.gap_seconds = Vector2(60.0, 60.0)
	return d


## Day [param number] of the week from the story files, with only the errands that bring a computer
## to leave, so a test of walking and talking doesn't depend on who the writers put first.
func computer_day(number: int) -> Day:
	var d: Day = game.day_of(number).duplicate()
	d.errands = game.day_of(number).errands.filter(func(e: Errand) -> bool: return e.brings == Errand.Brings.LEAVES)
	return d


## A software problem that [param software_check] checks.
func software_problem(software_check: SoftwareCheck) -> Problem:
	var problem := Problem.new()
	problem.location = Problem.Location.SOFTWARE
	problem.software_check = software_check
	return problem


## The seconds of game time since the test started: the frames so far over [constant FPS].
func now() -> float:
	return Engine.get_process_frames() / float(FPS)


## Runs Game's _process for [param seconds] of game time, in one step.
func tick(seconds: float) -> void:
	game.call("_process", seconds)


func _initialize() -> void:
	await process_frame
	if absf(root.get_process_delta_time() - 1.0 / FPS) > 1e-6:  # the engine hides --fixed-fps from get_cmdline_args
		printerr("FAIL %s: run it with --fixed-fps %d, so that its time doesn't follow the clock (docs/building-and-testing.md)" % [get_script().resource_path, FPS])
		quit(1)
		return
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
