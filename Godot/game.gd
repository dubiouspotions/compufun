extends Node
## The state that the whole game shares (autoload "Game"): the day, the visitor, the jobs on the
## counter, the computer in focus, the cable, the phone, the printout that the player carries, the
## view, the flags and the conversations that have played. Scenes call its methods, and re-read the
## state on [signal changed].

## Emitted after every change of the state. Listeners re-read the whole state.
signal changed
## Emitted when the player tries to take a page from the printer while they carry one; nothing changed.
signal printout_refused

enum Phase {
	IDLE, ## No day has started.
	OPEN, ## The shop is open: customers come in, and the player repairs and calls.
	CALLING, ## The phone is calling a customer to pick up a computer.
	DAY_OVER, ## The player closed the shop for the night.
	ENDED, ## The player closed the shop on the last day: Cambion takes them, and time and space bluescreen.
	CLOSED, ## The day started, and the shop isn't open yet: nobody comes in until [method open_shop].
}

## Why the visitor is in the shop.
enum Visit {
	NONE, ## Nobody is in the shop.
	DROP_OFF, ## The visitor brings a computer.
	PICKUP, ## The visitor takes a finished computer home.
}

## The time of day. The customers and closing move it forward; time does not pass on its own.
enum Daypart {
	NONE, ## No day has started.
	MORNING, ## The day started; the player opens the shop, and the first customer comes in.
	MIDDAY, ## The second customer came in.
	AFTERNOON, ## The third customer came in.
	EVENING, ## The player closed the shop.
	NIGHT, ## Not reached in play; the debug menu shows it.
}

enum VisitorState {
	NONE, ## Nobody is in the shop.
	WALKING_IN, ## The visitor walks from the door to the counter.
	TALKING, ## The visitor talks at the counter.
	WALKING_OUT, ## The visitor has handed the computer over and walks from the counter to the door.
	WAITING, ## The visitor's computer stands on the counter while they wait beside it ([constant Errand.Brings.SHOWS]), until [method talk_to_visitor].
}

## The places on the counter. A full counter holds back the next drop-off.
const MAX_JOBS: int = 4
## The most errand codes that a Day may have: the most visitors that it brings.
const MAX_CUSTOMERS: int = 4
## The date of day 1, so that day 7 is 6/6/96.
const FIRST_DATE: String = "1996-05-31"
## Where the problem with a short name lives, as a job in an older snapshot names it.
const PROBLEM_PATH: String = "res://problems/%s.tres"
## The folder of the endings, one Ending per file.
const ENDINGS_FOLDER: String = "res://endings/"
## Snapshot keys that the game no longer has, which [method restore] skips so that old F9 reports
## still restore: "stored" held the parts in the storage bin, which no longer takes parts.
const RETIRED_KEYS: Array[String] = ["stored"]
## What a pickup visitor says when no PICKUP conversation of theirs matches: one of its lines, the
## same one for each customer ([method _thanks]).
const THANKS: Conversation = preload("res://customers/conversations/thanks.tres")

var phase: Phase = Phase.IDLE
## The week that plays, from the story files ([method load_story]); null until a load without
## errors.
var week: StoryFiles.Week
## The errors of the story files at the last [method load_story], one "path:line: what" each;
## empty when the week loaded.
var story_errors: PackedStringArray = []
var day: Day
## How far down the day's errand codes ([method Day.codes]) today has come, 0 to their number:
## each code before it came in, or stays away for good ([method is_gone], or no alternative
## matched).
var arrivals: int = 0
## Set by [method start_day], each arrival and [method close_shop]; the Outside shows it.
var daypart: Daypart = Daypart.NONE
## The computers on the counter, oldest drop-off first. Jobs left overnight stay.
var jobs: Array[Job] = []
## The computer that the player works on in the Workview, or null for none.
var focus: Job
## The computer that the VGA cable is connected to, or null when the cable hangs free.
var connected: Job
## The computer whose customer the phone is calling, while the phase is CALLING; null otherwise.
var calling: Job
## The player holds the phone's receiver: picking whom to call, or on a call. The phone and a
## visitor never meet: it can't be picked up while someone is in the shop, and nobody comes in
## while it is off the hook.
var phone_off_hook: bool = false
## The part in the player's hand, or null. The hand holds one piece at a time.
var hand: Piece
## The pieces that the player threw in the trash can, the last one last. Never emptied.
var trashed: Array[Piece] = []
## The printout that the player carries, line by line as the printer printed it; empty while they
## carry none. It is apart from the hand, the player can't put it down, and only the trash can or the
## start of the next day takes it.
var printout: PackedStringArray = []
## The lines of [member printout] whose check box the player ticked, by index. They are the player's
## own notes: they change no record and no job.
var printout_ticks: Array[int] = []
## The customer in the shop, or null when nobody is in.
var visitor: Customer
## The errand that the visitor is in for: on a drop-off the one that came, on a pickup their
## job's; null when nobody is in, and for a pickup visitor whom a restore sets walking out.
var errand: Errand
var visit: Visit = Visit.NONE
var visitor_state: VisitorState = VisitorState.NONE
## The name of the current view marker in the room, for example &"Main".
var view: StringName = &"Main"
## The facts of the story: a name and a number. A flag that is 0 or missing is not set.
var flags: Dictionary[StringName, int] = {}
## The conversations that have played, by [member Conversation.id], such as "0102/drop-off/1".
var seen: Dictionary[String, bool] = {}
## The records that the player made in CompuFunDB, oldest first. They last the whole game.
var records: Array[DbRecord] = []
## The day on which CompuFunDB last started up (the work computer booted and the modem dialled
## up); 0 before its first start-up.
var db_day: int = 0
## What the visitor says while TALKING, or what the called customer says on the phone while
## CALLING (no lines: nobody answers, see [method rings_out]); null when no conversation matches.
var conversation: Conversation
## Goes up every time a visitor starts to walk in or a waiting visitor starts their pickup, also on
## [method restore]. A scene that remembers it can tell a new visit from a re-read of the same one.
var arrival: int = 0
## Goes up on every [method start_day] and [method restore]: the state jumped there instead of
## changing by a step of play. A scene that remembers it shows the new state at once, without the
## sounds and animations of a change.
var jump: int = 0
## The running copy of each computer's Win95 setup, made at its first boot. It lasts for the whole
## game, also through [method restore], so a customer who comes back brings the computer as the
## player left it. Use [method setup_for].
var setups: Dictionary[Computer, Win95Setup] = {}

## The number of the day, 1 to 7, or 0 before the first day.
var day_number: int:
	get:
		return day.number if day != null else 0

## How far Cambion has changed the shop today, 0 to 1 ([member Day.warp]); 0 before the first day.
var warp: float:
	get:
		return day.warp if day != null else 0.0

## The calendar date of the current day (day 1 before the first day), as a Time datetime
## dictionary: year, month, day, weekday.
var date: Dictionary:
	get:
		return date_of(day_number)

var _next_order: int = 0
var _waited: float = 0.0
var _wait: float = 0.0
var _pickup: Job


func _init() -> void:
	changed.connect(_forget_tests)


func _ready() -> void:
	var errors := load_story()
	for error: String in errors:
		push_error("Game: " + error)


# A computer that stops being fixed needs a new test.
func _forget_tests() -> void:
	for job in jobs:
		if not job.fixed:
			job.tested = false


## The calendar date of day [param number] (day 1 for 0 or less), as a Time datetime dictionary:
## year, month, day, weekday (0 is Sunday).
func date_of(number: int) -> Dictionary:
	var unix := Time.get_unix_time_from_datetime_string(FIRST_DATE) + maxi(number - 1, 0) * 86400
	return Time.get_datetime_dict_from_unix_time(unix)


# A computer left on overnight finishes what it was doing: Disk Defragmenter.
func _finish_overnight_work() -> void:
	for job in jobs:
		var setup: Win95Setup = setups.get(job.customer.computer)
		if setup == null or not job.powered or not setup.defragmenting:
			continue
		setup.defragmenting = false
		setup.fragmented = false
		if job.software_check() != null:
			job.software_fixed = job.software_check().is_fixed(setup)


## Starts [param new_day] in the morning with the shop CLOSED: nobody comes in until
## [method open_shop]. Jobs left overnight stay, and those computers that stayed on finish their
## Disk Defragmenter run. The player no longer carries a printout. The last day's
## [member Day.close_signs] stop, and the new day sets its [member Day.set_flags]. Refuses a day
## that [method check_day] refuses, and keeps the current state.
func start_day(new_day: Day) -> void:
	var invalid := check_day(new_day)
	if invalid != "":
		push_error("Game.start_day: " + invalid)
		return
	if day != null:
		for id: StringName in day.close_signs:
			flags.erase(sign_flag(id))
	day = new_day
	phone_off_hook = false
	printout = []
	printout_ticks.clear()
	_finish_overnight_work()
	arrivals = 0
	daypart = Daypart.MORNING
	phase = Phase.CLOSED
	_set_flags(new_day.set_flags, "day %d" % new_day.number)
	_set_visitor(null, Visit.NONE)
	jump += 1
	changed.emit()


func go_to_view(view_name: StringName) -> void:
	if view_name == &"" or view_name == view:
		return
	view = view_name
	changed.emit()


## The room calls this when the visitor reaches the counter: TALKING, with the first conversation
## that matches. A pickup visitor with no matching conversation says a short thanks.
func customer_arrived() -> void:
	if visitor_state != VisitorState.WALKING_IN:
		push_error("Game.customer_arrived: no visitor is walking in (visitor state %s)" % VisitorState.find_key(visitor_state))
		return
	visitor_state = VisitorState.TALKING
	_start_talk()
	changed.emit()


## The dialogue calls this after its last line. A drop-off puts the computer in the first free slot
## (in focus if nothing is), unless the errand brings none; a pickup takes its job off the counter,
## clears [member focus] and [member connected] if they pointed at it, and shifts the computers right
## of it left, so that the counter holds them oldest first from slot 0. Then the visitor walks out
## (WALKING_OUT), or, when they only show their computer, waits beside it (WAITING).
func dialogue_finished() -> void:
	if visitor_state != VisitorState.TALKING:
		push_error("Game.dialogue_finished: no visitor is talking (visitor state %s)" % VisitorState.find_key(visitor_state))
		return
	conversation = null
	_leave()
	changed.emit()


## The player turns to the visitor who waits beside the computer that they show (WAITING): their
## pickup conversation plays (TALKING, PICKUP), and after it they take the computer and go. False,
## and nothing changes, unless a visitor waits.
func talk_to_visitor() -> bool:
	if visitor_state != VisitorState.WAITING:
		return false
	visit = Visit.PICKUP
	visitor_state = VisitorState.TALKING
	arrival += 1
	_start_talk()
	changed.emit()
	return true


## True while the visitor carries their computer: in on a drop-off that brings one, and out after a
## pickup.
func visitor_carries() -> bool:
	match visitor_state:
		VisitorState.WALKING_IN, VisitorState.TALKING:
			return visit == Visit.DROP_OFF and errand != null and errand.brings != Errand.Brings.NOTHING
		VisitorState.WALKING_OUT:
			return visit == Visit.PICKUP
	return false


## The room calls this when the visitor who walks out reaches the door. The visit ends, and the
## wait for the next customer starts.
func customer_left() -> void:
	if visitor_state != VisitorState.WALKING_OUT:
		push_error("Game.customer_left: no visitor is walking out (visitor state %s)" % VisitorState.find_key(visitor_state))
		return
	_set_visitor(null, Visit.NONE)
	changed.emit()


## Loads the week from the story files with [param drafts] over them (see [method StoryFiles.load_week])
## and plays it from now on: a day that plays goes on in the new week, as [method restore] of the
## [method snapshot] sets it. Returns the errors, one "path:line: what" each, also in
## [member story_errors]; with any, the week that plays stays as it was. The game loads the week
## once as it starts.
func load_story(drafts: Dictionary[String, String] = {}) -> PackedStringArray:
	var loaded := StoryFiles.load_week(drafts)
	var errors := loaded.errors.duplicate()
	for d: Day in loaded.days:
		var invalid := check_day(d) if errors.is_empty() else ""  # a file that didn't parse fails check_day too
		if invalid != "":
			errors.append("%sday_%d.day: %s" % [StoryFiles.DAYS_DIR, d.number, invalid])
	if errors.is_empty():
		var playing := week
		week = loaded
		if day != null:
			var refused := restore(snapshot())
			if refused != "":
				week = playing
				errors.append("The game can't go on in the new week, so it plays the old one: " + refused)
	story_errors = errors
	return errors


## Jumps to the day of [param to_play], an errand of the week that plays (by file name, so the
## Story Lab can pass its own parse of the file after [method load_story]), as [method restore] sets
## it: the errands before it came and went, with their computers, so the counter is empty; the
## flags as they are, with the day's [member Day.set_flags] on top and the customer not gone; the
## errand's conversations not yet seen. Then the conversation for [param trigger] plays:
## [constant Conversation.Trigger.ARRIVE] with the customer at the counter, PICKUP with them at the
## counter and their computer fixed and tested on it, PHONE with the call on about that computer.
## For the Story Lab's Play here. Returns "" or why it can't, and then keeps the state.
func play_errand(to_play: Errand, trigger: Conversation.Trigger = Conversation.Trigger.ARRIVE) -> String:
	if to_play == null or to_play.file == "":
		return _refuse_play("play_errand needs an errand from a story file, not %s" % to_play)
	var found: Variant = _job_errand({"errand": to_play.file_name()}, to_play.day_number()) if week != null else "the story files didn't load"
	if found is String:
		return _refuse_play("%s; load its draft with load_story first" % found)
	var target: Errand = found
	var on_day := day_of(target.day_number())
	var new_flags := flags.duplicate()
	for flag_name: StringName in on_day.set_flags:
		new_flags[flag_name] = on_day.set_flags[flag_name]
	new_flags.erase(gone_flag(target.customer))
	var state := {
		"day": on_day.number,
		"phase": "OPEN",
		"arrivals": on_day.codes().find(target.code) + 1,
		"flags": new_flags,
		"seen": seen.keys().filter(func(key: String) -> bool: return not key.begins_with(target.code + "/")),
		"view": "Main",
	}
	var done := {"errand": target.file_name(), "slot": 0, "hardware_fixed": true, "software_fixed": true, "tested": true}
	match trigger:
		Conversation.Trigger.ARRIVE:
			state.merge({"visitor": target.customer.resource_path, "visit": "DROP_OFF", "visitor_state": "TALKING"})
		Conversation.Trigger.PICKUP, Conversation.Trigger.PHONE:
			if target.brings == Errand.Brings.NOTHING:
				return _refuse_play("%s brings no computer, so there is nothing to pick up or call about" % target.file_name())
			state.merge({"jobs": [done], "focus_slot": 0})
			if trigger == Conversation.Trigger.PICKUP:
				state.merge({"visitor": target.customer.resource_path, "visit": "PICKUP", "visitor_state": "TALKING"})
			else:
				state.merge({"phase": "CALLING", "calling_slot": 0}, true)
	var refused := restore(state)
	if refused == "" and visitor != null and errand != target:
		errand = target  # another alternative of the same customer matched first
		_start_talk()
		changed.emit()
	return refused


## The day numbers of the week that plays, from 1, in order; none before it loaded.
func day_numbers() -> Array[int]:
	var found: Array[int] = []
	if week != null:
		for d: Day in week.days:
			found.append(d.number)
	return found


## Day [param number] of the week that plays, or null when there is none.
func day_of(number: int) -> Day:
	return week.days[number - 1] if week != null and number >= 1 and number <= week.days.size() else null


## Sends the visitor away for good, as the [x] of the corruption sign customer_x does: they vanish
## at once, with every computer of theirs on the counter, and never come in again, also not on a
## later day or for a pickup ([method is_gone]); the flag gone_<customer file name> records it.
## Fails with an error when nobody is in.
func dismiss_visitor() -> void:
	if visitor == null:
		push_error("Game.dismiss_visitor: nobody is in the shop")
		return
	flags[gone_flag(visitor)] = 1
	for job: Job in jobs.filter(func(j: Job) -> bool: return j.customer == visitor):
		_take_off_counter(job)
	_pickup = null
	_set_visitor(null, Visit.NONE)
	changed.emit()


## True when [method dismiss_visitor] sent [param who] away for good.
func is_gone(who: Customer) -> bool:
	return flag(gone_flag(who)) != 0


## True while [param who]'s computer runs Win95 Cambion, the possessed build (wiki: Storyline): the
## flag <customer file name>_runs_cambion is set. Some corruption signs show only in such a computer.
func runs_cambion(who: Customer) -> bool:
	return flag(StringName(_id_of(who) + "_runs_cambion")) != 0


## The flag that records that [param who] is gone for good: gone_<customer file name>.
func gone_flag(who: Customer) -> StringName:
	return StringName("gone_" + _id_of(who))


## The number of [param flag_name]; 0 when it is not set.
func flag(flag_name: StringName) -> int:
	return flags.get(flag_name, 0)


## The flag that starts the corruption sign [param id]: sign_<id>.
func sign_flag(id: StringName) -> StringName:
	return StringName("sign_%s" % id)


## Sets [param flag_name] to [param value]. 0 removes it.
func set_flag(flag_name: StringName, value: int = 1) -> void:
	if flag_name == &"":
		push_error("Game.set_flag: no flag name")
		return
	_put_flag(flag_name, value)
	changed.emit()


func _put_flag(flag_name: StringName, value: int) -> void:
	if value == 0:
		flags.erase(flag_name)
	else:
		flags[flag_name] = value


## The choices of [param reply] that the player can say now: their condition matches, and one of
## their replies can play. In the reply's order.
func offered(reply: Reply) -> Array[Choice]:
	var found: Array[Choice] = []
	if reply == null:
		return found
	for choice: Choice in reply.choices:
		if choice != null and _met(choice.when) and reply_to(choice) != null:
			found.append(choice)
	return found


## The reply that [param choice] gets now: the first whose condition matches; null when none does.
func reply_to(choice: Choice) -> Reply:
	for reply: Reply in choice.replies:
		if reply != null and _met(reply.when):
			return reply
	return null


## The player says [param choice] to the customer who talks or answers the phone: their reply plays
## and sets its flags. Returns the reply; null, with an error, when nobody talks or no reply can play.
func choose(choice: Choice) -> Reply:
	if conversation == null or choice == null:
		push_error("Game.choose: no conversation plays, or no choice (%s)" % choice)
		return null
	var reply := reply_to(choice)
	if reply == null:
		push_error("Game.choose: '%s' has no reply that can play on day %d with flags %s" % [choice.text, day_number, flags])
		return null
	_set_flags(reply.set_flags, "a reply to '%s'" % choice.text)
	changed.emit()
	return reply


## The conversation that plays goes on below a list to [param reply], a [member Reply.then]: sets its
## flags. Fails with an error when nobody talks.
func go_on(reply: Reply) -> void:
	if conversation == null or reply == null:
		push_error("Game.go_on: no conversation plays, or no reply (%s)" % reply)
		return
	_set_flags(reply.set_flags, "the lines below a list in '%s'" % conversation.id)
	changed.emit()


func _met(when: Condition) -> bool:
	return when == null or when.is_met(day_number, flags)


## The first conversation of [param from] with [param trigger] whose condition matches now, and
## that has not played if it plays once. null when none matches, or [param from] is null.
func matching_conversation(from: Errand, trigger: Conversation.Trigger) -> Conversation:
	if from == null:
		return null
	for c: Conversation in from.conversations:
		if c == null or c.trigger != trigger:
			continue
		if c.once and seen.has(String(c.id)):
			continue
		if not _met(c.when):
			continue
		return c
	return null


## Switches the computer in focus off and lays it on its side in the Workview, so the player can
## reach its side panel ([member Job.lying]); it lies until [method stand_up], also while the player
## looks elsewhere. False, and nothing changes, when [param job] is not in focus in the Workview or
## already lies.
func lay_down(job: Job) -> bool:
	if not _on_counter(job, "lay_down") or job != focus or view != &"Workview" or job.lying:
		return false
	job.powered = false
	job.lying = true
	changed.emit()
	return true


## True when the lying computer of [param job] can stand up: its side panel is on, with every
## screw in.
func can_stand_up(job: Job) -> bool:
	return job.lying and not job.case_open and not job.panel_screws.has(false)


## Stands the lying computer of [param job] up again. False, and nothing changes, unless
## [method can_stand_up].
func stand_up(job: Job) -> bool:
	if not _on_counter(job, "stand_up") or not can_stand_up(job):
		return false
	job.lying = false
	changed.emit()
	return true


## Puts [param job] in focus for the Workview. null takes the focus away. The job must be on the
## counter.
func focus_job(job: Job) -> void:
	if job != null and job not in jobs:
		push_error("Game.focus_job: the job of %s is not on the counter" % _who(job.customer))
		return
	focus = job
	changed.emit()


## Connects the VGA cable to [param job]: the bench screen shows that computer as the cable left
## it. null disconnects. The job must be on the counter.
func connect_cable(job: Job) -> void:
	if job != null and job not in jobs:
		push_error("Game.connect_cable: the job of %s is not on the counter" % _who(job.customer))
		return
	connected = job
	changed.emit()


## Marks a part of a repair as done: HARDWARE on the job in [member focus], SOFTWARE on the
## [member connected] job. Fails with an error when that job is null.
func fix(location: Problem.Location) -> void:
	match location:
		Problem.Location.HARDWARE:
			if focus == null:
				push_error("Game.fix(HARDWARE): no computer is in focus")
				return
			focus.hardware_fixed = true
		Problem.Location.SOFTWARE:
			if connected == null:
				push_error("Game.fix(SOFTWARE): no computer is connected")
				return
			connected.software_fixed = true
		_:
			push_error("Game.fix: give HARDWARE or SOFTWARE, not %s" % location)
			return
	changed.emit()


## The running copy of [param job]'s Win95 setup, or null when its computer has none. The first
## call for a computer copies its Win95Setup; the first call for a job breaks the copy as the job's
## problem says, on top of what earlier visits left.
func setup_for(job: Job) -> Win95Setup:
	var computer := job.customer.computer
	if computer == null or computer.win95_setup == null:
		return null
	var setup: Win95Setup = setups.get(computer)
	if setup == null:
		setup = computer.win95_setup.copy()
		setups[computer] = setup
	if not job.broken:
		job.broken = true
		if job.software_check() != null:
			job.software_check().apply_break(setup)
	return setup


## Switches [param job] on or off. The screen shows the [member connected] job while it is on.
## The job must be on the counter.
func set_powered(job: Job, on: bool) -> void:
	if job == null or job not in jobs:
		push_error("Game.set_powered: the job is not on the counter: %s" % job)
		return
	if on == job.powered:
		return
	if on and not can_power_on(job):
		return
	job.powered = on
	changed.emit()


## True when a floppy is in drive A: of [param job]'s computer (Win95Setup.floppy_in_a of its running
## copy); false for a job without a Win95 setup.
func has_floppy(job: Job) -> bool:
	var setup := setup_for(job)
	return setup != null and setup.floppy_in_a


## Ejects the floppy from drive A: of [param job]'s computer, as a click on the case's floppy drive
## does, so the next boot gets past "Non-System disk". Does nothing when no floppy is in. The job must
## be on the counter.
func eject_floppy(job: Job) -> void:
	if job == null or job not in jobs:
		push_error("Game.eject_floppy: the job is not on the counter: %s" % job)
		return
	if not has_floppy(job):
		return
	var setup := setup_for(job)
	setup.floppy_in_a = false
	if job.software_check() != null:
		job.software_fixed = job.software_check().is_fixed(setup)
	changed.emit()


## True when [param job] can switch on: every place holds a piece, except that of the places that
## take the same part, such as the RAM slots, one is enough. It runs lying and open too, for testing.
func can_power_on(job: Job) -> bool:
	for place: Part in Part.every():
		if job.piece(place) == null and not job.places.keys().any(func(other: Part) -> bool: return other.piece_part() == place.piece_part()):
			return false
	return true


# --- Hardware repair (wiki: Hardware Repair). Each move returns false and changes nothing when the
# --- rules forbid it: that is a normal moment of play, not an error. A job must be on the counter.

## Lifts the side panel off [param job] (true) or puts it back on (false). The panel comes off only
## when the computer lies, is off and the panel's screws are out; it goes back on with its screws out.
func open_case(job: Job, open: bool) -> bool:
	if not _on_counter(job, "open_case") or open == job.case_open:
		return false
	if open and (not job.lying or job.powered or job.panel_screws.has(true)):
		return false
	job.case_open = open
	changed.emit()
	return true


## True when the piece in the place [param part] can come out of [param job] into the empty hand: the
## computer is off, the case is open, the piece is in, and no piece sits on it.
func can_take(job: Job, part: Part) -> bool:
	if hand != null or job.powered or not job.case_open or job.piece(part) == null:
		return false
	for other: Part in job.places:
		if other.sits_on == part:
			return false
	return true


## True when the piece in the hand can go into the place [param part] of [param job]: the place takes
## it, the computer is off, the case is open, the place is empty, and the part that it sits on is in.
func can_put(job: Job, part: Part) -> bool:
	if hand == null or hand.part != part.piece_part() or job.powered or not job.case_open or job.piece(part) != null:
		return false
	return part.sits_on == null or job.piece(part.sits_on) != null


## True when screw [param index] of the side panel of [param job] can turn, out or in: the panel is
## on. Only the side panel is screwed; the parts inside come out freely.
func can_turn(job: Job, index: int) -> bool:
	return not job.case_open and index >= 0 and index < job.panel_screws.size()


## Turns a screw of the side panel out, or back in (see [method can_turn]). The screwdriver is always
## at hand.
func turn_screw(job: Job, index: int) -> bool:
	if not _on_counter(job, "turn_screw") or not can_turn(job, index):
		return false
	job.panel_screws[index] = not job.panel_screws[index]
	changed.emit()
	return true


## Takes the piece of [param part] out of [param job] into the hand (see [method can_take]).
func take_part(job: Job, part: Part) -> bool:
	if not _on_counter(job, "take_part") or not can_take(job, part):
		return false
	hand = job.places[part]
	job.places.erase(part)
	changed.emit()
	return true


## Puts the piece in the hand into the place [param place] of [param job] (see [method can_put]);
## null picks the first place that can take it.
func put_part(job: Job, place: Part = null) -> bool:
	if not _on_counter(job, "put_part") or hand == null:
		return false
	if place == null:
		var free := Part.every().filter(func(each: Part) -> bool: return can_put(job, each))
		place = free[0] if not free.is_empty() else null
	if place == null or not can_put(job, place):
		return false
	job.places[place] = hand
	hand.unused = false
	hand = null
	changed.emit()
	return true


## Takes a new piece of [param part] from its box in the storage into the empty hand.
func take_new_part(part: Part) -> bool:
	if part == null:
		push_error("Game.take_new_part: no part")
		return false
	if hand != null:
		return false
	hand = Piece.new(part, false, true)
	changed.emit()
	return true


## True when the piece in the hand can go back into the storage box of [param part]: it is an unused
## piece of that part (see [member Piece.unused]). A piece that was in a computer goes in the trash.
func can_return_part(part: Part) -> bool:
	return hand != null and hand.unused and hand.part == part


## Puts the piece in the hand back into the storage box of [param part] (see [method can_return_part]).
func return_part(part: Part) -> bool:
	if not can_return_part(part):
		return false
	hand = null
	changed.emit()
	return true


## Throws the piece in the hand in the trash can, on top of what is in it.
func trash_part() -> bool:
	return _put_in(trashed)


## Takes the piece on top of the trash back into the empty hand.
func take_from_trash() -> bool:
	return _take_from(trashed)


## The player takes [param lines], a page from the printer, and carries it with no ticks. While they
## carry a page already, they take none: it returns false and emits [signal printout_refused]. Refuses
## an empty page and returns false.
func carry_printout(lines: PackedStringArray) -> bool:
	if lines.is_empty():
		push_error("Game.carry_printout: the page has no lines")
		return false
	if not printout.is_empty():
		printout_refused.emit()
		return false
	printout = lines.duplicate()
	printout_ticks.clear()
	changed.emit()
	return true


## Ticks (true) or unticks (false) the check box on line [param line] of the carried printout. Returns
## false, and changes nothing, when the player carries no printout or that line has no check box.
func tick_printout(line: int, ticked: bool) -> bool:
	if line < 0 or line >= printout.size() or printout_box(printout[line]) < 0:
		return false
	if (line in printout_ticks) != ticked:
		if ticked:
			printout_ticks.append(line)
		else:
			printout_ticks.erase(line)
		changed.emit()
	return true


## Throws the carried printout in the trash can, where it is gone for good. False when the player
## carries none.
func trash_printout() -> bool:
	if printout.is_empty():
		return false
	printout = []
	printout_ticks.clear()
	changed.emit()
	return true


## The column of the check box, "[ ]" or "[X]", in [param line] of a printout; -1 when it has none.
static func printout_box(line: String) -> int:
	for box: String in ["[ ]", "[X]"]:
		var at := line.find(box)
		if at >= 0:
			return at
	return -1


func _put_in(pile: Array[Piece]) -> bool:
	if hand == null:
		return false
	pile.append(hand)
	hand = null
	changed.emit()
	return true


func _take_from(pile: Array[Piece]) -> bool:
	if hand != null or pile.is_empty():
		return false
	hand = pile.pop_back()
	changed.emit()
	return true


func _on_counter(job: Job, what: String) -> bool:
	if job == null or job not in jobs:
		push_error("Game.%s: the job is not on the counter: %s" % [what, job])
		return false
	return true


## The running computer of [param job] reports whether its software has the problem, after every
## change it makes. Unlike fix(), this can turn back to false (muting again un-fixes no_sound), and
## the computer is no longer ready for pickup. The job must be on the counter.
func set_software_fixed(job: Job, fixed: bool) -> void:
	if job == null or job not in jobs:
		push_error("Game.set_software_fixed: the job is not on the counter: %s" % job)
		return
	if fixed == job.software_fixed:
		return
	job.software_fixed = fixed
	changed.emit()


## The running computer of [param job] reports that the player ran Windows on it while it was fixed
## (see [member Job.tested]). The job must be on the counter and fixed.
func set_tested(job: Job) -> void:
	if job == null or job not in jobs or not job.fixed:
		push_error("Game.set_tested: the job is not a fixed computer on the counter: %s" % (_who(job.customer) if job != null else "no job"))
		return
	if job.tested:
		return
	job.tested = true
	changed.emit()


## Makes the CompuFunDB record of [param job], with the [param text] that the character types up,
## and returns it. Fails with an error unless the job is on the counter and has no record yet.
func enter_job(job: Job, text: String) -> DbRecord:
	if not _on_counter(job, "enter_job"):
		return null
	if record_of(job) != null:
		push_error("Game.enter_job: the job of %s has a record already" % _who(job.customer))
		return null
	var record := DbRecord.new()
	record.text = text
	record.job_order = job.order
	records.append(record)
	changed.emit()
	return record


## The CompuFunDB record of [param job], or null when it has none.
func record_of(job: Job) -> DbRecord:
	for record: DbRecord in records:
		if record.job_order == job.order:
			return record
	return null


## CompuFunDB finished starting up today.
func start_db() -> void:
	db_day = day_number
	changed.emit()


## Marks [param symptom] on [param record] (true), or clears it (false).
func mark_symptom(record: DbRecord, symptom: String, marked: bool) -> void:
	if _is_record(record, "mark_symptom"):
		_set_in(record.marked_symptoms, symptom, marked)


## Ticks the repair step [param step] on [param record] (true), or unticks it (false).
func tick_repair(record: DbRecord, step: String, ticked: bool) -> void:
	if _is_record(record, "tick_repair"):
		_set_in(record.ticked_repairs, step, ticked)


func _is_record(record: DbRecord, what: String) -> bool:
	if record == null or record not in records:
		push_error("Game.%s: the record is not in CompuFunDB: %s" % [what, record])
		return false
	return true


func _set_in(items: Array[String], item: String, present: bool) -> void:
	if (item in items) == present:
		return
	if present:
		items.append(item)
	else:
		items.erase(item)
	changed.emit()


## Picks up the phone's receiver. False, and nothing changes, while someone is in the shop or the
## shop is not open.
func pick_up_phone() -> bool:
	if phone_off_hook:
		return true
	if phase != Phase.OPEN or visitor != null:
		return false
	phone_off_hook = true
	changed.emit()
	return true


## Puts the receiver down, unless a call is on: hang_up() ends a call.
func put_down_phone() -> void:
	if not phone_off_hook or phase == Phase.CALLING:
		return
	phone_off_hook = false
	changed.emit()


## True when the phone can call: the shop is open, nobody is in it, and a computer is done.
func can_call() -> bool:
	return phase == Phase.OPEN and visitor == null and jobs.any(func(j: Job) -> bool: return j.done)


## The done job on the counter that came in first (lowest [member Job.order]), whose customer the
## phone calls; null when no computer is done.
func next_to_call() -> Job:
	var next: Job = null
	for job: Job in jobs:
		if job.done and (next == null or job.order < next.order):
			next = job
	return next


## Calls the customer of [param job], a done computer on the counter, to say it is ready (phase
## CALLING; CompuFunDB is offline, as the land-line cuts the modem). The call lasts until
## [method hang_up]. Fails with an error unless [method can_call] and [param job] is done.
func call_customer(job: Job) -> void:
	if not can_call() or job not in jobs or not job.done:
		push_error("Game.call_customer: can't call about %s now (phase %s, visitor %s, fixed %s, tested %s)" % [_who(job.customer) if job != null else "no job", Phase.find_key(phase), _who(visitor) if visitor != null else "none", job.fixed if job != null else false, job.tested if job != null else false])
		return
	phase = Phase.CALLING
	calling = job
	phone_off_hook = true
	_play(job.errand, Conversation.Trigger.PHONE)
	changed.emit()


## True while the phone calls a customer who doesn't answer: their errand's matching PHONE
## conversation has no lines and no choices. The call ends at [method hang_up], and nobody comes.
func rings_out() -> bool:
	return phase == Phase.CALLING and conversation != null and conversation.lines.is_empty() and conversation.choices.is_empty()


## Ends the call: the called customer comes at once for a PICKUP, unless the call [method rings_out].
## Fails with an error unless the phone is calling.
func hang_up() -> void:
	if phase != Phase.CALLING or calling == null:
		push_error("Game.hang_up: the phone isn't calling (phase %s)" % Phase.find_key(phase))
		return
	var answered := not rings_out()
	phase = Phase.OPEN
	phone_off_hook = false
	conversation = null
	if answered:
		_pickup = calling
		_set_visitor(_pickup.errand, Visit.PICKUP)
	calling = null
	changed.emit()


## True when the shop can open: the day started, and the shop is CLOSED.
func can_open() -> bool:
	return phase == Phase.CLOSED


## Opens the shop: OPEN, and the first customer comes in [member Day.first_wait_seconds] later
## unless the counter is full. Does nothing when [method can_open] is false.
func open_shop() -> void:
	if not can_open():
		return
	phase = Phase.OPEN
	_restart_wait()
	_try_arrival()
	changed.emit()


## True when the shop can close: it is open, nobody is in it, and nobody else comes in today without
## a pickup first: every customer of the day came in or is gone for good, or the next one's computer
## is still in the shop. Closing then sends the rest of the day's customers away for today.
func can_close() -> bool:
	return phase == Phase.OPEN and day != null and _next_arrival() < 0 and visitor == null


## Closes the shop for the night: DAY_OVER and [constant Daypart.EVENING]. Jobs stay on the counter.
## On the last day it is ENDED instead. Starts the day's [member Day.close_signs] and sets its
## [member Day.close_flags]. Does nothing when [method can_close] is false.
func close_shop() -> void:
	if not can_close():
		return
	phase = Phase.DAY_OVER if has_next_day() else Phase.ENDED
	daypart = Daypart.EVENING
	for id: StringName in day.close_signs:
		flags[sign_flag(id)] = 1
	_set_flags(day.close_flags, "closing day %d" % day.number)
	changed.emit()


## The id of the ending that plays now that the game has ENDED: of the enabled endings in
## [constant ENDINGS_FOLDER] whose condition holds, the one with the highest priority; &"" before the
## end, or when none may play.
func ending() -> StringName:
	if phase != Phase.ENDED:
		return &""
	var best: Ending = null
	for file: String in ResourceLoader.list_directory(ENDINGS_FOLDER):
		if file.get_extension() != "tres":
			continue
		var each := load(ENDINGS_FOLDER + file) as Ending
		if each == null:
			push_error("Game.ending: %s%s is not an Ending" % [ENDINGS_FOLDER, file])
			continue
		if not each.enabled or (each.when != null and not each.when.is_met(day_number, flags)):
			continue
		if best == null or each.priority > best.priority:
			best = each
	if best == null:
		push_error("Game.ending: no ending in %s may play on day %d" % [ENDINGS_FOLDER, day_number])
		return &""
	return best.id()


## Starts the game again, as at boot: day 1, CLOSED, with every computer's Win95 setup forgotten.
## The view goes back to [param view].
func reboot(view_name: StringName = &"Main") -> void:
	setups.clear()
	var refused := restore({"day": 1, "phase": "CLOSED", "view": String(view_name)})
	if refused != "":
		push_error("Game.reboot: " + refused)


## True when the week has a day after the current one; false after the last day.
func has_next_day() -> bool:
	return day != null and day_of(day_number + 1) != null


## Starts the day after the current one in the week (see [method start_day]). Jobs left overnight
## stay. Fails with an error, keeping the state, when the week has no next day.
func start_next_day() -> void:
	var next := day_of(day_number + 1)
	if next == null:
		push_error("Game.start_next_day: the week has no day %d (%s)" % [day_number + 1, "loaded %d days" % week.days.size() if week != null else "no week loaded"])
		return
	start_day(next)


## The state as plain data: for the F9 report, the presets of the debug menu, and [method restore].
func snapshot() -> Dictionary:
	return {
		"phase": String(Phase.find_key(phase)),
		"day": day_number,
		"arrivals": arrivals,
		"daypart": String(Daypart.find_key(daypart)),
		"visitor": visitor.resource_path if visitor != null else "",
		"visit": String(Visit.find_key(visit)),
		"visitor_state": String(VisitorState.find_key(visitor_state)),
		"jobs": jobs.map(func(j: Job) -> Dictionary: return j.snapshot()),
		"focus_slot": focus.slot if focus != null else -1,
		"connected_slot": connected.slot if connected != null else -1,
		"calling_slot": calling.slot if calling != null else -1,
		"phone_off_hook": phone_off_hook,
		"hand": Job.pieces_data([hand] if hand != null else []),
		"trashed": Job.pieces_data(trashed),
		"printout": {"lines": Array(printout), "ticks": printout_ticks.duplicate()} if not printout.is_empty() else {},
		"view": String(view),
		"conversation": String(conversation.id) if conversation != null else "",
		"flags": flags.duplicate(),
		"seen": seen.keys(),
		"records": records.map(func(r: DbRecord) -> Dictionary: return r.snapshot()),
		"db_day": db_day,
	}


## Sets the state from [param state], in the format of [method snapshot]. A missing key takes its
## value at the start of a day, except that the shop is OPEN: day 1, nobody in the shop, no
## arrivals, an empty counter, an empty hand and trash, no printout, no flags, nothing seen, no
## CompuFunDB records or start-up, the daypart of the arrivals; a missing view keeps the current one.
## The conversation follows from the rest. Returns "" or why it refused; a refusal keeps the state.
## Keys in [constant RETIRED_KEYS] are ignored, with what they held. The pieces on a job's "mat",
## which older reports carry, go in the trash on top of "trashed", job by job, so none is lost.
func restore(state: Dictionary) -> String:
	var known := snapshot()
	for key: Variant in state:
		if key in RETIRED_KEYS:
			continue
		if not key is String or not known.has(key):
			return _refuse("unknown key %s" % key)
	var number := int(state.get("day", 1))
	var new_day := day_of(number)
	if new_day == null:
		return _refuse("the week has no day %d (%s)" % [number, "%d days" % week.days.size() if week != null else "the story files didn't load"])
	var new_phase: Variant = _enum_value(Phase, state.get("phase", "OPEN"), "phase")
	if new_phase is String:
		return _refuse(new_phase)
	if new_phase == Phase.IDLE:
		return _refuse("the phase IDLE can't be set; start a day instead")
	var new_arrivals := int(state.get("arrivals", 0))
	var codes := new_day.codes()
	if new_arrivals < 0 or new_arrivals > codes.size():
		return _refuse("day %d has %d errand codes, not %d arrivals" % [number, codes.size(), new_arrivals])
	if new_phase == Phase.CLOSED and new_arrivals > 0:
		return _refuse("the shop is CLOSED, but %d customers came in; it opens before the first" % new_arrivals)
	if new_phase == Phase.ENDED and day_of(number + 1) != null:
		return _refuse("ENDED is only for the last day, and day %d has a next day" % number)
	var evening: bool = new_phase == Phase.DAY_OVER or new_phase == Phase.ENDED
	var default_daypart := String(Daypart.find_key(Daypart.EVENING if evening else _daypart_of(new_day, new_arrivals)))
	var new_daypart: Variant = _enum_value(Daypart, state.get("daypart", default_daypart), "daypart")
	if new_daypart is String:
		return _refuse(new_daypart)

	var new_flags: Dictionary[StringName, int] = {}
	var given_flags: Dictionary = state.get("flags", {})
	for key: Variant in given_flags:
		if int(given_flags[key]) != 0:
			new_flags[StringName(str(key))] = int(given_flags[key])

	var new_jobs: Array[Job] = []
	var from_mats: Array[Piece] = []
	var slots: Array[int] = []
	var given_jobs: Array = state.get("jobs", [])
	if given_jobs.size() > MAX_JOBS:
		return _refuse("%d jobs, but the counter holds %d" % [given_jobs.size(), MAX_JOBS])
	for i: int in given_jobs.size():
		var data: Dictionary = given_jobs[i]
		var job_errand: Variant = _job_errand(data, number)
		if job_errand is String:
			return _refuse("job %d: %s" % [i, job_errand])
		var owner: Customer = job_errand.customer
		var job_problem: Problem = job_errand.problem
		if data.has("problem"):
			var problem_path := PROBLEM_PATH % str(data["problem"])
			job_problem = load(problem_path) as Problem if ResourceLoader.exists(problem_path) else null
			if job_problem == null:
				return _refuse("job %d: no problem at '%s'" % [i, problem_path])
		if new_flags.has(gone_flag(owner)):
			return _refuse("job %d: %s is gone for good (%s)" % [i, _who(owner), gone_flag(owner)])
		var slot := int(data.get("slot", i))
		if slot < 0 or slot >= MAX_JOBS or slots.has(slot):
			return _refuse("job %d: the slot %d is taken or not 0 to %d" % [i, slot, MAX_JOBS - 1])
		slots.append(slot)
		var job := Job.new(owner, job_problem, slot, int(data.get("order", i)))
		job.errand = job_errand
		job.hardware_fixed = bool(data.get("hardware_fixed", false))
		job.software_fixed = bool(data.get("software_fixed", false))
		job.powered = bool(data.get("powered", false))
		if data.has("parts"):
			var given_places: Variant = data["parts"]
			if given_places is not Dictionary:
				return _refuse("job %d: parts must map a place id to a piece, not %s" % [i, given_places])
			job.places.clear()
			for place_id: Variant in given_places:
				var place := Part.named(StringName(str(place_id)))
				if place == null or place.id() not in Part.IDS:
					return _refuse("job %d: a computer has no place '%s'" % [i, place_id])
				var pieces: Variant = Job.pieces_from([given_places[place_id]])
				if pieces is String:
					return _refuse("job %d: %s" % [i, pieces])
				var each: Piece = pieces[0]
				if each.part != place.piece_part():
					return _refuse("job %d: the place %s takes %s, not %s" % [i, place_id, place.piece_part().id(), each.part.id()])
				job.places[place] = each
		var mat_pieces: Variant = Job.pieces_from(data.get("mat", []))
		if mat_pieces is String:
			return _refuse("job %d: the mat: %s" % [i, mat_pieces])
		from_mats.append_array(mat_pieces)
		job.case_open = bool(data.get("case_open", false))
		job.lying = job.case_open or bool(data.get("lying", false))
		if data.has("panel_screws"):
			var panel: Array = data["panel_screws"]
			if panel.size() != Job.PANEL_SCREWS:
				return _refuse("job %d: the side panel has %d screws, not %d" % [i, Job.PANEL_SCREWS, panel.size()])
			job.panel_screws.assign(panel.map(func(v: Variant) -> bool: return bool(v)))
		job.tested = bool(data.get("tested", job.fixed))  # reports from before the test count fixed as tested
		if job.powered and not can_power_on(job):
			return _refuse("job %d: a computer that misses a part can't be on" % i)
		new_jobs.append(job)
	var new_focus: Variant = _job_in(new_jobs, int(state.get("focus_slot", -1)), "focus_slot")
	var new_connected: Variant = _job_in(new_jobs, int(state.get("connected_slot", -1)), "connected_slot")
	var new_calling: Variant = _job_in(new_jobs, int(state.get("calling_slot", -1)), "calling_slot")
	for picked: Variant in [new_focus, new_connected, new_calling]:
		if picked is String:
			return _refuse(picked)

	var visitor_path := str(state.get("visitor", ""))
	var new_visitor: Customer = null
	if visitor_path != "":
		new_visitor = _customer_at(visitor_path)
		if new_visitor == null:
			return _refuse("no customer at '%s'" % visitor_path)
		if new_flags.has(gone_flag(new_visitor)):
			return _refuse("the visitor %s is gone for good (%s)" % [_who(new_visitor), gone_flag(new_visitor)])
	var new_visit: Variant = _enum_value(Visit, state.get("visit", "NONE" if new_visitor == null else "DROP_OFF"), "visit")
	var new_visitor_state: Variant = _enum_value(VisitorState, state.get("visitor_state", "NONE" if new_visitor == null else "WALKING_IN"), "visitor_state")
	for value: Variant in [new_visit, new_visitor_state]:
		if value is String:
			return _refuse(value)
	if (new_visitor == null) != (new_visit == Visit.NONE) or (new_visitor == null) != (new_visitor_state == VisitorState.NONE):
		return _refuse("visitor, visit and visitor_state must all be set, or all be none")
	if new_visitor != null and new_phase != Phase.OPEN:
		return _refuse("a visitor can be in the shop only while it is OPEN")
	var new_pickup: Job = null
	var new_errand: Errand = null
	var handed_over: bool = new_visitor_state in [VisitorState.WALKING_OUT, VisitorState.WAITING]
	if new_visit == Visit.DROP_OFF:
		new_errand = _arrived(new_day, new_arrivals, new_visitor, new_flags)
		if new_errand == null:
			return _refuse("%s drops off, but the errands that %d arrivals let in are someone else's" % [_who(new_visitor), new_arrivals])
		if new_visitor_state == VisitorState.WAITING:
			if new_errand.brings != Errand.Brings.SHOWS:
				return _refuse("%s waits at the counter, but %s doesn't show a computer" % [_who(new_visitor), new_errand.file_name()])
			var shown := new_jobs.filter(func(j: Job) -> bool: return j.errand == new_errand)
			if shown.is_empty():
				return _refuse("%s waits beside the computer of %s, but it isn't on the counter" % [_who(new_visitor), new_errand.file_name()])
			new_pickup = shown[0]
		elif not handed_over and new_errand.brings != Errand.Brings.NOTHING and new_jobs.size() >= MAX_JOBS:
			return _refuse("%s drops off, but the counter is full" % _who(new_visitor))
	elif new_visit == Visit.PICKUP and new_visitor_state == VisitorState.WAITING:
		return _refuse("%s picks up, so they don't wait; WAITING is for a drop-off that shows a computer" % _who(new_visitor))
	elif new_visit == Visit.PICKUP and not handed_over:
		var theirs := new_jobs.filter(func(j: Job) -> bool: return j.customer == new_visitor and (j.done or j.errand.brings == Errand.Brings.SHOWS))
		if theirs.is_empty():
			return _refuse("%s picks up, but has no fixed and tested computer, nor one that they show" % _who(new_visitor))
		new_pickup = theirs[0]
		new_errand = new_pickup.errand
	if (new_phase == Phase.CALLING) != (new_calling != null):
		return _refuse("calling_slot is set exactly while the phase is CALLING")
	if new_calling != null and not new_calling.done:
		return _refuse("CALLING about a computer that isn't fixed and tested")
	var new_off_hook: bool = new_phase == Phase.CALLING or bool(state.get("phone_off_hook", false))
	if new_off_hook and new_visitor != null:
		return _refuse("the phone is off the hook while %s is in the shop" % _who(new_visitor))

	var hand_pieces: Variant = Job.pieces_from(state.get("hand", []))
	if hand_pieces is String:
		return _refuse("the hand: %s" % hand_pieces)
	if hand_pieces.size() > 1:
		return _refuse("the hand holds one part, not %d" % hand_pieces.size())
	var trashed_pieces: Variant = Job.pieces_from(state.get("trashed", []))
	if trashed_pieces is String:
		return _refuse("the trash: %s" % trashed_pieces)
	var new_printout: Variant = _printout_from(state.get("printout", {}))
	if new_printout is String:
		return _refuse("the printout: %s" % new_printout)
	var new_seen: Dictionary[String, bool] = {}
	for key: Variant in state.get("seen", []):
		new_seen[str(key)] = true
	var new_records: Array[DbRecord] = []
	var given_records: Variant = state.get("records", [])
	if not given_records is Array:
		return _refuse("records is not a list: %s" % given_records)
	for data: Variant in given_records:
		var record: Variant = DbRecord.from(data)
		if record is String:
			return _refuse(record)
		new_records.append(record)

	day = new_day
	phase = new_phase
	arrivals = new_arrivals
	daypart = new_daypart
	jobs = new_jobs
	focus = new_focus
	connected = new_connected
	calling = new_calling
	phone_off_hook = new_off_hook
	hand = hand_pieces[0] if not hand_pieces.is_empty() else null
	trashed.assign(trashed_pieces + from_mats)
	printout = new_printout[0]
	printout_ticks.assign(new_printout[1])
	visitor = new_visitor
	errand = new_errand
	visit = new_visit
	visitor_state = new_visitor_state
	_pickup = new_pickup
	_next_order = jobs.reduce(func(top: int, j: Job) -> int: return maxi(top, j.order + 1), 0)
	_restart_wait()
	view = StringName(str(state.get("view", view)))
	flags = new_flags
	seen = new_seen
	records = new_records
	db_day = maxi(int(state.get("db_day", 0)), 0)
	arrival += 1
	jump += 1
	conversation = null
	if visitor_state == VisitorState.TALKING:
		_start_talk()
	elif phase == Phase.CALLING:
		_play(calling.errand, Conversation.Trigger.PHONE)
	changed.emit()
	return ""


func _process(delta: float) -> void:
	if phase == Phase.CALLING:
		return
	if phase == Phase.OPEN and visitor == null and _has_room():
		_waited += delta
		if _try_arrival():
			changed.emit()


## The first customer comes in [member Day.first_wait_seconds] after the shop opens; each next one
## [member Day.gap_seconds] of open shop after the last visitor left. The wait pauses while the
## counter is full.
func _arrival_due() -> bool:
	return _waited >= _wait


# Starts the wait for the next customer, with a new random length.
func _restart_wait() -> void:
	_waited = 0.0
	if day != null:
		var span := day.first_wait_seconds if arrivals == 0 else day.gap_seconds
		_wait = randf_range(span.x, span.y)


## Lets the next customer of the day in when one is due and the shop has room. True when one came.
func _try_arrival() -> bool:
	if phase != Phase.OPEN or visitor != null or phone_off_hook or not _has_room():
		return false
	var next := _next_arrival()
	if next < 0 or not _arrival_due():
		return false
	arrivals = next + 1
	daypart = _daypart_of(day, arrivals)
	_set_visitor(coming(next), Visit.DROP_OFF)
	return true


# True when the counter has room for the computer of the next errand to come in, or it brings none.
func _has_room() -> bool:
	if jobs.size() < MAX_JOBS:
		return true
	var next := _next_arrival()
	return next >= 0 and coming(next).brings == Errand.Brings.NOTHING


## The errand that comes for the errand code at [param index] in today's [method Day.codes], if it
## came now: the first alternative whose condition matches and whose customer is not gone for good;
## null when none does.
func coming(index: int) -> Errand:
	var codes := day.codes() if day != null else PackedStringArray()
	if index < 0 or index >= codes.size():
		return null
	for each: Errand in day.alternatives(codes[index]):
		if _met(each.when) and not is_gone(each.customer):
			return each
	return null


## The index in today's [method Day.codes] of the next errand to come in, past those for which
## no alternative comes ([method coming]); -1 when none is left, or while the next one brings their
## computer and it is still in the shop: a customer has one computer, so they bring it after they
## picked it up, and those after them wait.
func _next_arrival() -> int:
	for i: int in range(arrivals, day.codes().size()):
		var next := coming(i)
		if next != null:
			var in_shop := jobs.any(func(j: Job) -> bool: return j.customer == next.customer)
			return -1 if in_shop and next.brings != Errand.Brings.NOTHING else i
	return -1


## The alternative for errand code [param count] - 1 of [param on_day] that [param who] is in for,
## preferring one whose condition matches [param with_flags]; null when no alternative is theirs.
static func _arrived(on_day: Day, count: int, who: Customer, with_flags: Dictionary[StringName, int]) -> Errand:
	var codes := on_day.codes()
	if count < 1 or count > codes.size():
		return null
	var theirs := on_day.alternatives(codes[count - 1]).filter(func(each: Errand) -> bool: return each.customer == who)
	for each: Errand in theirs:
		if each.when == null or each.when.is_met(on_day.number, with_flags):
			return each
	return theirs[0] if not theirs.is_empty() else null


## The errand that a job in a snapshot names (see [method Job.snapshot]), on day [param number] of
## the week, or a String that says why there is none. Without "errand", it is the last errand of the
## job's "customer" on that day or before that brings a computer, else their first after it, else,
## for a job that names its "problem", an errand without a file or conversations.
func _job_errand(data: Dictionary, number: int) -> Variant:
	if data.has("errand"):
		var name := str(data["errand"])
		for d: Day in week.days:
			for each: Errand in d.errands:
				if each.file_name() == name:
					if data.has("customer") and each.customer.resource_path != str(data["customer"]):
						return "the errand %s is %s's, not %s's" % [name, _who(each.customer), data["customer"]]
					return each
		return "the week has no errand %s" % name
	var owner := _customer_at(str(data.get("customer", "")))
	if owner == null:
		return "no customer at '%s'" % data.get("customer", "")
	var theirs: Array[Errand] = []
	for d: Day in week.days:
		theirs.append_array(d.errands.filter(func(each: Errand) -> bool: return each.customer == owner and each.brings != Errand.Brings.NOTHING))
	if theirs.is_empty() and data.has("problem"):
		var stand_in := Errand.new()
		stand_in.customer = owner
		return stand_in
	if theirs.is_empty():
		return "%s has no errand in the week that brings a computer, so name its problem" % _who(owner)
	var before := theirs.filter(func(each: Errand) -> bool: return each.day_number() <= number)
	return before.back() if not before.is_empty() else theirs.front()


## Debug: ends the wait that runs now, so the next event comes at once: the next customer (when
## the counter has room), or the end of the phone call.
func skip_wait() -> void:
	_waited = _wait
	if phase == Phase.CALLING:
		hang_up()


# The visitor hands the computer over and turns to the door, or waits beside it when they only show
# it; they stay the visitor until they leave.
func _leave() -> void:
	if visit == Visit.DROP_OFF:
		var job := _drop_off(errand) if errand.brings != Errand.Brings.NOTHING else null
		if errand.brings == Errand.Brings.SHOWS and job != null:
			_pickup = job
			visitor_state = VisitorState.WAITING
			return
	elif visit == Visit.PICKUP:
		_take_off_counter(_pickup)
		_pickup = null
	visitor_state = VisitorState.WALKING_OUT


# The computer of [param job] leaves the counter, the focus and the cable, and the computers right
# of it shift left: slot 0 up, oldest first.
func _take_off_counter(job: Job) -> void:
	jobs.erase(job)
	if focus == job:
		focus = null
	if connected == job:
		connected = null
	var by_age := jobs.duplicate()
	by_age.sort_custom(func(a: Job, b: Job) -> bool: return a.order < b.order)
	for i: int in by_age.size():
		(by_age[i] as Job).slot = i


# The computer of [param from] goes in the first free slot; returns its job, or null when the
# counter is full.
func _drop_off(from: Errand) -> Job:
	var taken := jobs.map(func(j: Job) -> int: return j.slot)
	for slot: int in MAX_JOBS:
		if slot not in taken:
			var job := Job.new(from.customer, from.problem, slot, _next_order)
			job.errand = from
			_next_order += 1
			jobs.append(job)
			if focus == null:
				focus = job
			return job
	push_error("Game: %s dropped off a computer, but the counter is full" % _who(from.customer))
	return null


# [param visiting] is the errand that the visitor is in for, or null for nobody.
func _set_visitor(visiting: Errand, why: Visit) -> void:
	errand = visiting
	var customer := visiting.customer if visiting != null else null
	visitor = customer
	visit = why
	visitor_state = VisitorState.WALKING_IN if customer != null else VisitorState.NONE
	conversation = null
	if customer != null:
		arrival += 1
	_restart_wait()


## Picks what the TALKING visitor says, and remembers that it played. A pickup visitor with no
## PICKUP conversation says a line of [constant THANKS]. A visitor who brings no computer and has
## nothing to say goes at once.
func _start_talk() -> void:
	_play(errand, Conversation.Trigger.PICKUP if visit == Visit.PICKUP else Conversation.Trigger.ARRIVE)
	if conversation == null and visit == Visit.PICKUP:
		conversation = _thanks(visitor)
		if conversation == null:
			_leave()
	elif conversation == null and errand != null and errand.brings == Errand.Brings.NOTHING:
		_leave()


## A conversation of one line of [constant THANKS], picked by [param who]'s file name; null, with
## an error, when THANKS has no lines.
static func _thanks(who: Customer) -> Conversation:
	if THANKS.lines.is_empty():
		push_error("Game: %s has no lines for %s's pickup" % [THANKS.resource_path, who.resource_path])
		return null
	var thanks := THANKS.duplicate() as Conversation
	thanks.lines = [THANKS.lines[_id_of(who).hash() % THANKS.lines.size()]]
	return thanks


# Sets [member conversation] to what is said for [param from] and [param trigger] now, and
# remembers that it played.
func _play(from: Errand, trigger: Conversation.Trigger) -> void:
	conversation = matching_conversation(from, trigger)
	if conversation == null:
		return
	seen[String(conversation.id)] = true
	_set_flags(conversation.set_flags, "conversation " + conversation.id)


# Sets each flag of [param sets] (name to number; 0 clears it). [param by] names the setter in an error.
func _set_flags(sets: Dictionary[StringName, int], by: String) -> void:
	for flag_name: StringName in sets:
		if flag_name == &"":
			push_error("Game: %s sets a flag with no name" % by)
			continue
		_put_flag(flag_name, sets[flag_name])


## The file name of [param who], which names them in [member seen] and in the flags.
static func _id_of(who: Customer) -> String:
	return who.resource_path.get_file().get_basename()


## The daypart of [param on_day] after [param count] arrivals: morning until the second customer
## who brings a computer, then midday, then afternoon. Errand codes at the start of the day whose
## alternatives all bring nothing (day 1's tutorial) come in the morning and don't count.
static func _daypart_of(on_day: Day, count: int) -> Daypart:
	var visits_first := 0
	for code: String in on_day.codes():
		if on_day.alternatives(code).any(func(each: Errand) -> bool: return each.brings != Errand.Brings.NOTHING):
			break
		visits_first += 1
	return clampi(count - visits_first, 1, Daypart.AFTERNOON) as Daypart


## Why [param d] can't be played, or "" when it can: it is null, has more than
## [constant MAX_CUSTOMERS] errand codes, or an errand without a customer.
static func check_day(d: Day) -> String:
	if d == null:
		return "no day"
	var codes := d.codes()
	if codes.size() > MAX_CUSTOMERS:
		return "day %d has %d errand codes (%s); the most is %d" % [d.number, codes.size(), ", ".join(codes), MAX_CUSTOMERS]
	for i: int in d.errands.size():
		var each := d.errands[i]
		if each == null or each.customer == null:
			return "day %d: errand %d (%s) needs a customer" % [d.number, i, each.file if each != null else "null"]
	return ""


## [lines, ticks] of the printout that [param data] describes, in the format of [method snapshot]
## ({} for none), or a String that says why not.
static func _printout_from(data: Variant) -> Variant:
	if data is not Dictionary:
		return "not a dictionary: %s" % data
	var given_lines: Variant = data.get("lines", [])
	var given_ticks: Variant = data.get("ticks", [])
	if given_lines is not Array or given_ticks is not Array:
		return "lines and ticks must be lists: %s" % data
	var lines := PackedStringArray(given_lines.map(str))
	var ticks: Array[int] = []
	for tick: Variant in given_ticks:
		var line := int(tick)
		if line < 0 or line >= lines.size() or printout_box(lines[line]) < 0:
			return "line %s has no check box to tick" % tick
		if line not in ticks:
			ticks.append(line)
	return [lines, ticks]


## The Customer at [param path], or null when there is none.
static func _customer_at(path: String) -> Customer:
	return load(path) as Customer if path != "" and ResourceLoader.exists(path) else null


## The value of [param enum_type] named [param value_name], or a String that says why not.
static func _enum_value(enum_type: Dictionary, value_name: Variant, key: String) -> Variant:
	if not enum_type.has(str(value_name)):
		return "%s can't be %s; use one of %s" % [key, value_name, enum_type.keys()]
	return enum_type[str(value_name)]


## The job in [param slot] (-1: null), or a String that says why there is none.
static func _job_in(in_jobs: Array[Job], slot: int, key: String) -> Variant:
	if slot == -1:
		return null
	for j: Job in in_jobs:
		if j.slot == slot:
			return j
	return "%s %d: no job in that slot" % [key, slot]


func _refuse(reason: String) -> String:
	push_error("Game.restore: " + reason)
	return reason


func _refuse_play(reason: String) -> String:
	push_error("Game.play_errand: " + reason)
	return reason


static func _who(customer: Customer) -> String:
	return "%s (%s)" % [customer.spoken_name(), customer.resource_path]
