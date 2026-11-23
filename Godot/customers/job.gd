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
## What lies in the computer and doesn't belong there (Problem.blocker), on the part that it sits on;
## null once the player took it out, or for a problem without one.
var blocker: Piece
## The pieces that lie askew on places that don't take them (Problem.misplaced), keyed by that place,
## which holds no piece of its own while one lies on it.
var misplaced: Dictionary[Part, Piece] = {}
## The pieces that the player took out and put down on the mat beside the computer.
var mat: Array[Piece] = []
## The computer lies on its side, the side panel up, in every view: the player laid it down in the
## Workview and hasn't stood it up again. Always true while [member case_open].
var lying: bool = false
## The side panel is off. The computer lies open.
var case_open: bool = false
## The side panel has come off on this visit (Game.open_case). It fixes an empty case's hardware
## (Problem.empty_case) once the panel is back on with its screws in.
var was_opened: bool = false
## The id of the part that the BIOS memory test counts.
const RAM: StringName = &"ram"

## What stops the BIOS before it shows a picture: the first part that the power-on self test misses.
enum Fault { NONE, NO_CPU, NO_MEMORY, NO_VIDEO }
## How many screws hold the side panel.
const PANEL_SCREWS: int = 2
## The screws of the side panel: true while it is in. The panel comes off only when all are out.
var panel_screws: Array[bool] = []
## True when every place holds a piece, none is broken, nothing is in the way ([member blocker]) or
## misplaced, and the side panel is on with its screws in. For an empty case (Problem.empty_case):
## when the panel is on with its screws in and [member was_opened], whatever the places hold.
## Setting it is for restore, the presets and the debug menu: true repairs the computer, false
## breaks the problem's part again, in a random place when several take it.
var hardware_fixed: bool:
	get:
		if case_open or panel_screws.has(false) or blocker != null or not misplaced.is_empty():
			return false
		if runs_empty():
			return was_opened
		for part: Part in Part.every():
			if not places.has(part) or places[part].broken:
				return false
		return true
	set(value):
		_fill(not value)
		was_opened = value
		case_open = false
var software_fixed: bool = false
## The computer is switched on.
var powered: bool = false
## The seconds that the computer has run with a CPU but no fan on it; Game switches it off at
## Game.OVERHEAT_SECONDS. 0 while it is off.
var heat_seconds: float = 0.0
## The CD-ROM drive's tray is out. Only Game.toggle_cd_tray changes it in play, and only while the
## computer is on; switching off leaves it where it is. Meaningless for a case front without a drive.
var cd_tray_open: bool = false
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


## True when the problem makes the computer run as if every part were in, whatever its places hold
## (Problem.empty_case).
func runs_empty() -> bool:
	return problem != null and problem.empty_case


## The share of the computer's memory that its RAM places hold, 0 to 1. 1 for a computer without
## RAM places, or one that [method runs_empty].
func memory_share() -> float:
	var slots := Part.every().filter(func(place: Part) -> bool: return place.piece_part().id() == RAM)
	if slots.is_empty() or runs_empty():
		return 1.0
	return slots.filter(func(place: Part) -> bool: return places.has(place)).size() / float(slots.size())


## True when a piece of the part [param part_id] is in, in any place that takes it, or the computer
## [method runs_empty].
func has(part_id: StringName) -> bool:
	return runs_empty() or places.keys().any(func(place: Part) -> bool: return place.piece_part().id() == part_id)


## The first part, in the order that the BIOS checks them, whose absence stops it before it shows a
## picture: NO_CPU (nothing happens but the fans), NO_MEMORY or NO_VIDEO (the PC speaker beeps).
func post_fault() -> Fault:
	if not has(&"cpu"):
		return Fault.NO_CPU
	if not has(RAM):
		return Fault.NO_MEMORY
	if not has(&"gpu"):
		return Fault.NO_VIDEO
	return Fault.NONE


## True while the computer runs with a CPU but no fan on it: it heats up (see [member heat_seconds]).
func overheats() -> bool:
	return powered and has(&"cpu") and not has(&"fan")


## True while a broken RAM piece is in: the BIOS memory test fails.
func memory_fails() -> bool:
	return places.values().any(func(each: Piece) -> bool: return each.broken and each.part.id() == RAM)


# Puts a piece in every place. When [param break_part] is true, the problem's broken part breaks,
# in one random place of those that take it, so the player can't learn which; its missing part and
# its misplaced pieces leave their places (see Problem.missing_part, Problem.misplaced), and its
# stand-ins take the places of the parts that they pose as, in their order, one per place while
# they last. An empty case (Problem.empty_case) ends with every place empty, broken or repaired.
func _fill(break_part: bool) -> void:
	places.clear()
	misplaced.clear()
	var broken_part: Part = problem.broken_part if problem != null else null
	var takers := Part.every().filter(func(place: Part) -> bool: return place.piece_part() == broken_part)
	var bad: Part = takers.pick_random() if break_part and not takers.is_empty() else null
	var stand_ins: Array[Part] = problem.stand_ins if break_part and problem != null else ([] as Array[Part])
	var used: Array[Part] = []
	for place: Part in Part.every():
		var standing_in := stand_ins.filter(func(each: Part) -> bool: return each.poses_as == place.piece_part())
		var unused := standing_in.filter(func(each: Part) -> bool: return each not in used)
		var piece_part: Part = unused[0] if not unused.is_empty() else standing_in[0] if not standing_in.is_empty() else place.piece_part()
		used.append(piece_part)
		places[place] = Piece.new(piece_part, place == bad)
	blocker = Piece.new(problem.blocker, false) if break_part and problem != null and problem.blocker != null else null
	panel_screws.assign(Job.all_in(PANEL_SCREWS))
	if break_part and problem != null:
		_take_out(problem.missing_part)
		for lies_on: Part in problem.misplaced:
			var part: Part = problem.misplaced[lies_on]
			if _take_out(part):
				misplaced[lies_on] = Piece.new(part)
		for lies_on: Part in misplaced:
			if places.has(lies_on):
				push_error("Job: %s puts %s on %s, whose own piece is still in" % [problem.resource_path, misplaced[lies_on].part.id(), lies_on.id()])
	if runs_empty():
		places.clear()


# Empties the first place that holds a piece of [param part]; false, with an error, when none does.
# null takes nothing out and returns false.
func _take_out(part: Part) -> bool:
	if part == null:
		return false
	for place: Part in places:
		if place.piece_part() == part:
			places.erase(place)
			return true
	push_error("Job: %s takes out more pieces of %s than a computer has" % [problem.resource_path, part.id()])
	return false


## [param count] screws, all in.
static func all_in(count: int) -> Array[bool]:
	var screwed: Array[bool] = []
	screwed.resize(count)
	screwed.fill(true)
	return screwed


## The job as plain data, for the F9 report and Game.restore: its errand by file name ("errand",
## such as "0102_skater_bro", when a story file holds it), its customer, and its problem by short
## name ("problem") when it is not that errand's.
func snapshot() -> Dictionary:
	var data := {
		"slot": slot,
		"order": order,
		"customer": customer.resource_path,
		"hardware_fixed": hardware_fixed,
		"software_fixed": software_fixed,
		"tested": tested,
		"powered": powered,
		"cd_tray_open": cd_tray_open,
		"lying": lying,
		"case_open": case_open,
		"was_opened": was_opened,
		"panel_screws": panel_screws.duplicate(),
		"parts": places_data(),
		"blocker": blocker != null,
		"misplaced": misplaced_data(),
		"mat": Job.pieces_data(mat),
	}
	if errand != null and errand.file != "":
		data["errand"] = errand.file_name()
	if problem != null and (errand == null or errand.file == "" or problem != errand.problem):
		data["problem"] = String(problem.short_name)
	return data


## The pieces in their places as plain data: place id to piece (see [method pieces_data]).
func places_data() -> Dictionary[String, String]:
	return Job._by_place(places)


## The misplaced pieces as plain data: the id of the place that each lies on, to the piece (see
## [method pieces_data]).
func misplaced_data() -> Dictionary[String, String]:
	return Job._by_place(misplaced)


static func _by_place(pieces: Dictionary[Part, Piece]) -> Dictionary[String, String]:
	var data: Dictionary[String, String] = {}
	for place: Part in pieces:
		data[String(place.id())] = Job.pieces_data([pieces[place]])[0]
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

