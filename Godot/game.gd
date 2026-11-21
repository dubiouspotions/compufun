extends Node
## The state that the whole game shares (autoload "Game"): the day, the visitor, the jobs on the
## counter, the computer in focus, the cable, the phone and the view. Scenes call its methods, and
## re-read the state on [signal changed].

## Emitted after every change of the state. Listeners re-read the whole state.
signal changed

enum Phase {
	IDLE, ## No day has started.
	OPEN, ## The shop is open: customers come in, and the player repairs and calls.
	CALLING, ## The phone is calling a customer to pick up a computer.
	DAY_OVER, ## The player closed the shop for the night.
}

## Why the visitor is in the shop.
enum Visit {
	NONE, ## Nobody is in the shop.
	DROP_OFF, ## The visitor brings a computer.
	PICKUP, ## The visitor takes a finished computer home.
}

## The time of day. The customers move it forward; time does not pass on its own.
enum Daypart {
	NONE, ## Before the first customer of the day.
	MORNING, ## The first customer came in.
	MIDDAY, ## The second customer came in.
	EVENING, ## The third customer came in.
	NIGHT, ## The player closed the shop.
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
## The conversation that a customer has when they bring a computer.
const ARRIVE_CONVERSATION: StringName = &"arrive"
## The conversation that a customer has when they pick up a computer. Optional: without it, the
## customer takes the computer and leaves.
const PICKUP_CONVERSATION: StringName = &"pickup"

var phase: Phase = Phase.IDLE
var day: Day
## How many of [member Day.customers] have come in today, 0 to day.customers.size().
var arrivals: int = 0
## Set by each arrival and by [method close_shop]; the Outside shows it.
var daypart: Daypart = Daypart.NONE
## The computers on the counter, oldest drop-off first. Jobs left overnight stay.
var jobs: Array[Job] = []
## The computer that the player works on in the Workview, or null for none.
var focus: Job
## The computer that the keyboard cable is connected to, or null when the cable hangs free.
var connected: Job
## The customer in the shop, or null when nobody is in.
var visitor: Customer
var visit: Visit = Visit.NONE
var visitor_state: VisitorState = VisitorState.NONE
## The name of the current view marker in the room, for example &"Main".
var view: StringName = &"Main"

var _next_order: int = 0
var _gap_elapsed: float = 0.0
var _call_left: float = 0.0
var _pickup: Job


## Starts [param new_day]: the shop opens and its first customer comes in at once, unless the
## counter is full. Jobs left overnight stay. Refuses a day that is null, has no customers, has more
## than [constant MAX_CUSTOMERS], or has a customer with no problem, and keeps the current state.
func start_day(new_day: Day) -> void:
	if new_day == null or new_day.customers.is_empty():
		push_error("Game.start_day: the day is null or has no customers: %s" % new_day)
		return
	if new_day.customers.size() > MAX_CUSTOMERS:
		push_error("Game.start_day: day %d has %d customers; the most is %d" % [new_day.number, new_day.customers.size(), MAX_CUSTOMERS])
		return
	for c: Customer in new_day.customers:
		if c == null or c.problem == null:
			push_error("Game.start_day: day %d has a customer with no problem: %s" % [new_day.number, c])
			return
	day = new_day
	arrivals = 0
	daypart = Daypart.NONE
	phase = Phase.OPEN
	_set_visitor(null, Visit.NONE)
	_try_arrival()
	changed.emit()


func go_to_view(view_name: StringName) -> void:
	if view_name == &"" or view_name == view:
		return
	view = view_name
	changed.emit()


## The room calls this when the visitor reaches the counter: TALKING. A pickup visitor without the
## [constant PICKUP_CONVERSATION] takes the computer and leaves at once.
func customer_arrived() -> void:
	if visitor_state != VisitorState.WALKING_IN:
		push_error("Game.customer_arrived: no visitor is walking in (visitor state %s)" % VisitorState.find_key(visitor_state))
		return
	visitor_state = VisitorState.TALKING
	if visit == Visit.PICKUP and visitor.conversation(PICKUP_CONVERSATION) == null:
		_leave()
	changed.emit()


## The dialogue calls this after its last line. A drop-off puts the computer in the first free slot
## (in focus if nothing is); a pickup takes its job off the counter and clears [member focus] and
## [member connected] if they pointed at it. Then the visitor walks out (WALKING_OUT).
func dialogue_finished() -> void:
	if visitor_state != VisitorState.TALKING:
		push_error("Game.dialogue_finished: no visitor is talking (visitor state %s)" % VisitorState.find_key(visitor_state))
		return
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


## Puts [param job] in focus for the Workview. null takes the focus away. The job must be on the
## counter.
func focus_job(job: Job) -> void:
	if job != null and job not in jobs:
		push_error("Game.focus_job: the job of %s is not on the counter" % _who(job.customer))
		return
	focus = job
	changed.emit()


## Connects the keyboard cable to [param job], which then boots on the screen. null disconnects.
## The job must be on the counter.
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


## Switches [param job] on or off. The screen shows the [member connected] job while it is on.
## The job must be on the counter.
func set_powered(job: Job, on: bool) -> void:
	if job == null or job not in jobs:
		push_error("Game.set_powered: the job is not on the counter: %s" % job)
		return
	if on == job.powered:
		return
	job.powered = on
	changed.emit()


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


## Closes the shop for the night: DAY_OVER and [constant Daypart.NIGHT]. Jobs stay on the counter. Does nothing when
## [method can_close] is false.
func close_shop() -> void:
	if not can_close():
		return
	phase = Phase.DAY_OVER
	daypart = Daypart.NIGHT
	changed.emit()


## The state as plain data, for the F9 report.
func snapshot() -> Dictionary:
	return {
		"phase": String(Phase.find_key(phase)),
		"day": day.number if day != null else 0,
		"arrivals": arrivals,
		"daypart": String(Daypart.find_key(daypart)),
		"visitor": visitor.resource_path if visitor != null else "",
		"visit": String(Visit.find_key(visit)),
		"visitor_state": String(VisitorState.find_key(visitor_state)),
		"jobs": jobs.map(func(j: Job) -> Dictionary: return j.snapshot()),
		"focus_slot": focus.slot if focus != null else -1,
		"connected_slot": connected.slot if connected != null else -1,
		"view": String(view),
	}


func _process(delta: float) -> void:
	if phase == Phase.CALLING:
		_call_left -= delta
		if _call_left <= 0.0:
			_end_call()
		return
	if phase == Phase.OPEN and visitor == null and jobs.size() < MAX_JOBS:
		_gap_elapsed += delta
		if _try_arrival():
			changed.emit()


## The first customer comes in at once; each next one [member Day.gap_seconds] of open shop after
## the last visitor left. The wait pauses while the counter is full.
func _arrival_due() -> bool:
	return arrivals == 0 or _gap_elapsed >= day.gap_seconds


## Lets the next customer of the day in when one is due and the shop has room. True when one came.
func _try_arrival() -> bool:
	if phase != Phase.OPEN or visitor != null or jobs.size() >= MAX_JOBS or arrivals >= day.customers.size():
		return false
	if not _arrival_due():
		return false
	arrivals += 1
	daypart = mini(arrivals, Daypart.EVENING) as Daypart
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
	_gap_elapsed = 0.0


static func _who(customer: Customer) -> String:
	return "%s (%s)" % [customer.display_name, customer.resource_path]
