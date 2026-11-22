class_name Job
extends RefCounted
## One computer on the counter: whose it is, where it stands and how far the repair is. Game
## creates, changes and removes jobs, and emits Game.changed after each change; other scripts read.

## The customer who brought the computer. Never null.
var customer: Customer
## The visit that brought the computer: its pickup and phone conversations play from it, on any
## later day. Game sets it on every job that it creates; null only on a job built outside Game.
var errand: Errand
## The place on the counter, 0 to Game.MAX_JOBS - 1. No two jobs on the counter share a slot. Game
## changes it when a computer left of this one leaves the counter: the computers fill the slots from
## 0 up, oldest first.
var slot: int = 0
## Counts up with each drop-off, across days: a lower order is an older job.
var order: int = 0
## The pieces in the computer, keyed by their place (see [constant Part.IDS]); an empty place has no
## key.
var places: Dictionary[Part, Piece] = {}
## The computer lies on its side, the side panel up, in every view: the player laid it down in the
## Workview and hasn't stood it up again. Always true while [member case_open].
var lying: bool = false
## The side panel is off. The computer lies open.
var case_open: bool = false
## The id of the part that the BIOS memory test counts.
const RAM: StringName = &"ram"
## How many screws hold the side panel.
const PANEL_SCREWS: int = 2
## The screws of the side panel: true while it is in. The panel comes off only when all are out.
var panel_screws: Array[bool] = []
## True when every place holds a piece, none is broken, and the side panel is on with its screws in.
## Setting it is for restore, the presets and the debug menu: true repairs the computer, false
## breaks the problem's part again, in a random place when several take it.
var hardware_fixed: bool:
	get:
		if case_open or panel_screws.has(false):
			return false
		for part: Part in Part.every():
			if not places.has(part) or places[part].broken:
				return false
		return true
	set(value):
		_fill(not value)
		case_open = false
var software_fixed: bool = false
## The computer is switched on.
var powered: bool = false
## Game.setup_for has broken the computer's running copy as the problem says.
var broken: bool = false

## What is wrong with the computer on this visit (the Errand's); null for a visit that needs no
## repair: such a computer is never fixed or tested, and nobody calls about it.
var problem: Problem

## True when every part that the problem needs (hardware, software or both) is fixed. Always false
## without a problem.
var fixed: bool:
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

## The player has run Windows on the fixed computer: its desktop stayed up for the problem's
## [member Problem.hangs_after] seconds. Game clears it each time the computer stops being fixed.
var tested: bool = false

## The repair is done: fixed and tested. The post-it shows the check, and the player can call the
## customer.
var done: bool:
	get:
		return fixed and tested


## [param job_problem] may be null.
func _init(job_customer: Customer, job_problem: Problem, job_slot: int, job_order: int) -> void:
	customer = job_customer
	problem = job_problem
	slot = job_slot
	order = job_order
	_fill(true)


## How the problem breaks the computer's Win95 setup and when that is fixed; null without a problem
## or a software check.
func software_check() -> SoftwareCheck:
	return problem.software_check if problem != null else null


## What the post-it says: the problem's perceived issue, or "" without a problem.
func perceived_issue() -> String:
	return problem.perceived_issue if problem != null else ""


## The piece in the place [param part], or null when that place is empty.
func piece(part: Part) -> Piece:
	return places.get(part)


## The share of the computer's memory that its RAM places hold, 0 to 1. 1 for a computer without
## RAM places.
func memory_share() -> float:
	var slots := Part.every().filter(func(place: Part) -> bool: return place.piece_part().id() == RAM)
	if slots.is_empty():
		return 1.0
	return slots.filter(func(place: Part) -> bool: return places.has(place)).size() / float(slots.size())


## True while a broken RAM piece is in: the BIOS memory test fails.
func memory_fails() -> bool:
	return places.values().any(func(each: Piece) -> bool: return each.broken and each.part.id() == RAM)


# Puts a piece in every place. When [param break_part] is true, the problem's broken part breaks,
# in one random place of those that take it, so the player can't learn which.
func _fill(break_part: bool) -> void:
	places.clear()
	var broken_part: Part = problem.broken_part if problem != null else null
	var takers := Part.every().filter(func(place: Part) -> bool: return place.piece_part() == broken_part)
	var bad: Part = takers.pick_random() if break_part and not takers.is_empty() else null
	for place: Part in Part.every():
		places[place] = Piece.new(place.piece_part(), place == bad)
	panel_screws.assign(Job.all_in(PANEL_SCREWS))


## [param count] screws, all in.
static func all_in(count: int) -> Array[bool]:
	var screwed: Array[bool] = []
	screwed.resize(count)
	screwed.fill(true)
	return screwed


## The job as plain data, for the F9 report and Game.restore: its errand by file name ("errand",
## such as "0102_skater_bro", when a story file holds it), its customer, and its problem by short
## name ("problem") only when it is not the errand's.
func snapshot() -> Dictionary:
	var data := {
		"slot": slot,
		"order": order,
		"customer": customer.resource_path,
		"hardware_fixed": hardware_fixed,
		"software_fixed": software_fixed,
		"tested": tested,
		"powered": powered,
		"lying": lying,
		"case_open": case_open,
		"panel_screws": panel_screws.duplicate(),
		"parts": places_data(),
	}
	if errand != null and errand.file != "":
		data["errand"] = errand.file_name()
	if problem != null and (errand == null or problem != errand.problem):
		data["problem"] = String(problem.short_name)
	return data


## The pieces in their places as plain data: place id to piece (see [method pieces_data]).
func places_data() -> Dictionary[String, String]:
	var data: Dictionary[String, String] = {}
	for place: Part in places:
		data[String(place.id())] = Job.pieces_data([places[place]])[0]
	return data


## [param pieces] as plain data: "<part id>" for a working piece, "<part id>!" for a broken one,
## "<part id>+" for an unused one (see [member Piece.unused]).
static func pieces_data(pieces: Array) -> Array[String]:
	var data: Array[String] = []
	for each: Piece in pieces:
		data.append(String(each.part.id()) + ("!" if each.broken else "+" if each.unused else ""))
	return data


## The pieces that [param data] names (see [method pieces_data]), or an error message.
static func pieces_from(data: Array) -> Variant:
	var pieces: Array[Piece] = []
	for entry: Variant in data:
		var text := str(entry)
		var part_id := StringName(text.trim_suffix("!").trim_suffix("+"))
		var part := Part.named(part_id)
		if part == null:
			return "no part '%s'" % part_id
		pieces.append(Piece.new(part, text.ends_with("!"), text.ends_with("+")))
	return pieces

