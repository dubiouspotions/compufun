extends Node
## The state that the whole game shares (autoload "Game"): the day, the customer, the repair, the
## phone and the view. Scenes call its methods, and re-read the state on [signal changed].

## Emitted after every change of the state. Listeners re-read the whole state.
signal changed

enum Phase {
	IDLE, ## No day has started.
	WALKING_IN, ## The customer walks from the door to the counter.
	TALKING, ## The customer talks at the counter.
	REPAIR, ## The computer is on the counter, and the customer has left.
	CALLING, ## The player calls the customer to pick up the computer.
	DAY_OVER, ## Every customer of the day has picked up the computer.
}

## How long a phone call takes, in seconds.
const CALL_SECONDS: float = 2.0

var phase: Phase = Phase.IDLE
var day: Day
## The index of the current customer in [member Day.customers]; -1 before the first.
var customer_index: int = -1
var hardware_fixed: bool = false
var software_fixed: bool = false
## The computer on the bench has power and a screen. Only in REPAIR; every new customer starts off.
var bench_powered: bool = false
var post_it_ticked: bool = false
## The name of the current view marker in the room, for example &"Main".
var view: StringName = &"Main"

## The current customer, or null in IDLE and DAY_OVER.
var customer: Customer:
	get:
		if day == null or customer_index < 0 or customer_index >= day.customers.size():
			return null
		return day.customers[customer_index]

## The problem of the current customer, or null.
var problem: Problem:
	get:
		return customer.problem if customer != null else null

## True when every part of the problem that needs a fix (hardware, software or both) is fixed.
var problem_fixed: bool:
	get:
		if problem == null:
			return false
		match problem.location:
			Problem.Location.HARDWARE:
				return hardware_fixed
			Problem.Location.SOFTWARE:
				return software_fixed
			_:
				return hardware_fixed and software_fixed


## Starts [param new_day] with its first customer. Refuses a day with no customers or a customer
## with no problem, and keeps the current state.
func start_day(new_day: Day) -> void:
	if new_day == null or new_day.customers.is_empty():
		push_error("Game.start_day: the day is null or has no customers: %s" % new_day)
		return
	for c: Customer in new_day.customers:
		if c == null or c.problem == null:
			push_error("Game.start_day: day %d has a customer with no problem: %s" % [new_day.number, c])
			return
	day = new_day
	customer_index = -1
	_next_customer()


func go_to_view(view_name: StringName) -> void:
	if view_name == &"" or view_name == view:
		return
	view = view_name
	changed.emit()


## The room calls this when the customer reaches the counter.
func customer_arrived() -> void:
	if phase != Phase.WALKING_IN:
		return
	phase = Phase.TALKING
	changed.emit()


## The dialogue calls this after its last line: the computer stays on the counter.
func dialogue_finished() -> void:
	if phase != Phase.TALKING:
		return
	phase = Phase.REPAIR
	changed.emit()


## Marks the hardware or the software part of the repair as done. Only in REPAIR.
func fix(location: Problem.Location) -> void:
	if phase != Phase.REPAIR:
		return
	if location == Problem.Location.HARDWARE:
		hardware_fixed = true
	elif location == Problem.Location.SOFTWARE:
		software_fixed = true
	else:
		push_error("Game.fix: give HARDWARE or SOFTWARE, not %s" % location)
		return
	changed.emit()


## Switches the computer on the bench on or off. Only in REPAIR.
func set_bench_powered(on: bool) -> void:
	if phase != Phase.REPAIR or on == bench_powered:
		return
	bench_powered = on
	changed.emit()


## The running computer reports whether its software has the problem, after every change it makes.
## Unlike fix(), this can turn back to false: muting again un-fixes no_sound. Only in REPAIR.
func set_software_fixed(fixed: bool) -> void:
	if phase != Phase.REPAIR or fixed == software_fixed:
		return
	software_fixed = fixed
	if not problem_fixed:
		post_it_ticked = false  # the tick claimed a fix that is gone
	changed.emit()


## Ticks the post-it. Only when the problem is fixed.
func tick_post_it() -> void:
	if phase != Phase.REPAIR or not problem_fixed:
		return
	post_it_ticked = true
	changed.emit()


func can_call() -> bool:
	return phase == Phase.REPAIR and post_it_ticked


## Calls the customer. CompufunDB is offline during the call (the land-line cuts the modem).
## After the call, the customer picks up the computer and the next customer comes in.
func call_customer() -> void:
	if not can_call():
		return
	phase = Phase.CALLING
	changed.emit()
	await get_tree().create_timer(CALL_SECONDS, false).timeout
	_next_customer()


## The state as plain data, for the F9 report.
func snapshot() -> Dictionary:
	return {
		"phase": String(Phase.find_key(phase)),
		"day": day.number if day != null else 0,
		"customer_index": customer_index,
		"customer": customer.resource_path if customer != null else "",
		"problem": String(problem.short_name) if problem != null else "",
		"hardware_fixed": hardware_fixed,
		"software_fixed": software_fixed,
		"bench_powered": bench_powered,
		"post_it_ticked": post_it_ticked,
		"view": String(view),
	}


func _next_customer() -> void:
	customer_index += 1
	hardware_fixed = false
	software_fixed = false
	bench_powered = false
	post_it_ticked = false
	phase = Phase.WALKING_IN if customer != null else Phase.DAY_OVER
	changed.emit()
