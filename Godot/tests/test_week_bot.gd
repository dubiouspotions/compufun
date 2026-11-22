extends "res://tests/test.gd"
## The week bot: plays the week of the story files from day 1 to the ending's credits in main.tscn, in
## real game time, with the clicks and keys of a player where the game has them: it clicks the open
## sign, reads each customer's lines and clicks their choices (at random, from a seed), looks every
## computer up in CompuFunDB and prints its fix, repairs it (hardware with the parts, software through
## the Win95 computer's own settings, files and Disk Defragmenter), tests it, phones for the pickup,
## and closes the shop at the sign. It also checks that Game.restore(Game.snapshot()) keeps each
## morning as it was.
##
## It fails on an error, where the game stops moving and when the week doesn't end, naming the day,
## the errand, the step and the snapshot; and when the game has something new that it doesn't know
## (KNOWN): teach it, then list it. Gaps in the story that dev/story.gd lists already (STORY_GAPS),
## and what they cause, it only reports: at the end it prints what became of every errand.
## Seeds, after `--`: `-s res://tests/test_week_bot.gd -- 7 8`. docs/building-and-testing.md has more.

const GAME := preload("res://game.gd")
const COMPUTER_STATE_PATH: String = "res://win95/computer_state.gd"  # by path: it names Game, which doesn't compile under -s
## Game seconds without a change of the state before the bot calls the game stuck: longer than the
## longest wait for a customer, a boot, a night and a look-up in CompuFunDB.
const STUCK_SECONDS: float = 120.0
## Game seconds that the ending may take to reach its credits (Finale.stage()).
const ENDING_SECONDS: float = 120.0
## Frames between two clicks on a line that a customer says: how fast the bot reads.
const READ_FRAMES: int = 8
## Game seconds that the printer may take to print a page.
const PRINT_SECONDS: float = 10.0
const DEFAULT_SEEDS: Array[int] = [1]
## Errors that come from a missing link that dev/story.gd lists, by a part of their text: reported,
## not failed, so that the writers' gaps don't fail every push.
const STORY_GAPS: Array[String] = ["has no conversation for day", "\" portrait"]

## What the bot knows how to play. When the game gets something new here, the bot fails until it is
## taught: make it do what a player does with the new thing (or decide that a player doesn't), then
## add the name. The values of each enum that [method _act] plays:
const KNOWN_ENUMS: Dictionary[String, Array] = {
	"Game.Phase": ["IDLE", "OPEN", "CALLING", "DAY_OVER", "ENDED", "CLOSED"],
	"Game.Visit": ["NONE", "DROP_OFF", "PICKUP"],
	"Game.VisitorState": ["NONE", "WALKING_IN", "TALKING", "WALKING_OUT", "WAITING"],
	"Game.Daypart": ["NONE", "MORNING", "MIDDAY", "AFTERNOON", "EVENING", "NIGHT"],
	"Errand.Brings": ["LEAVES", "NOTHING", "SHOWS"],
	"Conversation.Trigger": ["ARRIVE", "PICKUP", "PHONE"],
	"Problem.Location": ["HARDWARE", "SOFTWARE", "BOTH"],
}
## The SoftwareCheck types that [method _fix_check] fixes the way a player does.
const KNOWN_CHECKS: Array[String] = ["SettingCheck", "FileCheck", "MultiCheck", "DesktopPrankCheck"]
## Game's public methods: those that the bot, or the scenes that it clicks, use in a week, and those
## that a week doesn't need (queries, the debug menu, the Story Lab).
const KNOWN_GAME_METHODS: Array[String] = [
	# the day, the visitor and the talk
	"start_day", "start_next_day", "has_next_day", "can_open", "open_shop", "can_close", "close_shop",
	"customer_arrived", "dialogue_finished", "talk_to_visitor", "visitor_carries", "customer_left",
	"offered", "reply_to", "choose", "go_on", "matching_conversation", "coming", "go_to_view",
	# the repair
	"focus_job", "job_beside", "lay_down", "can_stand_up", "stand_up", "open_case", "turn_screw", "can_turn",
	"can_take", "take_part", "can_put", "put_part", "take_new_part", "can_take_blocker", "take_blocker",
	"can_return_part", "return_part", "trash_part", "take_from_trash", "connect_cable", "set_powered",
	"can_power_on", "setup_for", "has_floppy", "can_eject", "eject_floppy", "set_software_fixed", "set_tested",
	# CompuFunDB and the printout
	"enter_job", "record_of", "start_db", "mark_symptom", "tick_repair", "carry_printout", "tick_printout",
	"trash_printout", "printout_box",
	# the phone and the end
	"pick_up_phone", "put_down_phone", "can_call", "next_to_call", "call_customer", "rings_out", "hang_up",
	"ending", "reboot",
	# state, flags and tools that a week doesn't need to play
	"snapshot", "restore", "load_story", "play_errand", "day_numbers", "day_of", "date_of", "check_day",
	"flag", "set_flag", "sign_flag", "gone_flag", "is_gone", "runs_cambion", "dismiss_visitor", "fix", "skip_wait",
]

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
## Job orders that the bot can't repair, looked up in CompuFunDB, or left defragmenting overnight.
var _unrepairable: Dictionary[int, bool] = {}
var _looked_up: Dictionary[int, bool] = {}
var _overnight: Dictionary[int, bool] = {}
## The choices clicked in each conversation, by its id and the choice's text.
var _clicked: Dictionary[String, bool] = {}
var _testing: Job
var _printing_since: float = -1.0
var _restored_day: int = 0
var _frame: int = 0
var _failed: bool = false
var _last_visit: Array = []
var _main: Node
var _shop: Node3D
var _camera: Camera3D


func run() -> void:
	OS.add_logger(_errors)
	_check_known()
	game.set_process(true)
	var seeds := DEFAULT_SEEDS.duplicate()
	if not OS.get_cmdline_user_args().is_empty():
		seeds.assign(Array(OS.get_cmdline_user_args()).map(func(arg: String) -> int: return int(arg)))
	for each: int in seeds:
		paused = false  # the finale holds the world still
		game.reboot()
		_main = load("res://main.tscn").instantiate()
		root.add_child(_main)
		current_scene = _main  # the finale plays in it
		_shop = _main.get_node("%Shop")
		_camera = _shop.get_node("%Camera")
		await process_frame
		await _play_week(each)
		_main.queue_free()
		await process_frame
		_errors.lines.clear()  # freeing the finale headless logs "Parameter material is null"; test_finale does too


# Fails for each enum value, SoftwareCheck type and public Game method that the bot doesn't know.
func _check_known() -> void:
	var enums: Dictionary[String, Dictionary] = {"Game.Phase": GAME.Phase, "Game.Visit": GAME.Visit, "Game.VisitorState": GAME.VisitorState,
		"Game.Daypart": GAME.Daypart, "Errand.Brings": Errand.Brings, "Conversation.Trigger": Conversation.Trigger, "Problem.Location": Problem.Location}
	for enum_name: String in enums:
		_check_list("%s values" % enum_name, enums[enum_name].keys(), KNOWN_ENUMS.get(enum_name, []))
	var checks: Array = ProjectSettings.get_global_class_list().filter(func(c: Dictionary) -> bool: return c.base == &"SoftwareCheck").map(func(c: Dictionary) -> String: return c.class)
	_check_list("SoftwareCheck types", checks, KNOWN_CHECKS)
	var methods: Array = game.get_script().get_script_method_list().map(func(m: Dictionary) -> String: return str(m.name)).filter(func(m: String) -> bool: return m.is_valid_identifier() and not m.begins_with("_"))
	_check_list("public Game methods", methods, KNOWN_GAME_METHODS)


func _check_list(what: String, found: Array, known: Array) -> void:
	var new := found.map(str).filter(func(each: String) -> bool: return each not in known)
	check("the week bot knows every one of the %s; teach it the new ones, then list them in tests/test_week_bot.gd" % what, new, [])


func _play_week(with_seed: int) -> void:
	print("Week bot, seed %d" % with_seed)
	seed(with_seed)
	_rng.seed = with_seed
	for state: Dictionary in [_fate, _unrepairable, _looked_up, _overnight, _clicked]:
		state.clear()
	_gaps.clear()
	_testing = null
	_printing_since = -1.0
	_restored_day = 0
	_failed = false
	for d: Day in game.week.days:
		for errand: Errand in d.errands:
			_fate[errand.file_name()] = PackedStringArray()
	var last: Array = _progress()
	var still := 0.0
	while game.phase != GAME.Phase.ENDED and not _failed:
		_frame += 1
		_watch()
		await _act()
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
		await _watch_ending(with_seed)
	for line: String in _errors.lines:
		if STORY_GAPS.any(func(gap: String) -> bool: return gap in line):
			_gaps.append(line)
		else:
			check("seed %d: no error" % with_seed, line, "")
	_errors.lines.clear()
	_report(with_seed)


func _watch_ending(with_seed: int) -> void:
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


# Notes what became of the errands: who came in, left a computer, took one home.
func _watch() -> void:
	var now_at := [game.arrival, game.visitor_state, game.visit, game.errand]
	if now_at == _last_visit:
		return
	var was := _last_visit
	_last_visit = now_at
	if game.errand != null and game.visit == GAME.Visit.DROP_OFF and _fate[game.errand.file_name()].is_empty():
		_happened(game.errand, "came on day %d" % game.day_number)
	if was.is_empty() or was[1] != GAME.VisitorState.TALKING or game.visitor_state == GAME.VisitorState.TALKING or was[3] == null:
		return
	var errand: Errand = was[3]
	if was[2] == GAME.Visit.PICKUP:
		_happened(errand, "picked up on day %d" % game.day_number)
	else:
		_happened(errand, ["left its computer", "brought no computer", "showed its computer"][errand.brings])


# One move of the player, if one is due; the rest of the time they wait.
func _act() -> void:
	match game.phase:
		GAME.Phase.DAY_OVER:
			_doing = ["", "waits through the night after day %d" % game.day_number]
			return
		GAME.Phase.ENDED, GAME.Phase.IDLE:
			return
		GAME.Phase.CALLING:
			await _talk_on_phone()
			return
	if _main.get_node("%EndOfDay").call(&"asking"):
		_doing = ["", "answers Yes to closing the shop on day %d" % game.day_number]
		var panel_yes: Button = _main.get_node("%EndOfDay").get_node("%Yes")
		if panel_yes.is_visible_in_tree():
			await _click(_screen_of(panel_yes, panel_yes.size / 2.0))
		else:
			await _click_button(_main.get_node("%EndOfDay"), "Yes")  # the Win95 message box, from day 4's warp
		return
	if game.visitor_state == GAME.VisitorState.TALKING:
		await _talk()
		return
	if game.phase == GAME.Phase.CLOSED:
		_doing = ["", "clicks the open sign on day %d" % game.day_number]
		await _click_in(&"Main", _shop.get_node("%OpenSign").find_child("Hotspot"))
		return
	if _restored_day != game.day_number:
		_check_restore()
		return
	if game.visitor_state in [GAME.VisitorState.WALKING_IN, GAME.VisitorState.WALKING_OUT]:
		_doing = [_code(game.errand), "waits for %s to walk %s" % [_who(), "in" if game.visitor_state == GAME.VisitorState.WALKING_IN else "out"]]
	if _testing != null:
		if _testing in game.jobs and not _testing.tested:
			_doing = [_code(_testing.errand), "waits for %s's computer to boot and pass its test" % _testing.customer.spoken_name()]
			return
		_testing = null
		game.trash_printout()
	for job: Job in game.jobs:
		if not job.done and not _unrepairable.has(job.order) and await _work_on(job):
			return
	if game.view != &"Main":
		game.go_to_view(&"Main")
	elif game.visitor_state == GAME.VisitorState.WAITING:
		_doing = [_code(game.errand), "clicks %s, who waits beside the computer" % _who()]
		await _click_in(&"Main", _shop.get_node("%VisitorHotspot"))
	elif game.can_call():
		var job: Job = game.next_to_call()
		_doing = [_code(job.errand), "clicks the phone to call %s for the pickup" % job.customer.spoken_name()]
		await _click_in(&"Main", _shop.get_node("%Phone"))
	elif game.can_close():
		_doing = ["", "clicks the open sign to close the shop on day %d" % game.day_number]
		if await _click_in(&"Main", _shop.get_node("%OpenSign").find_child("Hotspot")):
			_note_who_stays_away()
	elif game.visitor == null:
		_doing = ["", "waits for the next customer on day %d" % game.day_number]


# Each morning, once the shop is open: a restore of the snapshot keeps the state as it was.
func _check_restore() -> void:
	_restored_day = game.day_number
	_doing = ["", "restores the snapshot of day %d's morning" % game.day_number]
	var before: Dictionary = game.snapshot()
	var refused: String = game.restore(before)
	var after: Dictionary = game.snapshot()
	var changed := before.keys().filter(func(key: String) -> bool: return after.get(key) != before[key])
	check("%s: restore refuses nothing and keeps every key" % _where(), [refused, changed], ["", []])


# The next step with [param job]: look it up, repair it, test it. False when there is none.
func _work_on(job: Job) -> bool:
	var why := _cannot_repair(job)
	if why != "":
		_unrepairable[job.order] = true
		_happened(job.errand, "can't be repaired: " + why)
		return false
	if _overnight.has(job.order) and not job.software_fixed:
		return false
	if not _looked_up.has(job.order):
		return await _look_up(job)
	_doing = [_code(job.errand), "repairs %s's computer" % job.customer.spoken_name()]
	if not job.fixed:
		if job.problem.location != Problem.Location.SOFTWARE and not job.hardware_fixed:
			_repair_hardware(job)
		if job.problem.location != Problem.Location.HARDWARE and not job.software_fixed:
			_repair_software(job)
		if _overnight.has(job.order) and not job.software_fixed:
			_happened(job.errand, "left defragmenting overnight")
			return true
		if not job.fixed:
			_fail("the repair of %s didn't fix it: hardware %s, software %s" % [job.problem.short_name, job.hardware_fixed, job.software_fixed])
			return true
		_happened(job.errand, "repaired")
	_tick_printout()
	_doing = [_code(job.errand), "tests %s's computer" % job.customer.spoken_name()]
	game.connect_cable(job)
	game.set_powered(job, true)
	if not job.powered:
		_fail("the fixed computer doesn't switch on")
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


# Looks [param job] up in CompuFunDB as a player does, one step per call: opens it (it starts up once
# a day and types up the computers on the counter), marks the problem's symptoms, prints the record's
# FIX page with F and takes it from the printer.
func _look_up(job: Job) -> bool:
	var record: DbRecord = game.record_of(job)
	if _printing_since >= 0.0:
		_doing = [_code(job.errand), "takes the printed fix for %s's computer from the printer" % job.customer.spoken_name()]
		if not game.printout.is_empty():
			_check_printout(job)
			return true
		if now() - _printing_since > PRINT_SECONDS:
			_gaps.append("%s: CompuFunDB printed no FIX page for %s with its symptoms marked" % [_where(), job.problem.short_name])
			_printing_since = -1.0
			_looked_up[job.order] = true
			return true
		await _click_in(&"Right", _shop.find_child("Printer", true, false).get_node("%Hotspot"))
		return true
	_doing = [_code(job.errand), "looks up %s's computer in CompuFunDB" % job.customer.spoken_name()]
	if not game.printout.is_empty():
		game.trash_printout()
		return true
	if game.view != &"CompuFunDB":
		game.go_to_view(&"CompuFunDB")
		return true
	if game.db_day != game.day_number or record == null:
		return true  # it starts up and types the record up
	for symptom: String in job.problem.symptoms:
		game.mark_symptom(record, symptom, true)
	var listed: Array = game.records.filter(func(r: DbRecord) -> bool: return game.jobs.any(func(j: Job) -> bool: return j.order == r.job_order))
	for key: Key in [KEY_LEFT, KEY_LEFT]:
		await _press(key)
	for i: int in listed.size():
		await _press(KEY_UP)
	for i: int in listed.find(record):
		await _press(KEY_DOWN)
	await _press(KEY_F)
	_printing_since = now()
	return true


func _check_printout(job: Job) -> void:
	_printing_since = -1.0
	_looked_up[job.order] = true
	var steps := Array(game.printout).filter(func(line: String) -> bool: return GAME.printout_box(line) >= 0)
	check("%s: the printed fix lists steps to tick" % _where(), steps.is_empty(), false)
	_happened(job.errand, "looked up, %d steps printed" % steps.size())


# Ticks every step on the carried page, as the player does in pencil.
func _tick_printout() -> void:
	for line: int in game.printout.size():
		if GAME.printout_box(game.printout[line]) >= 0 and not game.tick_printout(line, true):
			_fail("line %d of the printout won't tick" % line)


# Lays the computer down, opens it, replaces every broken piece (and takes out what is in the way),
# closes it and stands it up: what the clicks in the Workview do.
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


# Connects the computer, switches it on and fixes its Windows as a player does; the computer reports
# the fix to Game itself.
func _repair_software(job: Job) -> void:
	game.connect_cable(job)
	game.set_powered(job, true)
	var state := _state_of(job)
	if state == null:
		_fail("no ComputerState runs %s's computer" % job.customer.spoken_name())
		return
	_fix_check(job, job.software_check(), state)


# Fixes what [param software] broke, through the running computer [param state] as the Win95 windows
# do: the volume control, the drive's eject button, Disk Defragmenter (done the next morning), a
# Control Panel property sheet, a rename in Explorer and a save in Notepad, Display Properties and a
# drag of the icons.
func _fix_check(job: Job, software: SoftwareCheck, state: Node) -> void:
	var setup: Win95Setup = state.get(&"setup")
	match software.get_script().get_global_name():
		&"MultiCheck":
			for each: SoftwareCheck in (software as MultiCheck).checks:
				_fix_check(job, each, state)
		&"FileCheck":
			var file_check := software as FileCheck
			var file := file_check.broken_file(setup)
			if file == null:
				_fail("%s isn't on the computer to fix" % file_check.path)
				return
			state.call(&"rename_file", file, file_check.healthy_name())
			if file_check.fixed_contents(file.contents) != file.contents:
				state.call(&"write_text", file, file_check.fixed_contents(file.contents))
		&"DesktopPrankCheck":
			var shot := setup.desktop_screenshot
			if shot != null:
				var wallpaper: Dictionary[StringName, Variant] = {&"wallpaper": shot.wallpaper}
				state.call(&"apply_settings", wallpaper)
				var hidden: Array[Win95File] = []
				hidden.assign(shot.icons.filter(func(icon: Win95File) -> bool: return not setup.desktop.has(icon)))
				state.call(&"move_files", hidden, setup.desktop)
		&"SettingCheck":
			var setting := software as SettingCheck
			match setting.setting:
				&"muted":
					state.call(&"set_sound", setup.volume, false)
				&"floppy_in_a":
					game.eject_floppy(job)
					game.trash_part()
				&"fragmented":
					state.call(&"start_defrag")
					_overnight[job.order] = true
				_:
					var values: Dictionary[StringName, Variant] = {setting.setting: setting.fix_value()}
					state.call(&"apply_settings", values)
		var other:
			_fail("the week bot doesn't know how a player fixes a %s" % other)


# The ComputerState that runs [param job]'s computer, or null.
func _state_of(job: Job) -> Node:
	var script: Script = load(COMPUTER_STATE_PATH)
	for node: Node in _main.find_children("*", "Node", true, false):
		if node.get_script() == script and node.get(&"job") == job:
			return node
	return null


# Reads the visitor's lines, a click at a time, and clicks one of the choices when they show: one not
# clicked yet in this conversation, or the button that leaves the list. The dialogue ends itself.
func _talk() -> void:
	_doing = [_code(game.errand), "talks with %s at the %s" % [_who(), "drop-off" if game.visit == GAME.Visit.DROP_OFF else "pickup"]]
	if game.view != &"Main":
		game.go_to_view(&"Main")  # the dialogue shows while the player faces the customer
		return
	var overlay: Control = _main.get_node("%DialogueOverlay")
	var buttons := _buttons_in(overlay)
	if buttons.any(func(b: Button) -> bool: return b.disabled or b.modulate.a < 0.999):
		return  # they fade in, or a pick fades the others out
	if buttons.is_empty():
		if _frame % READ_FRAMES == 0:
			await _click(_screen_of(overlay.get_node("Box"), Vector2(40.0, 40.0)))
		return
	var id := String(game.conversation.id) if game.conversation != null else ""
	var leaving := ["> " + game.conversation.leave_text, "> " + game.conversation.back_text] if game.conversation != null else []
	var options := buttons.filter(func(b: Button) -> bool: return b.text in leaving or not _clicked.has(id + b.text))
	if options.is_empty():
		options = buttons
	var pick: Button = options[_rng.randi_range(0, options.size() - 1)]
	_clicked[id + pick.text] = true
	await _click(_screen_of(pick, pick.size / 2.0))


# Clicks through the call's lines; the phone hangs up after the last.
func _talk_on_phone() -> void:
	_doing = [_code(game.calling.errand), "talks on the phone with %s" % game.calling.customer.spoken_name()]
	if _frame % READ_FRAMES == 0:
		await _click(_screen_of(_main.get_node("%PhoneCall/Box"), Vector2(40.0, 40.0)))


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


# --- Input, as a player gives it.

# Clicks [param hotspot] once the camera has settled in [param view]; false while it turns there.
func _click_in(view: StringName, hotspot: Node3D) -> bool:
	if game.view != view:
		game.go_to_view(view)
		return false
	var marker: Node3D = _shop.call(&"view_marker", view)
	if _camera.global_position.distance_to(marker.global_position) > 0.001 or _camera.quaternion.angle_to(marker.global_basis.get_rotation_quaternion()) > 0.001:
		return false
	await _click(_from_viewport(_camera.get_viewport(), _camera.unproject_position(hotspot.global_position)))
	return true


# Clicks the visible button with [param text] under [param parent].
func _click_button(parent: Node, text: String) -> void:
	for button: Button in _buttons_in(parent):
		if button.text == text:
			await _click(_screen_of(button, button.size / 2.0))
			return


func _buttons_in(parent: Node) -> Array[Button]:
	var found: Array[Button] = []
	for node: Node in parent.find_children("*", "Button", true, false):
		var button := node as Button
		if button.is_visible_in_tree() and not button.is_queued_for_deletion():
			found.append(button)
	return found


# [param local], in [param item]'s coordinates, in the window's, through the SubViewports above it.
func _screen_of(item: CanvasItem, local: Vector2) -> Vector2:
	return _from_viewport(item.get_viewport(), item.get_global_transform_with_canvas() * local)


func _from_viewport(viewport: Viewport, at: Vector2) -> Vector2:
	while viewport != root:
		var container := viewport.get_parent() as SubViewportContainer
		at = container.get_global_transform_with_canvas() * (at * container.size / Vector2((viewport as SubViewport).size))
		viewport = container.get_viewport()
	return at


# A left click at [param at] in the window: the mouse moves there, presses and lets go, with a physics
# frame after each, as physics picking needs.
func _click(at: Vector2) -> void:
	var position := root.get_final_transform() * at
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	Input.parse_input_event(motion)
	for pressed: bool in [true, false]:
		var button := InputEventMouseButton.new()
		button.button_index = MOUSE_BUTTON_LEFT
		button.pressed = pressed
		button.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		button.position = position
		button.global_position = position
		Input.parse_input_event(button)
		Input.flush_buffered_events()
		await physics_frame
		await process_frame


func _press(key: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame


# --- The report.

# What must change while the week moves on.
func _progress() -> Array:
	return [game.phase, game.day_number, game.arrival, game.visitor_state, game.view, game.records.size(), game.printout.size(),
		game.jobs.map(func(j: Job) -> Array: return [j.order, j.fixed, j.tested])]


# The game is stuck: the week stops here.
func _fail(what: String) -> void:
	_failed = true
	check("%s, and %s" % [_where(), what], false, true)
	printerr("  snapshot: %s" % JSON.stringify(game.snapshot(), "  "))


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
