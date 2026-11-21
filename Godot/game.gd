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
## The date of day 1, so that day 7 is 6/6/96.
const FIRST_DATE: String = "1996-05-31"
## Where [method restore] finds day N.
const DAY_PATH: String = "res://days/day_%d.tres"

var phase: Phase = Phase.IDLE
var day: Day
## How far down [member Day.customers] today has come, 0 to day.customers.size(): every customer
## before it came in, or stays away for good ([method is_gone]).
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
## The part in the player's hand, or null. The hand holds one piece at a time.
var hand: Piece
## The pieces that the player put away in the storage bin, the last one last.
var stored: Array[Piece] = []
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
## The records that the player made in CompuFunDB, oldest first. They last the whole game.
var records: Array[DbRecord] = []
## The day on which CompuFunDB last started up (the work computer booted and the modem dialled
## up); 0 before its first start-up.
var db_day: int = 0
## What the visitor says while TALKING, or what the called customer says on the phone while
## CALLING; null when no conversation matches.
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
var _pickup: Job


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
		if job.problem.software_check != null:
			job.software_fixed = job.problem.software_check.is_fixed(setup)


## Starts [param new_day] in the morning: the shop opens, and its first customer comes in after
## [member Day.first_wait_seconds] unless the counter is full. Jobs left overnight stay, and those
## computers that stayed on finish their Disk Defragmenter run. Refuses a day that is null, has no customers, has more
## than [constant MAX_CUSTOMERS], or has a customer with no problem, and keeps the current state.
func start_day(new_day: Day) -> void:
	var invalid := _check_day(new_day)
	if invalid != "":
		push_error("Game.start_day: " + invalid)
		return
	day = new_day
	_finish_overnight_work()
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


## Sends the visitor, a [member Customer.regular] customer, away for good, as the [x] of the
## corruption sign customer_x does: they vanish at once, with every computer of theirs on the
## counter, and never come in again, also not on a later day or for a pickup ([method is_gone]).
## Fails with an error when nobody is in or the visitor is not regular.
func dismiss_visitor() -> void:
	if visitor == null or not visitor.regular:
		push_error("Game.dismiss_visitor: the visitor is not a regular customer: %s" % (_who(visitor) if visitor != null else "nobody is in"))
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


## The flag that records that [param who] is gone for good: gone_<customer file name>.
func gone_flag(who: Customer) -> StringName:
	return StringName("gone_" + _id_of(who))


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


## Puts the piece in the hand away in the storage bin.
func put_in_storage() -> bool:
	if hand == null:
		return false
	stored.append(hand)
	hand = null
	changed.emit()
	return true


## Takes the piece that went into the storage bin last back into the empty hand.
func take_from_storage() -> bool:
	if hand != null or stored.is_empty():
		return false
	hand = stored.pop_back()
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
## the computer is no longer ready for pickup. The job must be on the counter.
func set_software_fixed(job: Job, fixed: bool) -> void:
	if job == null or job not in jobs:
		push_error("Game.set_software_fixed: the job is not on the counter: %s" % job)
		return
	if fixed == job.software_fixed:
		return
	job.software_fixed = fixed
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


## True when the phone can call: the shop is open, nobody is in it, and a computer is fixed.
func can_call() -> bool:
	return phase == Phase.OPEN and visitor == null and jobs.any(func(j: Job) -> bool: return j.fixed)


## Calls the customer of [param job], a fixed computer on the counter, to say it is ready (phase
## CALLING; CompuFunDB is offline, as the land-line cuts the modem). The call lasts until
## [method hang_up]. Fails with an error unless [method can_call] and [param job] is fixed.
func call_customer(job: Job) -> void:
	if not can_call() or job not in jobs or not job.fixed:
		push_error("Game.call_customer: can't call about %s now (phase %s, visitor %s, fixed %s)" % [_who(job.customer) if job != null else "no job", Phase.find_key(phase), _who(visitor) if visitor != null else "none", job.fixed if job != null else false])
		return
	phase = Phase.CALLING
	calling = job
	_play(job.customer, Conversation.Trigger.PHONE)
	changed.emit()


## Ends the call: the called customer comes at once for a PICKUP. Fails with an error unless the
## phone is calling.
func hang_up() -> void:
	if phase != Phase.CALLING or calling == null:
		push_error("Game.hang_up: the phone isn't calling (phase %s)" % Phase.find_key(phase))
		return
	phase = Phase.OPEN
	_pickup = calling
	calling = null
	_set_visitor(_pickup.customer, Visit.PICKUP)
	changed.emit()


## True when the shop can close: it is open, every customer of the day has come in or is gone for
## good, and nobody is in it.
func can_close() -> bool:
	return phase == Phase.OPEN and day != null and _next_arrival() < 0 and visitor == null


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
		"calling_slot": calling.slot if calling != null else -1,
		"hand": Job.pieces_data([hand] if hand != null else []),
		"stored": Job.pieces_data(stored),
		"view": String(view),
		"conversation": String(conversation.id) if conversation != null else "",
		"flags": flags.duplicate(),
		"seen": seen.keys(),
		"records": records.map(func(r: DbRecord) -> Dictionary: return r.snapshot()),
		"db_day": db_day,
	}


## Sets the state from [param state], in the format of [method snapshot]. A missing key takes its
## value at the start of a day: day 1, OPEN, nobody in the shop, no arrivals, an empty counter, an
## empty hand and storage bin, no flags, nothing seen, no CompuFunDB records or start-up, the
## daypart of the arrivals; a missing view keeps the current one. The conversation follows from the rest. Returns
## "" or why it refused; a refusal keeps the state.
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

	var new_flags: Dictionary[StringName, int] = {}
	var given_flags: Dictionary = state.get("flags", {})
	for key: Variant in given_flags:
		if int(given_flags[key]) != 0:
			new_flags[StringName(str(key))] = int(given_flags[key])

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
		if new_flags.has(gone_flag(owner)):
			return _refuse("job %d: %s is gone for good (%s)" % [i, _who(owner), gone_flag(owner)])
		var slot := int(data.get("slot", i))
		if slot < 0 or slot >= MAX_JOBS or slots.has(slot):
			return _refuse("job %d: the slot %d is taken or not 0 to %d" % [i, slot, MAX_JOBS - 1])
		slots.append(slot)
		var job := Job.new(owner, slot, int(data.get("order", i)))
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
		job.mat.assign(mat_pieces)
		job.case_open = bool(data.get("case_open", false))
		job.lying = job.case_open or bool(data.get("lying", false))
		if data.has("panel_screws"):
			var panel: Array = data["panel_screws"]
			if panel.size() != Job.PANEL_SCREWS:
				return _refuse("job %d: the side panel has %d screws, not %d" % [i, Job.PANEL_SCREWS, panel.size()])
			job.panel_screws.assign(panel.map(func(v: Variant) -> bool: return bool(v)))
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
	var handed_over: bool = new_visitor_state == VisitorState.WALKING_OUT
	if new_visit == Visit.PICKUP and not handed_over:
		var ready := new_jobs.filter(func(j: Job) -> bool: return j.customer == new_visitor and j.fixed)
		if ready.is_empty():
			return _refuse("%s picks up, but has no fixed computer" % _who(new_visitor))
		new_pickup = ready[0]
	if new_visit == Visit.DROP_OFF and not handed_over and new_jobs.size() >= MAX_JOBS:
		return _refuse("%s drops off, but the counter is full" % _who(new_visitor))
	if (new_phase == Phase.CALLING) != (new_calling != null):
		return _refuse("calling_slot is set exactly while the phase is CALLING")
	if new_calling != null and not new_calling.fixed:
		return _refuse("CALLING about a computer that isn't fixed")

	var hand_pieces: Variant = Job.pieces_from(state.get("hand", []))
	if hand_pieces is String:
		return _refuse("the hand: %s" % hand_pieces)
	if hand_pieces.size() > 1:
		return _refuse("the hand holds one part, not %d" % hand_pieces.size())
	var stored_pieces: Variant = Job.pieces_from(state.get("stored", []))
	if stored_pieces is String:
		return _refuse("the storage bin: %s" % stored_pieces)
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
	hand = hand_pieces[0] if not hand_pieces.is_empty() else null
	stored.assign(stored_pieces)
	visitor = new_visitor
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
	conversation = null
	if visitor_state == VisitorState.TALKING:
		_start_talk()
	elif phase == Phase.CALLING:
		_play(calling.customer, Conversation.Trigger.PHONE)
	changed.emit()
	return ""


func _process(delta: float) -> void:
	if phase == Phase.CALLING:
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
	if phase != Phase.OPEN or visitor != null or jobs.size() >= MAX_JOBS:
		return false
	var next := _next_arrival()
	if next < 0 or not _arrival_due():
		return false
	arrivals = next + 1
	daypart = _daypart_of(arrivals)
	_set_visitor(day.customers[next], Visit.DROP_OFF)
	return true


## The index in [member Day.customers] of the next customer to come in today, past those who are
## gone for good; -1 when none is left.
func _next_arrival() -> int:
	for i: int in range(arrivals, day.customers.size()):
		if not is_gone(day.customers[i]):
			return i
	return -1


## Debug: ends the wait that runs now, so the next event comes at once: the next customer (when
## the counter has room), or the end of the phone call.
func skip_wait() -> void:
	_waited = _wait
	if phase == Phase.CALLING:
		hang_up()


# The visitor hands the computer over and turns to the door; they stay the visitor until they leave.
func _leave() -> void:
	if visit == Visit.DROP_OFF:
		_drop_off(visitor)
	elif visit == Visit.PICKUP:
		_take_off_counter(_pickup)
		_pickup = null
	visitor_state = VisitorState.WALKING_OUT


# The computer of [param job] leaves the counter, the focus and the cable.
func _take_off_counter(job: Job) -> void:
	jobs.erase(job)
	if focus == job:
		focus = null
	if connected == job:
		connected = null


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
	_play(visitor, Conversation.Trigger.PICKUP if visit == Visit.PICKUP else Conversation.Trigger.ARRIVE)
	if conversation == null and visit == Visit.PICKUP:
		_leave()


# Sets [member conversation] to what [param who] says for [param trigger] now, and remembers that
# it played.
func _play(who: Customer, trigger: Conversation.Trigger) -> void:
	conversation = matching_conversation(who, trigger)
	if conversation != null:
		seen[_seen_key(who, conversation)] = true


func _seen_key(who: Customer, c: Conversation) -> String:
	return "%s/%s" % [_id_of(who), c.id]


## The file name of [param who], which names them in [member seen] and in the flags.
static func _id_of(who: Customer) -> String:
	return who.resource_path.get_file().get_basename()


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
	return "%s (%s)" % [customer.spoken_name(), customer.resource_path]
