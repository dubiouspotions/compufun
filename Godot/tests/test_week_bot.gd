extends "res://tests/test.gd"
## The week bot: plays the week of the story files from day 1 to the ending in main.tscn, as a player
## would, through Game's public methods only, while the shop's scripts run and real time passes: it
## opens the shop, talks to each customer (picking choices at random from a seed), repairs and tests
## every computer it can, phones for the pickup and closes the shop. It fails on an error, where the
## game stops moving and when the week doesn't end, naming the day, the errand, the step and the
## snapshot. Gaps in the story that dev/story.gd lists already (STORY_GAPS), and what they cause, such
## as errands that never come, it only reports: at the end it prints what became of every errand.
## Seeds, after `--`: `-s res://tests/test_week_bot.gd -- 7 8`. docs/building-and-testing.md has more.

const GAME := preload("res://game.gd")
const WALK_PATH: String = "res://customers/conversation_walk.gd"  # loaded at run time: it names Game, which doesn't compile under -s
## Game seconds without a change of the state before the bot calls the game stuck: longer than the
## longest wait for a customer, a boot and a night.
const STUCK_SECONDS: float = 120.0
## Game seconds that the ending may take to reach its credits (Finale.stage()).
const ENDING_SECONDS: float = 120.0
## Steps of one conversation before the bot calls it endless.
const MOST_STEPS: int = 500
const DEFAULT_SEEDS: Array[int] = [1]
## Errors that come from a missing link that dev/story.gd lists, by a part of their text: reported,
## not failed, so that the writers' gaps don't fail every push.
const STORY_GAPS: Array[String] = ["has no conversation for day", "\" portrait"]

var _rng := RandomNumberGenerator.new()
var _errors := Errors.new()
## What the bot does now: [errand code, step], for the report.
var _doing: Array[String] = ["", "starts the game"]:
	set(value):
		_doing = value
		if _errors != null:
			_errors.context = _where()
## Errand file name to what happened to it, in order.
var _fate: Dictionary[String, PackedStringArray] = {}
## Gaps in the story that the week ran into.
var _gaps := PackedStringArray()
## The orders of the jobs that the bot can't repair.
var _unrepairable: Dictionary[int, bool] = {}
var _testing: Job
var _failed: bool = false


func run() -> void:
	OS.add_logger(_errors)
	game.set_process(true)
	var seeds := DEFAULT_SEEDS.duplicate()
	if not OS.get_cmdline_user_args().is_empty():
		seeds.assign(Array(OS.get_cmdline_user_args()).map(func(arg: String) -> int: return int(arg)))
	for each: int in seeds:
		paused = false  # the finale holds the world still
		game.reboot()
		var main: Node = load("res://main.tscn").instantiate()
		root.add_child(main)
		current_scene = main  # the finale plays in it
		await process_frame
		await _play_week(each)
		main.queue_free()
		await process_frame
		_errors.lines.clear()  # freeing the finale headless logs "Parameter material is null"; test_finale does too


func _play_week(with_seed: int) -> void:
	print("Week bot, seed %d" % with_seed)
	seed(with_seed)
	_rng.seed = with_seed
	_fate.clear()
	_gaps.clear()
	_unrepairable.clear()
	_testing = null
	_failed = false
	for d: Day in game.week.days:
		for errand: Errand in d.errands:
			_fate[errand.file_name()] = PackedStringArray()
	var last: Array = _progress()
	var still := 0.0
	while game.phase != GAME.Phase.ENDED and not _failed:
		_act()
		await process_frame
		var now_at: Array = _progress()
		if now_at != last:
			last = now_at
			still = 0.0
		else:
			still += 1.0 / FPS
		if still > STUCK_SECONDS:
			_fail("nothing changed for %d s" % STUCK_SECONDS)
	if not _failed:
		var ending: StringName = game.ending()
		check("seed %d: the week ends in an ending" % with_seed, ending != &"", true)
		_doing = ["", "watches the ending %s" % ending]
		var credits := false
		for frame: int in int(ENDING_SECONDS * FPS):
			var finale := get_first_node_in_group(&"finale")  # Finale.GROUP; Finale names Game, which doesn't compile under -s
			credits = finale != null and finale.call(&"stage") == &"credits"
			if credits:
				break
			await process_frame
		check("seed %d: the ending %s plays to its credits" % [with_seed, ending], credits, true)
	for line: String in _errors.lines:
		if STORY_GAPS.any(func(gap: String) -> bool: return gap in line):
			_gaps.append(line)
		else:
			check("seed %d: no error" % with_seed, line, "")
	_errors.lines.clear()
	_report(with_seed)


# One move of the player, if one is due; the rest of the time they wait.
func _act() -> void:
	match game.phase:
		GAME.Phase.CLOSED:
			_doing = ["", "opens the shop on day %d" % game.day_number]
			game.open_shop()
			return
		GAME.Phase.CALLING:
			_talk_on_phone()
			return
		GAME.Phase.OPEN:
			pass
		_:
			_doing = ["", "waits through the night after day %d" % game.day_number]
			return
	match game.visitor_state:
		GAME.VisitorState.TALKING:
			_talk()
			return
		GAME.VisitorState.WALKING_IN, GAME.VisitorState.WALKING_OUT:
			if game.visit == GAME.Visit.DROP_OFF and _fate[game.errand.file_name()].is_empty():
				_happened(game.errand, "came on day %d" % game.day_number)
			_doing = [_code(game.errand), "waits for %s to walk %s" % [_who(), "in" if game.visitor_state == GAME.VisitorState.WALKING_IN else "out"]]
	if _testing != null:
		if _testing in game.jobs and not _testing.tested:
			_doing = [_code(_testing.errand), "waits for %s's computer to boot and pass its test" % _testing.customer.spoken_name()]
			return
		_testing = null
	for job: Job in game.jobs:
		if not job.done and not _unrepairable.has(job.order) and _repair(job):
			return
	if game.visitor_state == GAME.VisitorState.WAITING:
		_doing = [_code(game.errand), "talks to %s, who waits beside the computer" % _who()]
		game.talk_to_visitor()
	elif game.can_call():
		var job: Job = game.next_to_call()
		_doing = [_code(job.errand), "phones %s for the pickup" % job.customer.spoken_name()]
		game.call_customer(job)
		_talk_on_phone()
	elif game.can_close():
		_doing = ["", "closes the shop on day %d" % game.day_number]
		_note_who_stays_away()
		game.close_shop()
	elif game.visitor == null:
		_doing = ["", "waits for the next customer on day %d" % game.day_number]


# Repairs [param job] as far as it goes, and starts its test; false when there is nothing to do.
func _repair(job: Job) -> bool:
	_doing = [_code(job.errand), "repairs %s's computer" % job.customer.spoken_name()]
	var why := _cannot_repair(job)
	if why != "":
		_unrepairable[job.order] = true
		_happened(job.errand, "can't be repaired: " + why)
		return false
	if not job.fixed:
		if job.problem.location != Problem.Location.SOFTWARE and not job.hardware_fixed:
			_repair_hardware(job)
		if job.problem.location != Problem.Location.HARDWARE and not job.software_fixed:
			_repair_software(job)
		if not job.fixed:
			_fail("the repair of %s didn't fix it: hardware %s, software %s" % [job.problem.short_name, job.hardware_fixed, job.software_fixed])
			return true
	_doing = [_code(job.errand), "tests %s's computer" % job.customer.spoken_name()]
	game.connect_cable(job)
	game.set_powered(job, true)
	if not job.powered:
		_fail("the fixed computer doesn't switch on")
	_happened(job.errand, "repaired")
	_testing = job
	return true


# Why the bot can't repair [param job], or "".
func _cannot_repair(job: Job) -> String:
	if job.problem == null:
		return "its errand has no problem, so it is never fixed, and nobody is called"
	if job.problem.location != Problem.Location.HARDWARE and job.software_check() == null:
		return "%s has a software part but no software check to fix" % job.problem.short_name
	if job.problem.location != Problem.Location.HARDWARE and game.setup_for(job) == null:
		return "%s is a software problem, but the computer has no Win95 setup" % job.problem.short_name
	return ""


# Lays the computer down, opens it, replaces every broken piece (and takes out what is in the way),
# closes it and stands it up.
func _repair_hardware(job: Job) -> void:
	game.focus_job(job)
	game.go_to_view(&"Workview")
	if not job.lying and not game.lay_down(job):
		_fail("the computer won't lie down")
		return
	_turn_screws(job, true)
	if not game.open_case(job, true):
		_fail("the side panel won't come off")
		return
	if job.blocker != null and not (game.take_blocker(job) and game.trash_part()):
		_fail("what lies in the way (%s) won't come out" % job.blocker.part.id())
		return
	for place: Part in Part.every():
		if job.piece(place) != null and job.piece(place).broken:
			_replace(job, place)
	if not game.open_case(job, false):
		_fail("the side panel won't go back on")
		return
	_turn_screws(job, false)
	if not game.stand_up(job):
		_fail("the computer won't stand up")
	game.go_to_view(&"Main")


func _turn_screws(job: Job, out: bool) -> void:
	for i: int in job.panel_screws.size():
		if job.panel_screws[i] == out and not game.turn_screw(job, i):
			_fail("screw %d won't turn %s" % [i, "out" if out else "in"])


# Takes the pieces that sit on [param place] out onto the trash, the broken piece into the trash, a
# new one from the storage in, and the others back from the trash.
func _replace(job: Job, place: Part) -> void:
	var on_top := Part.every().filter(func(other: Part) -> bool: return other.sits_on == place and job.piece(other) != null)
	for other: Part in on_top:
		if not (game.take_part(job, other) and game.trash_part()):
			_fail("%s, on top of %s, won't come out" % [other.id(), place.id()])
			return
	if not (game.take_part(job, place) and game.trash_part()):
		_fail("the broken %s won't come out" % place.id())
		return
	if not (game.take_new_part(place.piece_part()) and game.put_part(job, place)):
		_fail("a new %s won't go in" % place.piece_part().id())
		return
	on_top.reverse()
	for other: Part in on_top:
		if not (game.take_from_trash() and game.put_part(job, other)):
			_fail("%s won't go back on %s" % [other.id(), place.id()])
			return


# Connects the computer, switches it on and repairs its running Win95, which reports the fix to Game
# as the desktop's own windows do.
func _repair_software(job: Job) -> void:
	game.connect_cable(job)
	game.set_powered(job, true)
	var setup := game.setup_for(job) as Win95Setup
	job.software_check().apply_fix(setup)
	game.set_software_fixed(job, job.software_check().is_fixed(setup))


# Talks with the visitor at the counter to the end of the conversation.
func _talk() -> void:
	var dropping_off: bool = game.visit == GAME.Visit.DROP_OFF
	var errand: Errand = game.errand
	_doing = [_code(errand), "talks with %s at the %s" % [_who(), "drop-off" if dropping_off else "pickup"]]
	if game.conversation == null:
		_gaps.append("%s: %s says nothing at the counter: no conversation matches" % [_where(), errand.file_name()])
	elif not _walk():
		return
	game.dialogue_finished()
	if not dropping_off:
		_happened(errand, "picked up on day %d" % game.day_number)
	else:
		_happened(errand, ["left its computer", "brought no computer", "showed its computer"][errand.brings])


# Before closing: why each errand code still to come today stays away.
func _note_who_stays_away() -> void:
	var codes: PackedStringArray = game.day.codes()
	var blocked := ""
	for i: int in range(game.arrivals, codes.size()):
		var next: Errand = game.coming(i)
		var why := "no alternative's condition holds, or the customer is gone"
		if next != null and blocked != "":
			why = "waits behind %s" % blocked
		elif next != null:
			var theirs: Array = game.jobs.filter(func(j: Job) -> bool: return j.customer == next.customer)
			blocked = codes[i]
			why = "%s's computer from %s is still in the shop" % [next.customer.spoken_name(), _code(theirs[0].errand)] if not theirs.is_empty() else "the shop closed first"
		for each: Errand in game.day.alternatives(codes[i]):
			_happened(each, "never came: " + why)


func _talk_on_phone() -> void:
	_doing = [_code(game.calling.errand), "talks on the phone with %s" % game.calling.customer.spoken_name()]
	if game.conversation != null and not _walk():
		return
	game.hang_up()


# Walks [member Game.conversation] to its end, picking at random among the choices not picked yet
# and the leave button. False, and the bot fails, when it doesn't end.
func _walk() -> bool:
	var walk: RefCounted = (load(WALK_PATH) as GDScript).new(game.conversation)
	for step: int in MOST_STEPS:
		if walk.is_over():
			return true
		if not walk.lines().is_empty():
			walk.said()
			continue
		var options: Array = walk.choices().filter(func(c: Choice) -> bool: return not walk.was_picked(c))
		if walk.leave_text() != "":
			options.append(null)
		elif options.is_empty():
			options = walk.choices()
		if options.is_empty():
			_fail("conversation '%s' offers no choice and no way out" % game.conversation.id)
			return false
		var pick: Choice = options[_rng.randi_range(0, options.size() - 1)]
		if pick == null:
			walk.leave()
		elif not walk.pick(pick):
			_fail("picking '%s' in '%s' failed" % [pick.text, game.conversation.id])
			return false
	_fail("conversation '%s' didn't end in %d steps" % [game.conversation.id, MOST_STEPS])
	return false


# What must change while the week moves on.
func _progress() -> Array:
	return [game.phase, game.day_number, game.arrival, game.visitor_state, game.jobs.map(func(j: Job) -> Array: return [j.order, j.fixed, j.tested])]


# The game is stuck: the week stops here.
func _fail(what: String) -> void:
	_failed = true
	_flaw(what)
	printerr("  snapshot: %s" % JSON.stringify(game.snapshot(), "  "))


# Something is wrong, but the week goes on.
func _flaw(what: String) -> void:
	check("%s, and %s" % [_where(), what], false, true)


# Day, errand code and step: "day 3, errand 0302: the bot talks with ...".
func _where() -> String:
	return "day %d%s: the bot %s" % [game.day_number, ", errand " + _doing[0] if _doing[0] != "" else "", _doing[1]]


func _happened(errand: Errand, what: String) -> void:
	_fate[errand.file_name()].append(what)


func _report(with_seed: int) -> void:
	print("Week bot, seed %d: what became of each errand" % with_seed)
	var files := _fate.keys()
	files.sort()
	for file: String in files:
		var fate: PackedStringArray = _fate[file]
		print("  %s: %s" % [file, "; ".join(fate) if not fate.is_empty() else "nobody came (an alternative did)"])
	print("Week bot, seed %d: %d gaps in the story" % [with_seed, _gaps.size()])
	for gap: String in _gaps:
		print("  " + gap)


func _code(errand: Errand) -> String:
	return errand.code if errand != null else ""


func _who() -> String:
	return game.visitor.spoken_name() if game.visitor != null else "nobody"


## Every error line from push_error or a script while the bot plays, with what the bot was doing.
class Errors extends Logger:
	var lines := PackedStringArray()
	var context: String = ""
	var _mutex := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		_mutex.lock()
		var entry := ("%s: %s %s (%s:%d %s)" % [context, code, rationale, file, line, function])
		if entry not in lines:
			lines.append(entry)
		_mutex.unlock()
