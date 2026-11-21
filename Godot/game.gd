extends Node
## The state that the whole game shares (autoload "Game"): the day, the visitor, the jobs on the
## counter, the computer in focus, the cable, the phone, the view, the flags and the conversations
## that have played. Scenes call its methods, and re-read the state on [signal changed].

## Emitted after every change of the state. Listeners re-read the whole state.
signal changed

enum Phase {
	IDLE, ## No day has started.
	OPEN, ## The shop is open: customers come in, and the player repairs and calls.
	CALLING, ## The phone is calling a customer to pick up a computer.
	DAY_OVER, ## The player closed the shop for the night.
	ENDED, ## The player closed the shop on the last day: Cambion takes them, and time and space bluescreen.
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
	MORNING, ## The day started; the first customer comes in.
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
}

## The places on the counter. A full counter holds back the next drop-off.
const MAX_JOBS: int = 4
## The most customers that a Day may have.
const MAX_CUSTOMERS: int = 3
## How long a phone call takes, in seconds.
const CALL_SECONDS: float = 2.0
## The date of day 1, so that day 7 is 6/6/96.
const FIRST_DATE: String = "1996-05-31"
## Where [method restore] finds day N.
const DAY_PATH: String = "res://days/day_%d.tres"

var phase: Phase = Phase.IDLE
var day: Day
## How many of [member Day.customers] have come in today, 0 to day.customers.size().
var arrivals: int = 0
## Set by [method start_day], each arrival and [method close_shop]; the Outside shows it.
var daypart: Daypart = Daypart.NONE
## The computers on the counter, oldest drop-off first. Jobs left overnight stay.
var jobs: Array[Job] = []
## The computer that the player works on in the Workview, or null for none.
var focus: Job
## The computer that the VGA cable is connected to, or null when the cable hangs free.
var connected: Job
## The part in the player's hand, or null. The hand holds one piece at a time.
var hand: Piece
## The customer in the shop, or null when nobody is in.
var visitor: Customer
var visit: Visit = Visit.NONE
var visitor_state: VisitorState = VisitorState.NONE
## The name of the current view marker in the room, for example &"Main".
var view: StringName = &"Main"
## The facts of the story: a name and a number. A flag that is 0 or missing is not set.
var flags: Dictionary[StringName, int] = {}
## The conversations that have played, as "<customer file name>/<conversation id>".
var seen: Dictionary[String, bool] = {}
## What the visitor says while TALKING, or null when no conversation matches.
var conversation: Conversation
## Goes up every time a visitor starts to walk in, also on [method restore]. A scene that
## remembers it can tell a new visit from a re-read of the same one.
var arrival: int = 0
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
var _call_left: float = 0.0
var _pickup: Job


## The calendar date of day [param number] (day 1 for 0 or less), as a Time datetime dictionary:
## year, month, day, weekday (0 is Sunday).
func date_of(number: int) -> Dictionary:
	var unix := Time.get_unix_time_from_datetime_string(FIRST_DATE) + maxi(number - 1, 0) * 86400
	return Time.get_datetime_dict_from_unix_time(unix)


## Starts [param new_day] in the morning: the shop opens, and its first customer comes in after
## [member Day.first_wait_seconds] unless the counter is full. Jobs left overnight stay. Refuses a day that is null, has no customers, has more
## than [constant MAX_CUSTOMERS], or has a customer with no problem, and keeps the current state.
func start_day(new_day: Day) -> void:
	var invalid := _check_day(new_day)
	if invalid != "":
		push_error("Game.start_day: " + invalid)
		return
	day = new_day
	arrivals = 0
	daypart = Daypart.MORNING
	phase = Phase.OPEN
	_set_visitor(null, Visit.NONE)
	_try_arrival()
	changed.emit()


func go_to_view(view_name: StringName) -> void:
	if view_name == &"" or view_name == view:
		return
	view = view_name
	changed.emit()


## The room calls this when the visitor reaches the counter: TALKING, with the first conversation
## that matches. A pickup visitor with no matching conversation takes the computer and leaves.
func customer_arrived() -> void:
	if visitor_state != VisitorState.WALKING_IN:
		push_error("Game.customer_arrived: no visitor is walking in (visitor state %s)" % VisitorState.find_key(visitor_state))
		return
	visitor_state = VisitorState.TALKING
	_start_talk()
	changed.emit()


## The dialogue calls this after its last line. A drop-off puts the computer in the first free slot
## (in focus if nothing is); a pickup takes its job off the counter and clears [member focus] and
## [member connected] if they pointed at it. Then the visitor walks out (WALKING_OUT).
func dialogue_finished() -> void:
	if visitor_state != VisitorState.TALKING:
		push_error("Game.dialogue_finished: no visitor is talking (visitor state %s)" % VisitorState.find_key(visitor_state))
		return
	conversation = null
	_leave()
	changed.emit()


## The room calls this when the visitor who walks out reaches the door. The visit ends, and the
## wait for the next customer starts.
func customer_left() -> void:
	if visitor_state != VisitorState.WALKING_OUT:
		push_error("Game.customer_left: no visitor is walking out (visitor state %s)" % VisitorState.find_key(visitor_state))
		return
	_set_visitor(null, Visit.NONE)
	changed.emit()


## The day numbers, 1 to 7, that have a day file at [constant DAY_PATH], in order.
func day_numbers() -> Array[int]:
	var found: Array[int] = []
	for number: int in range(1, 8):
		if ResourceLoader.exists(DAY_PATH % number):
			found.append(number)
	return found


## The number of [param flag_name]; 0 when it is not set.
func flag(flag_name: StringName) -> int:
	return flags.get(flag_name, 0)


## Sets [param flag_name] to [param value]. 0 removes it.
func set_flag(flag_name: StringName, value: int = 1) -> void:
	if flag_name == &"":
		push_error("Game.set_flag: no flag name")
		return
	if value == 0:
		flags.erase(flag_name)
	else:
		flags[flag_name] = value
	changed.emit()


## The first conversation of [param who] with [param trigger] whose condition matches now, and
## that has not played if it plays once. null when none matches.
func matching_conversation(who: Customer, trigger: Conversation.Trigger) -> Conversation:
	for c: Conversation in who.conversations:
		if c == null or c.trigger != trigger:
			continue
		if c.once and seen.has(_seen_key(who, c)):
			continue
		if c.when != null and not c.when.is_met(day_number, flags):
			continue
		return c
	return null


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
		setup = computer.win95_setup.duplicate_deep()  # loaded resources are shared, so mutating them would leak
		setups[computer] = setup
	if not job.broken:
		job.broken = true
		if job.problem.software_check != null:
			job.problem.software_check.apply_break(setup)
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


## True when [param job] can switch on: its case is closed and every place holds a piece.
func can_power_on(job: Job) -> bool:
	return not job.case_open and job.places.size() == Part.every().size()


# --- Hardware repair (wiki: Hardware Repair). Each move returns false and changes nothing when the
# --- rules forbid it: that is a normal moment of play, not an error. A job must be on the counter.

## Lifts the side panel off [param job] (true) or puts it back on (false). The panel comes off only
## when the computer is off and the panel's screws are out; it goes back on with its screws out.
func open_case(job: Job, open: bool) -> bool:
	if not _on_counter(job, "open_case") or open == job.case_open:
		return false
	if open and (job.powered or job.panel_screws.has(true)):
		return false
	job.case_open = open
	changed.emit()
	return true


## True when the piece of [param part] can come out of [param job] into the empty hand: the case is
## open, the piece is in, and no piece sits on it.
func can_take(job: Job, part: Part) -> bool:
	if hand != null or not job.case_open or job.piece(part) == null or job.screws[part].has(true):
		return false
	for other: Part in job.places:
		if other.sits_on == part:
			return false
	return true


## True when the piece in the hand can go into its place in [param job]: the case is open, the
## place is empty, and the part that it sits on is in.
func can_put(job: Job, part: Part) -> bool:
	if hand == null or hand.part != part or not job.case_open or job.piece(part) != null:
		return false
	return part.sits_on == null or job.piece(part.sits_on) != null


## True when screw [param index] of the place of [param part] in [param job] can turn, out or in: the
## piece is there and the case is open. A null [param part] is the side panel: the panel is on.
func can_turn(job: Job, part: Part, index: int) -> bool:
	if part == null:
		return not job.case_open and index >= 0 and index < job.panel_screws.size()
	return job.case_open and job.piece(part) != null and index >= 0 and index < job.screws[part].size()


## Turns a screw out, or back in (see [method can_turn]). The screwdriver is always at hand.
func turn_screw(job: Job, part: Part, index: int) -> bool:
	if not _on_counter(job, "turn_screw") or not can_turn(job, part, index):
		return false
	if part == null:
		job.panel_screws[index] = not job.panel_screws[index]
	else:
		job.screws[part][index] = not job.screws[part][index]
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


## Puts the piece in the hand into its place in [param job] (see [method can_put]).
func put_part(job: Job) -> bool:
	if not _on_counter(job, "put_part") or hand == null or not can_put(job, hand.part):
		return false
	job.places[hand.part] = hand
	hand = null
	changed.emit()
	return true


## Lays the piece in the hand on the mat of [param job].
func put_on_mat(job: Job) -> bool:
	if not _on_counter(job, "put_on_mat") or hand == null:
		return false
	job.mat.append(hand)
	hand = null
	changed.emit()
	return true


## Takes the piece at [param index] on the mat of [param job] into the empty hand.
func take_from_mat(job: Job, index: int) -> bool:
	if not _on_counter(job, "take_from_mat") or hand != null or index < 0 or index >= job.mat.size():
		return false
	hand = job.mat[index]
	job.mat.remove_at(index)
	changed.emit()
	return true


## Takes a new piece of [param part] from its box in the storage into the empty hand.
func take_new_part(part: Part) -> bool:
	if part == null:
		push_error("Game.take_new_part: no part")
		return false
	if hand != null:
		return false
	hand = Piece.new(part)
	changed.emit()
	return true


## Throws the piece in the hand in the trash. It is gone.
func trash_part() -> bool:
	if hand == null:
		return false
	hand = null
	changed.emit()
	return true


func _on_counter(job: Job, what: String) -> bool:
	if job == null or job not in jobs:
		push_error("Game.%s: the job is not on the counter: %s" % [what, job])
		return false
	return true


## The running computer of [param job] reports whether its software has the problem, after every
## change it makes. Unlike fix(), this can turn back to false (muting again un-fixes no_sound), and
## then the post-it unticks. The job must be on the counter.
func set_software_fixed(job: Job, fixed: bool) -> void:
	if job == null or job not in jobs:
		push_error("Game.set_software_fixed: the job is not on the counter: %s" % job)
		return
	if fixed == job.software_fixed:
		return
	job.software_fixed = fixed
	if not job.fixed:
		job.post_it_ticked = false  # the tick claimed a fix that is gone
	changed.emit()


## Ticks the post-it of [param job]. Fails with an error unless the job is on the counter and
## [member Job.fixed].
func tick_post_it(job: Job) -> void:
	if job == null or job not in jobs:
		push_error("Game.tick_post_it: the job is not on the counter: %s" % job)
		return
	if not job.fixed:
		push_error("Game.tick_post_it: the job of %s is not fixed" % _who(job.customer))
		return
	job.post_it_ticked = true
	changed.emit()


## True when the phone can call: the shop is open, nobody is in it, and a post-it is ticked.
func can_call() -> bool:
	return phase == Phase.OPEN and visitor == null and jobs.any(func(j: Job) -> bool: return j.post_it_ticked)


## Calls for [constant CALL_SECONDS] (phase CALLING; CompufunDB is offline, as the land-line cuts
## the modem). Then the customer of the oldest ticked job walks in for a PICKUP. Does nothing when
## [method can_call] is false.
func call_customer() -> void:
	if not can_call():
		return
	phase = Phase.CALLING
	_call_left = CALL_SECONDS
	changed.emit()


## True when the shop can close: it is open, every customer of the day has come in, and nobody is
## in it.
func can_close() -> bool:
	return phase == Phase.OPEN and day != null and arrivals >= day.customers.size() and visitor == null


## Closes the shop for the night: DAY_OVER and [constant Daypart.EVENING]. Jobs stay on the counter.
## On the last day it is ENDED instead. Does nothing when [method can_close] is false.
func close_shop() -> void:
	if not can_close():
		return
	phase = Phase.DAY_OVER if has_next_day() else Phase.ENDED
	daypart = Daypart.EVENING
	changed.emit()


## Starts the game again, as at boot: day 1, with every computer's Win95 setup forgotten. The view
## goes back to [param view].
func reboot(view_name: StringName = &"Main") -> void:
	setups.clear()
	var refused := restore({"day": 1, "view": String(view_name)})
	if refused != "":
		push_error("Game.reboot: " + refused)


## True when a day file follows the current day at [constant DAY_PATH]; false after the last day.
func has_next_day() -> bool:
	return day != null and ResourceLoader.exists(DAY_PATH % (day_number + 1))


## Starts the day after the current one (see [method start_day]), from its file at
## [constant DAY_PATH]. Jobs left overnight stay. Fails with an error, keeping the state, when that
## file is missing, isn't a Day or has another day number.
func start_next_day() -> void:
	var number := day_number + 1
	var path := DAY_PATH % number
	var next := load(path) as Day if ResourceLoader.exists(path) else null
	if next == null or next.number != number:
		push_error("Game.start_next_day: %s is not day %d: %s" % [path, number, next])
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
		"hand": Job.pieces_data([hand] if hand != null else []),
		"view": String(view),
		"conversation": String(conversation.id) if conversation != null else "",
		"flags": flags.duplicate(),
		"seen": seen.keys(),
	}


## Sets the state from [param state], in the format of [method snapshot]. A missing key takes its
## value at the start of a day: day 1, OPEN, nobody in the shop, no arrivals, an empty counter, no
## flags, nothing seen, the daypart of the arrivals; a missing view keeps the current one. The
## conversation follows from the rest. Returns "" or why it refused; a refusal keeps the state.
func restore(state: Dictionary) -> String:
	var known := snapshot()
	for key: Variant in state:
		if not key is String or not known.has(key):
			return _refuse("unknown key %s" % key)
	var number := int(state.get("day", 1))
	var path := DAY_PATH % number
	if not ResourceLoader.exists(path):
		return _refuse("there is no day %d (%s)" % [number, path])
	var new_day := load(path) as Day
	var invalid := _check_day(new_day)
	if invalid != "":
		return _refuse(invalid)
	if new_day.number != number:
		return _refuse("%s says it is day %d" % [path, new_day.number])
	var new_phase: Variant = _enum_value(Phase, state.get("phase", "OPEN"), "phase")
	if new_phase is String:
		return _refuse(new_phase)
	if new_phase == Phase.IDLE:
		return _refuse("the phase IDLE can't be set; start a day instead")
	var new_arrivals := int(state.get("arrivals", 0))
	if new_arrivals < 0 or new_arrivals > new_day.customers.size():
		return _refuse("day %d has %d customers, not %d arrivals" % [number, new_day.customers.size(), new_arrivals])
	if new_phase == Phase.ENDED and ResourceLoader.exists(DAY_PATH % (number + 1)):
		return _refuse("ENDED is only for the last day, and day %d has a next day" % number)
	var evening: bool = new_phase == Phase.DAY_OVER or new_phase == Phase.ENDED
	var default_daypart := String(Daypart.find_key(Daypart.EVENING if evening else _daypart_of(new_arrivals)))
	var new_daypart: Variant = _enum_value(Daypart, state.get("daypart", default_daypart), "daypart")
	if new_daypart is String:
		return _refuse(new_daypart)

	var new_jobs: Array[Job] = []
	var slots: Array[int] = []
	var given_jobs: Array = state.get("jobs", [])
	if given_jobs.size() > MAX_JOBS:
		return _refuse("%d jobs, but the counter holds %d" % [given_jobs.size(), MAX_JOBS])
	for i: int in given_jobs.size():
		var data: Dictionary = given_jobs[i]
		var owner := _customer_at(str(data.get("customer", "")))
		if owner == null or owner.problem == null:
			return _refuse("job %d: no customer with a problem at '%s'" % [i, data.get("customer", "")])
		var slot := int(data.get("slot", i))
		if slot < 0 or slot >= MAX_JOBS or slots.has(slot):
			return _refuse("job %d: the slot %d is taken or not 0 to %d" % [i, slot, MAX_JOBS - 1])
		slots.append(slot)
		var job := Job.new(owner, slot, int(data.get("order", i)))
		job.hardware_fixed = bool(data.get("hardware_fixed", false))
		job.software_fixed = bool(data.get("software_fixed", false))
		job.powered = bool(data.get("powered", false))
		job.post_it_ticked = bool(data.get("post_it_ticked", false))
		if data.has("parts"):
			var pieces: Variant = Job.pieces_from(data["parts"])
			if pieces is String:
				return _refuse("job %d: %s" % [i, pieces])
			job.places.clear()
			for each: Piece in pieces:
				if job.places.has(each.part):
					return _refuse("job %d: two pieces in the place of %s" % [i, each.part.id()])
				job.places[each.part] = each
		var mat_pieces: Variant = Job.pieces_from(data.get("mat", []))
		if mat_pieces is String:
			return _refuse("job %d: the mat: %s" % [i, mat_pieces])
		job.mat.assign(mat_pieces)
		job.case_open = bool(data.get("case_open", false))
		if data.has("panel_screws"):
			var panel: Array = data["panel_screws"]
			if panel.size() != Job.PANEL_SCREWS:
				return _refuse("job %d: the side panel has %d screws, not %d" % [i, Job.PANEL_SCREWS, panel.size()])
			job.panel_screws.assign(panel.map(func(v: Variant) -> bool: return bool(v)))
		var given_screws: Dictionary = data.get("screws", {})
		for part: Part in Part.every():
			if not given_screws.has(String(part.id())):
				continue
			var screwed: Array = given_screws[String(part.id())]
			if screwed.size() != part.screw_points.size():
				return _refuse("job %d: %s has %d screws, not %d" % [i, part.id(), part.screw_points.size(), screwed.size()])
			job.screws[part] = screwed.map(func(v: Variant) -> bool: return bool(v))
		if job.powered and not can_power_on(job):
			return _refuse("job %d: a computer that is open or misses a part can't be on" % i)
		if job.post_it_ticked and not job.fixed:
			return _refuse("job %d: the post-it can be ticked only when the problem is fixed" % i)
		new_jobs.append(job)
	var new_focus: Variant = _job_in(new_jobs, int(state.get("focus_slot", -1)), "focus_slot")
	var new_connected: Variant = _job_in(new_jobs, int(state.get("connected_slot", -1)), "connected_slot")
	for picked: Variant in [new_focus, new_connected]:
		if picked is String:
			return _refuse(picked)

	var visitor_path := str(state.get("visitor", ""))
	var new_visitor: Customer = null
	if visitor_path != "":
		new_visitor = _customer_at(visitor_path)
		if new_visitor == null:
			return _refuse("no customer at '%s'" % visitor_path)
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
	var handed_over: bool = new_visitor_state == VisitorState.WALKING_OUT
	if new_visit == Visit.PICKUP and not handed_over:
		var ticked := new_jobs.filter(func(j: Job) -> bool: return j.customer == new_visitor and j.post_it_ticked)
		if ticked.is_empty():
			return _refuse("%s picks up, but has no ticked job" % _who(new_visitor))
		new_pickup = ticked[0]
	if new_visit == Visit.DROP_OFF and not handed_over and new_jobs.size() >= MAX_JOBS:
		return _refuse("%s drops off, but the counter is full" % _who(new_visitor))
	if new_phase == Phase.CALLING and not new_jobs.any(func(j: Job) -> bool: return j.post_it_ticked):
		return _refuse("CALLING needs a ticked post-it")

	var new_flags: Dictionary[StringName, int] = {}
	var given_flags: Dictionary = state.get("flags", {})
	for key: Variant in given_flags:
		if int(given_flags[key]) != 0:
			new_flags[StringName(str(key))] = int(given_flags[key])
	var hand_pieces: Variant = Job.pieces_from(state.get("hand", []))
	if hand_pieces is String:
		return _refuse("the hand: %s" % hand_pieces)
	if hand_pieces.size() > 1:
		return _refuse("the hand holds one part, not %d" % hand_pieces.size())
	var new_seen: Dictionary[String, bool] = {}
	for key: Variant in state.get("seen", []):
		new_seen[str(key)] = true

	day = new_day
	phase = new_phase
	arrivals = new_arrivals
	daypart = new_daypart
	jobs = new_jobs
	focus = new_focus
	connected = new_connected
	hand = hand_pieces[0] if not hand_pieces.is_empty() else null
	visitor = new_visitor
	visit = new_visit
	visitor_state = new_visitor_state
	_pickup = new_pickup
	_next_order = jobs.reduce(func(top: int, j: Job) -> int: return maxi(top, j.order + 1), 0)
	_restart_wait()
	_call_left = CALL_SECONDS
	view = StringName(str(state.get("view", view)))
	flags = new_flags
	seen = new_seen
	arrival += 1
	conversation = null
	if visitor_state == VisitorState.TALKING:
		_start_talk()
	changed.emit()
	return ""


func _process(delta: float) -> void:
	if phase == Phase.CALLING:
		_call_left -= delta
		if _call_left <= 0.0:
			_end_call()
		return
	if phase == Phase.OPEN and visitor == null and jobs.size() < MAX_JOBS:
		_waited += delta
		if _try_arrival():
			changed.emit()


## The first customer comes in [member Day.first_wait_seconds] after the day starts; each next one
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
	if phase != Phase.OPEN or visitor != null or jobs.size() >= MAX_JOBS or arrivals >= day.customers.size():
		return false
	if not _arrival_due():
		return false
	arrivals += 1
	daypart = _daypart_of(arrivals)
	_set_visitor(day.customers[arrivals - 1], Visit.DROP_OFF)
	return true


func _end_call() -> void:
	phase = Phase.OPEN
	var ticked := jobs.filter(func(j: Job) -> bool: return j.post_it_ticked)
	if ticked.is_empty():
		push_error("Game: the call ended, but no post-it is ticked")
	else:
		ticked.sort_custom(func(a: Job, b: Job) -> bool: return a.order < b.order)
		_pickup = ticked[0]
		_set_visitor(_pickup.customer, Visit.PICKUP)
	changed.emit()


# The visitor hands the computer over and turns to the door; they stay the visitor until they leave.
func _leave() -> void:
	if visit == Visit.DROP_OFF:
		_drop_off(visitor)
	elif visit == Visit.PICKUP:
		jobs.erase(_pickup)
		if focus == _pickup:
			focus = null
		if connected == _pickup:
			connected = null
		_pickup = null
	visitor_state = VisitorState.WALKING_OUT


func _drop_off(customer: Customer) -> void:
	var taken := jobs.map(func(j: Job) -> int: return j.slot)
	for slot: int in MAX_JOBS:
		if slot not in taken:
			var job := Job.new(customer, slot, _next_order)
			_next_order += 1
			jobs.append(job)
			if focus == null:
				focus = job
			return
	push_error("Game: %s dropped off a computer, but the counter is full" % _who(customer))


func _set_visitor(customer: Customer, why: Visit) -> void:
	visitor = customer
	visit = why
	visitor_state = VisitorState.WALKING_IN if customer != null else VisitorState.NONE
	conversation = null
	if customer != null:
		arrival += 1
	_restart_wait()


## Picks what the TALKING visitor says, and remembers that it played. A pickup visitor with
## nothing to say takes the computer and leaves.
func _start_talk() -> void:
	var trigger := Conversation.Trigger.PICKUP if visit == Visit.PICKUP else Conversation.Trigger.ARRIVE
	conversation = matching_conversation(visitor, trigger)
	if conversation != null:
		seen[_seen_key(visitor, conversation)] = true
	elif visit == Visit.PICKUP:
		_leave()


func _seen_key(who: Customer, c: Conversation) -> String:
	return "%s/%s" % [who.resource_path.get_file().get_basename(), c.id]


## The daypart after [param count] arrivals: morning until the second customer, then midday, then
## afternoon.
static func _daypart_of(count: int) -> Daypart:
	return clampi(count, 1, Daypart.AFTERNOON) as Daypart


## Why [param d] can't be played, or "".
func _check_day(d: Day) -> String:
	if d == null or d.customers.is_empty():
		return "the day is null or has no customers: %s" % d
	if d.customers.size() > MAX_CUSTOMERS:
		return "day %d has %d customers; the most is %d" % [d.number, d.customers.size(), MAX_CUSTOMERS]
	for c: Customer in d.customers:
		if c == null or c.problem == null:
			return "day %d has a customer with no problem: %s" % [d.number, c]
	return ""


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


static func _who(customer: Customer) -> String:
	return "%s (%s)" % [customer.display_name, customer.resource_path]
