class_name Job
extends RefCounted
## One computer on the counter: whose it is, where it stands and how far the repair is. Game
## creates, changes and removes jobs, and emits Game.changed after each change; other scripts read.

## The customer who brought the computer. Never null.
var customer: Customer
## The place on the counter, 0 to Game.MAX_JOBS - 1. No two jobs on the counter share a slot.
var slot: int = 0
## Counts up with each drop-off, across days: a lower order is an older job.
var order: int = 0
## The pieces in the computer, one per Part; a part that is out has no key.
var places: Dictionary[Part, Piece] = {}
## The pieces that the player took out and put down on the mat beside the computer.
var mat: Array[Piece] = []
## The side panel is off and the computer lies open in the Workview.
var case_open: bool = false
## How many screws hold the side panel.
const PANEL_SCREWS: int = 2
## The screws of the side panel: true while it is in. The panel comes off only when all are out.
var panel_screws: Array[bool] = []
## True when every place holds a piece, none is broken, and the side panel is on with its screws in.
## Setting it is for
## restore, the presets and the debug menu: true repairs the computer, false breaks the problem's
## part again.
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

## The customer's problem.
var problem: Problem:
	get:
		return customer.problem

## True when every part that the problem needs (hardware, software or both) is fixed.
var fixed: bool:
	get:
		match problem.location:
			Problem.Location.HARDWARE:
				return hardware_fixed
			Problem.Location.SOFTWARE:
				return software_fixed
			_:
				return hardware_fixed and software_fixed


func _init(job_customer: Customer, job_slot: int, job_order: int) -> void:
	customer = job_customer
	slot = job_slot
	order = job_order
	_fill(true)


## The piece in the place of [param part], or null when that place is empty.
func piece(part: Part) -> Piece:
	return places.get(part)


# Puts a piece in every place; the problem's broken part breaks when [param break_part] is true.
func _fill(break_part: bool) -> void:
	places.clear()
	var broken_part: Part = customer.problem.broken_part if customer.problem != null else null
	for part: Part in Part.every():
		places[part] = Piece.new(part, break_part and part == broken_part)
	panel_screws.assign(Job.all_in(PANEL_SCREWS))


## [param count] screws, all in.
static func all_in(count: int) -> Array[bool]:
	var screwed: Array[bool] = []
	screwed.resize(count)
	screwed.fill(true)
	return screwed


## The job as plain data, for the F9 report.
func snapshot() -> Dictionary:
	return {
		"slot": slot,
		"order": order,
		"customer": customer.resource_path,
		"problem": String(problem.short_name),
		"hardware_fixed": hardware_fixed,
		"software_fixed": software_fixed,
		"powered": powered,
		"case_open": case_open,
		"panel_screws": panel_screws.duplicate(),
		"parts": Job.pieces_data(places.values()),
		"mat": Job.pieces_data(mat),
	}


## [param pieces] as plain data: "<part id>" for a working piece, "<part id>!" for a broken one.
static func pieces_data(pieces: Array) -> Array[String]:
	var data: Array[String] = []
	for each: Piece in pieces:
		data.append(String(each.part.id()) + ("!" if each.broken else ""))
	return data


## The pieces that [param data] names (see [method pieces_data]), or an error message.
static func pieces_from(data: Array) -> Variant:
	var pieces: Array[Piece] = []
	for entry: Variant in data:
		var text := str(entry)
		var part_id := StringName(text.trim_suffix("!"))
		if part_id not in Part.IDS:
			return "no part '%s'" % part_id
		pieces.append(Piece.new(load("res://parts/%s.tres" % part_id), text.ends_with("!")))
	return pieces

