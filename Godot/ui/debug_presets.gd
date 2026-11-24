extends VBoxContainer
## The Presets tab of the debug menu: buttons that set a Game state at once. Days has the start and
## the end of each day, and Computer problems one button per problem in [constant PROBLEMS_FOLDER],
## both made from the data; Moments are the hand-written states in [constant MOMENTS]. A preset is in the format of Game.snapshot(); "Copy
## state" copies the current one, so a new moment is a paste. Missing keys start the day fresh (see
## Game.restore()). A job names its errand by file name, or a customer and a problem when the story
## has no errand with that problem.

const PROBLEMS_FOLDER: String = "res://problems/"
## Who brings a problem that no day has yet, and on which day: problem to [customer path, day]. A
## problem on a day takes that day's errand instead.
const STAND_INS: Dictionary[StringName, Array] = {
	&"broken_hard_drive": ["res://customers/nice_guy.tres", 5],
	&"desktop_prank": ["res://customers/office_girl.tres", 5],
	&"gpu_overheating": ["res://customers/young_entrepreneur.tres", 6],
	&"hamster": ["res://customers/nice_lady.tres", 2],
	&"screensaver": ["res://customers/attractive_guy.tres", 4],
}
## Who brings a problem that neither a day nor [constant STAND_INS] names.
const FALLBACK: Array = ["res://customers/skater_bro.tres", 1]
const MOMENTS: Dictionary[String, Dictionary] = {
	"Skater bro at the counter": {"day": 1, "arrivals": 2, "visitor": "res://customers/skater_bro.tres",
			"visit": "DROP_OFF", "visitor_state": "TALKING"},
	"Skater bro's computer, ready to call": {"day": 1, "arrivals": 2, "focus_slot": 0,
			"jobs": [{"errand": "0102_skater_bro", "slot": 0, "hardware_fixed": true}]},
	"Old dude at the counter, Skater bro's computer waiting": {"day": 1, "arrivals": 3, "focus_slot": 0,
			"visitor": "res://customers/retired_accountant.tres", "visit": "DROP_OFF", "visitor_state": "TALKING",
			"jobs": [{"errand": "0102_skater_bro", "slot": 0}]},
	"Day 1 over, two computers overnight": {"day": 1, "phase": "DAY_OVER", "arrivals": 4,
			"jobs": [{"errand": "0102_skater_bro", "slot": 0},
				{"errand": "0103_retired_accountant", "slot": 1, "order": 1}]},
	"The end": {"day": 7, "phase": "ENDED"},
}
const HEADER_COLOR := Color(1.0, 0.84, 0.35)
const HINT_COLOR := Color(0.7, 0.7, 0.7)

var _status: Label


## Two presets per day of the week, by button text: the closed morning (with the customer who comes
## before opening talking at the counter), and the open shop with every errand of the day come and
## gone, ready to close. Each holds the flags that the week sets before
## it: the days' [member Day.set_flags] and [member Day.close_flags], and the flags of each drop-off
## conversation that plays. The flags of a reply depend on the player's choices, so they are left out.
static func day_presets() -> Dictionary[String, Dictionary]:
	var presets: Dictionary[String, Dictionary] = {}
	if Game.week == null:
		return presets
	var flags: Dictionary[StringName, int] = {}
	for day: Day in Game.week.days:
		_put_flags(flags, day.set_flags)
		var start: Dictionary = {"day": day.number, "phase": "CLOSED", "flags": flags.duplicate()}
		var early: Errand = null
		if not day.errands.is_empty():
			early = _first_met(day.alternatives(day.codes()[0]), day.number, flags) as Errand
		if early != null and early.before_opening:
			start.merge({"arrivals": 1, "visitor": early.customer.resource_path, "visitor_state": "TALKING"})
		presets["Day %d starts" % day.number] = start
		for code: String in day.codes():
			var errand := _first_met(day.alternatives(code), day.number, flags) as Errand
			if errand == null:
				continue
			var arrive := _first_met(errand.conversations.filter(func(c: Conversation) -> bool: return c.trigger == Conversation.Trigger.ARRIVE), day.number, flags) as Conversation
			if arrive != null:
				_put_flags(flags, arrive.set_flags)
		presets["Day %d, ready to close" % day.number] = {"day": day.number, "arrivals": day.codes().size(), "flags": flags.duplicate()}
		_put_flags(flags, day.close_flags)
	return presets


# The first of [param candidates] (each with a Condition in `when`) that may play on day [param number] with [param flags].
static func _first_met(candidates: Array, number: int, flags: Dictionary[StringName, int]) -> Resource:
	for each: Resource in candidates:
		var when: Condition = each.get("when")
		if when == null or when.is_met(number, flags):
			return each
	return null


static func _put_flags(flags: Dictionary[StringName, int], sets: Dictionary[StringName, int]) -> void:
	for flag_name: StringName in sets:
		@warning_ignore("static_called_on_instance")
		Game.put_flag(flags, flag_name, sets[flag_name])


## One preset per problem in [constant PROBLEMS_FOLDER], by its button text: the customer's computer
## on the counter with that problem, in focus in the Workview for hardware, or connected, on and in
## the Screen View for software.
static func problem_presets() -> Dictionary[String, Dictionary]:
	var presets: Dictionary[String, Dictionary] = {}
	for file: String in ResourceLoader.list_directory(PROBLEMS_FOLDER):
		if file.get_extension() != "tres":
			continue
		var problem := load(PROBLEMS_FOLDER + file) as Problem
		if problem == null:
			push_error("Debug presets: %s%s is not a Problem" % [PROBLEMS_FOLDER, file])
			continue
		var who: Array = _bringer(problem)
		var customer := load(who[0]) as Customer
		var job := {"errand": who[2], "slot": 0} if who.size() > 2 else {"customer": who[0], "problem": String(problem.short_name), "slot": 0}
		var state := {"day": who[1], "arrivals": 0, "focus_slot": 0, "jobs": [job]}
		if problem.location == Problem.Location.HARDWARE:
			state["view"] = "Workview"
		else:
			job["powered"] = true
			state["connected_slot"] = 0
			state["view"] = "Screen"
		var label := "%s  (%s, day %d)" % [String(problem.short_name).capitalize(), customer.spoken_name() if customer != null else who[0], who[1]]
		presets[label] = state
	return presets


# [customer path, day, errand file name] of the week's first errand with [param problem], else its
# stand-in [customer path, day].
static func _bringer(problem: Problem) -> Array:
	if Game.week != null:
		for day: Day in Game.week.days:
			for errand: Errand in day.errands:
				if errand.problem == problem and errand.customer != null:
					return [errand.customer.resource_path, day.number, errand.file_name()]
	return STAND_INS.get(problem.short_name, FALLBACK)


func _ready() -> void:
	add_theme_constant_override(&"separation", 8)
	_add_section("Days", "The start of each day, and its end with every errand done, with the flags that the days and drop-offs set before it.", day_presets())
	var problems := problem_presets()
	_add_section("Computer problems", "One per problem file: hardware opens in the Workview, software booted in the Screen View.", problems)
	_add_section("Moments", "Hand-written states. Copy state, then paste a new one into MOMENTS.", MOMENTS)
	var copy := Button.new()
	copy.text = "Copy state"
	copy.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	copy.pressed.connect(_copy)
	add_child(copy)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)


func _add_section(title: String, hint: String, presets: Dictionary[String, Dictionary]) -> void:
	var header := Label.new()
	header.text = title
	header.add_theme_font_size_override(&"font_size", 15)
	header.add_theme_color_override(&"font_color", HEADER_COLOR)
	add_child(header)
	var note := Label.new()
	note.text = hint
	note.add_theme_font_size_override(&"font_size", 13)
	note.add_theme_color_override(&"font_color", HINT_COLOR)
	add_child(note)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 6)
	grid.add_theme_constant_override(&"v_separation", 4)
	add_child(grid)
	for preset_name: String in presets:
		var button := Button.new()
		button.text = preset_name
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.clip_text = true
		button.add_theme_font_size_override(&"font_size", 14)
		button.tooltip_text = preset_name
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_apply.bind(preset_name, presets[preset_name]))
		grid.add_child(button)


func _apply(preset_name: String, state: Dictionary) -> void:
	var refused := Game.restore(state)
	_status.text = "%s: %s" % [preset_name, refused] if refused != "" else "Set: " + preset_name


func _copy() -> void:
	var state := JSON.stringify(Game.snapshot(), "\t")
	print(state)
	if not DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		push_error("Debug presets: no clipboard here; the state is in the output log")
		_status.text = "No clipboard here. The state is in the output log."
		return
	DisplayServer.clipboard_set(state)
	_status.text = "Copied the state. Paste it into MOMENTS in ui/debug_presets.gd."
