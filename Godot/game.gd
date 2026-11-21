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


## The dialogue calls this after the player's reply: the computer stays on the counter.
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
	await get_tree().create_timer(CALL_SECONDS).timeout
	_next_customer()


func _next_customer() -> void:
	customer_index += 1
	hardware_fixed = false
	software_fixed = false
	post_it_ticked = false
	phase = Phase.WALKING_IN if customer != null else Phase.DAY_OVER
	changed.emit()
