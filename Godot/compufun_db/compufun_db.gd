class_name CompuFunDB
extends Control
## CompuFunDB on the work computer: a DOS database in text mode, 80 x 30 characters. Three columns:
## SEARCH (the player types words and presses Enter; the work computer is slow, so the symptoms of
## every Problem that hold them all come in one at a time, each after a seek of the hard drive),
## what to check (the checks of every problem with the symptom picked, among a few checks of
## other problems in the same place: the Game.db_search; the player marks those that fail) and what to
## fix (the repair steps of each of those problems whose checks are all marked, while no other is,
## numbered and ending in [member test_step]; the player ticks them off). This screen keeps only its cursor and the typed
## words. It reads every Problem file, so its text is never a second copy of the problems.
## The first time the player opens it on a day, the work computer boots, the character starts the
## program at the DOS prompt and the modem dials up; until then the computer is off. Nothing skips
## the start-up; the player can leave meanwhile, and it goes on.
## Keys: in SEARCH, letters type, Backspace erases, and Enter searches, or picks a symptom found for
## the words as typed; arrows and Tab move, Enter acts (Space too
## outside SEARCH), and outside SEARCH, P prints the checklist on the shop's Printer, F only its FIX
## steps, and the go_back keys but Down leave the view, as the Back button does; Esc always does.
## The mouse clicks and scrolls.

const PROBLEMS_DIR: String = "res://problems/"
const COLUMNS: int = 80
const ROWS: int = 30
const CELL: Vector2 = Vector2(8, 16)
## The rows of the frame's lines: the top, under the headers, the bottom.
const FRAME_ROWS: Array[int] = [1, 3, 27]
## The first and last row of the lists, between the headers and the bottom frame.
const LIST_TOP: int = 4
const LIST_BOTTOM: int = 26
## The buttons in the bottom frame, under the CHECK and the FIX column,, that do what P and F do.
const PRINT_BUTTON: String = "[ PRINT CHECKLIST ]"
const PRINT_FIX_BUTTON: String = "[ PRINT FIX ]"

enum Column { SEARCH, CHECKS, FIXES }

const HEADERS: Array[String] = ["SEARCH", "CHECK", "FIX"]
## The most characters that the player can type into SEARCH.
const SEARCH_LENGTH: int = 40

## The text-mode font: one glyph per 8 x 16 cell.
@export var font: Font = preload("res://compufun_db/fonts/Px437_IBM_VGA_8x16.ttf")
@export var background: Color = Color.BLACK
@export var text_color: Color = Color(0.667, 0.667, 0.667)
@export var bright_color: Color = Color.WHITE
@export var dim_color: Color = Color(0.333, 0.333, 0.333)
## The CompuFun red of the bars, the headers and the selection.
@export var bar_color: Color = Color(0.89, 0, 0)
## The last repair step of every problem but a software-only one, after its hardware and software
## steps (see Job.tested). A software fix lands on a running Windows, which tests it at once.
@export var test_step: String = "Test the computer"
## How many checks of other problems CompuFunDB mixes into what to check: between x and y.
@export var decoys: Vector2i = Vector2i(2, 5)
## The sound of each key that the character types.
@export var keystroke: SoundSet = preload("res://sounds/keystroke.tres")
## The sound of the space bar; null plays [member keystroke].
@export var space_bar: SoundSet = preload("res://sounds/keystroke_space.tres")
## The seconds between two keys, picked between x and y for each key.
@export var key_seconds: Vector2 = Vector2(0.03, 0.09)
@export_group("Search")
## The seconds that a search reads before its first symptom shows, picked between x and y.
@export var search_seconds: Vector2 = Vector2(1.2, 2.0)
## The seconds that each symptom found takes to show, picked between x and y for each; the more
## found, the longer the search.
@export var hit_seconds: Vector2 = Vector2(0.6, 1.4)
## The seconds between two seeks of the hard drive while it reads, picked between x and y.
@export var seek_seconds: Vector2 = Vector2(0.12, 0.4)
## The hard drive seeking, from the work modem's speaker beside the tower; null is silent.
@export var hdd_seek: SoundSet = preload("res://sounds/hdd_seek.tres")
@export_group("")
@export_group("Start-up")
## The work computer's boot: a 386 that stops after the BIOS.
@export var boot_scene: PackedScene = preload("res://compufun_db/work_pc_boot.tscn")
## What the character types at the DOS prompt to start the program.
@export var command: String = "CFDB"
## The program's banner, then what the modem says before the dial-up and after it.
@export_multiline var banner_lines: PackedStringArray = [
	"CompuFunDB 1.0   Copyright (C) 1988 CompuFun Inc.", "", "Initializing modem...", "ATZ", "OK", "ATDT 555-0196"]
@export_multiline var connect_lines: PackedStringArray = ["CONNECT 14400", "Logging in to CompuFun HQ... OK"]
## The seconds after each start-up line.
@export var start_line_seconds: float = 0.2
## The modem dialling CompuFun HQ, from the dial tone until it connects.
@export var dialup_sound: AudioStream = preload("res://sounds/modem_dialup.wav")
@export_group("")

## The group of the speaker at the work keyboard, which plays the keys that the character types.
const KEYS_SPEAKER: StringName = &"work_keys_speaker"
## The group of the work modem's speaker, which plays the dial-up.
const MODEM_SPEAKER: StringName = &"modem_speaker"

## The picture changed: the computer started, or a new day turned it off.
signal picture_changed

## The first and last x of each column's text, inside the frame.
var _spans: Array[Vector2i] = [Vector2i(1, 24), Vector2i(26, 51), Vector2i(53, 78)]
var _problems: Array[Problem] = []
## Every symptom of every problem, once each, by category (see [member check_categories]), then
## alphabetically.
var _symptoms: PackedStringArray = []
var _column: Column = Column.SEARCH
var _selected: Array[int] = [0, 0, 0]
var _scroll: Array[int] = [0, 0, 0]
## What the player typed into SEARCH.
var _typed: String = ""
## The words of the last search, and the symptoms that it found so far; the search runs while
## [member _searching].
var _searched: String = ""
var _hits: PackedStringArray = []
var _searching: bool = false
## Counts up with each search, so that a search that a new one replaced stops.
var _search_count: int = 0
var _mouse_cell: Vector2i = Vector2i(-1, -1)
## True from the first opening of a day until the database shows.
var _starting: bool = false
## The DOS screen of the start-up, line by line.
var _dos: PackedStringArray = []
var _shown_day: int = -1
## What the bottom bar says instead of the column's name until the next key or click; empty: nothing.
var _status: String = ""
# The grid that _draw paints: one character, foreground and background per cell.
var _chars: PackedStringArray = []
var _fg: PackedColorArray = []
var _bg: PackedColorArray = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if font == null:
		push_error("CompuFunDB: font is empty")
	_load_problems()
	mouse_exited.connect(_on_mouse_exited)
	Game.changed.connect(queue_redraw)
	Game.changed.connect(_check_day)
	Game.changed.connect(_reconcile)


func _on_mouse_exited() -> void:
	_mouse_cell = Vector2i(-1, -1)
	queue_redraw()


func _load_problems() -> void:
	for file: String in ResourceLoader.list_directory(PROBLEMS_DIR):
		if not file.ends_with(".tres"):
			continue
		var problem := load(PROBLEMS_DIR + file) as Problem
		if problem == null:
			push_error("CompuFunDB: %s%s is not a Problem" % [PROBLEMS_DIR, file])
			continue
		if not problem.in_compufun_db:
			continue
		_problems.append(problem)
		for symptom: String in problem.symptoms:
			var category: String = problem.symptom_categories.get(symptom, "")
			if category == "":
				push_error("CompuFunDB: the symptom '%s' of %s has no 'category:'; CHECK lists it under Other" % [symptom, problem.short_name])
				category = "Other"
			if not _categories.has(symptom):
				_symptoms.append(symptom)
				_categories[symptom] = category
			elif _categories[symptom] != category:
				push_error("CompuFunDB: the symptom '%s' of %s is in the category '%s', but another problem puts it in '%s'" % [symptom, problem.short_name, category, _categories[symptom]])
	if _problems.is_empty():
		push_error("CompuFunDB: no Problem files in %s" % PROBLEMS_DIR)
	var ordered := Array(_symptoms)
	ordered.sort_custom(func(a: String, b: String) -> bool:
		var rank_a := _category_rank(_categories[a])
		var rank_b := _category_rank(_categories[b])
		return rank_a < rank_b or (rank_a == rank_b and (_categories[a] < _categories[b] or (_categories[a] == _categories[b] and a.naturalnocasecmp_to(b) < 0))))
	_symptoms = PackedStringArray(ordered)


# Where [param category] comes among the CHECK column's headings: its place in check_categories, or
# after them all.
func _category_rank(category: String) -> int:
	var rank := check_categories.find(category)
	return rank if rank >= 0 else check_categories.size()


# An entry of a column: its text, its check box (null: none) and whether the player can pick it.
func _entries(column: Column) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var search := Game.db_search
	match column:
		Column.SEARCH:
			for symptom: String in _hits:
				entries.append({text = symptom, check = null, pick = true})
		Column.CHECKS:
			if search != null:
				for check: String in search.offered:
					entries.append({text = check, check = check in search.marked_checks, pick = true})
		Column.FIXES:
			for problem: Problem in _matches():
				var number := _add_steps(entries, "Hardware", problem.hardware_steps, 1)
				number = _add_steps(entries, "Software", problem.software_steps, number)
				_add_steps(entries, "Test", PackedStringArray([test_step]), number)
	return entries


# Adds a section of numbered steps, the first numbered [param number]; returns the next number.
func _add_steps(entries: Array[Dictionary], title: String, steps: PackedStringArray, number: int) -> int:
	if steps.is_empty():
		return number
	entries.append({text = "-- %s --" % title, check = null, pick = false})
	for step: String in steps:
		entries.append({text = step, check = step in Game.db_search.ticked_repairs, pick = true, number = number})
		number += 1
	return number


# The symptoms that hold every word of [param text], whatever the case; none for no words.
func _found(text: String) -> PackedStringArray:
	var words := text.to_lower().split(" ", false)
	var found: PackedStringArray = []
	if words.is_empty():
		return found
	for symptom: String in _symptoms:
		var lower := symptom.to_lower()
		if Array(words).all(func(word: String) -> bool: return lower.contains(word)):
			found.append(symptom)
	return found


# The problems with the symptom searched for whose checks are all marked, while no other check is: a
# wrong mark shows no fix.
func _matches() -> Array[Problem]:
	var found: Array[Problem] = []
	var search := Game.db_search
	if search == null:
		return found
	var covered: Array[String] = []
	for problem: Problem in _problems:
		if search.query in problem.symptoms and Array(problem.checks).all(func(c: String) -> bool: return c in search.marked_checks):
			found.append(problem)
			covered.append_array(problem.checks)
	if search.marked_checks.any(func(c: String) -> bool: return c not in covered):
		found.clear()
	return found


# Starts the search for [param query]: what to check is the checks of every problem that has it,
# mixed with a few checks of other problems in the same place, so the list doesn't give it away.
func _search(query: String) -> void:
	var right: Array[String] = []
	var places: Array[Problem.Location] = []
	for problem: Problem in _problems:
		if query in problem.symptoms:
			places.append(problem.location)
			for check: String in problem.checks:
				if check not in right:
					right.append(check)
	var others: Array[String] = []
	for problem: Problem in _problems:
		if query in problem.symptoms or not places.any(func(at: Problem.Location) -> bool: return _same_place(at, problem.location)):
			continue
		for check: String in problem.checks:
			if check not in right and check not in others:
				others.append(check)
	others.shuffle()
	var offered: Array[String] = right.duplicate()
	offered.append_array(others.slice(0, randi_range(decoys.x, decoys.y)))
	offered.shuffle()
	if Game.search_db(query, offered) == null:
		return
	_column = Column.CHECKS
	for column: Column in [Column.CHECKS, Column.FIXES]:
		_selected[column] = 0
		_scroll[column] = 0
	_move(0)


func _same_place(a: Problem.Location, b: Problem.Location) -> bool:
	return a == b or Problem.Location.BOTH in [a, b]


# The screen lines of a column: [entry index, text], with the entries wrapped to the column's width.
# A numbered step has its check box at the right of its last line; other entries in front.
func _lines(column: Column, entries: Array[Dictionary]) -> Array[Array]:
	var width := _spans[column].y - _spans[column].x + 1
	var lines: Array[Array] = []
	for i: int in entries.size():
		var entry := entries[i]
		var box := "" if entry.check == null else ("[X]" if entry.check else "[ ]")
		var numbered := entry.has("number")
		var prefix := "%d. " % entry.number if numbered else ("" if box.is_empty() else box + " ")
		var suffix := " " + box if numbered else ""
		var wrapped := _wrap(entry.text, width - prefix.length() - suffix.length())
		for j: int in wrapped.size():
			var line := (prefix if j == 0 else " ".repeat(prefix.length())) + wrapped[j]
			if j == wrapped.size() - 1 and numbered:
				line = line.rpad(width - suffix.length()) + suffix
			lines.append([i, line])
	return lines


func _wrap(text: String, width: int) -> PackedStringArray:
	var lines: PackedStringArray = []
	var line := ""
	for word: String in text.split(" ", false):
		while word.length() > width:  # a word longer than the column breaks anywhere
			if not line.is_empty():
				lines.append(line)
				line = ""
			lines.append(word.left(width))
			word = word.substr(width)
		if line.is_empty():
			line = word
		elif line.length() + 1 + word.length() <= width:
			line += " " + word
		else:
			lines.append(line)
			line = word
	if not line.is_empty() or lines.is_empty():
		lines.append(line)
	return lines


func _gui_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		_mouse_cell = Vector2i((motion.position / CELL).floor())
		queue_redraw()
		return
	var button := event as InputEventMouseButton
	if button != null and button.pressed:
		_on_click(button)
		accept_event()
		return


# The keys come here, not to _gui_input: that needs the GUI focus, which the screen doesn't have
# until the player clicks it. The CRT screen passes the keys only while it is open.
func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key.pressed and _on_key(key):
		get_viewport().set_input_as_handled()


## The player opened the screen: the computer starts up if it hasn't today.
func screen_opened() -> void:
	if not has_picture():
		_start_up()


## False while the work computer is off: before its first start-up of the day.
func has_picture() -> bool:
	return _starting or Game.db_day == Game.day_number


# A new day turns the computer off, until the player opens it.
func _check_day() -> void:
	if Game.day_number != _shown_day:
		_shown_day = Game.day_number
		picture_changed.emit()


func _play_key(letter: String) -> void:
	var sound := space_bar if letter == " " and space_bar != null else keystroke
	var speaker := _speaker(KEYS_SPEAKER)
	if sound != null and speaker != null:
		sound.play_on(speaker)


# The first 3D speaker in [param group], in the shop; null, with an error, when there is none.
func _speaker(group: StringName) -> AudioStreamPlayer3D:
	var speaker := get_tree().get_first_node_in_group(group) as AudioStreamPlayer3D
	if speaker == null:
		push_error("CompuFunDB: no AudioStreamPlayer3D in group '%s' to play from" % group)
	return speaker


# The boot, the program at the DOS prompt, the dial-up; then the database.
func _start_up() -> void:
	_starting = true
	_dos.clear()
	picture_changed.emit()
	var boot := boot_scene.instantiate() if boot_scene != null else null
	if boot != null:
		add_child(boot)
	while is_instance_valid(boot) and boot.visible:
		await get_tree().process_frame
	if is_instance_valid(boot):
		boot.queue_free()
	_dos.append("C:\\>")
	for letter: String in command:
		await _pause(randf_range(key_seconds.x, key_seconds.y) * 2.0)
		_dos[-1] += letter
		_play_key(letter)
		queue_redraw()
	for line: String in banner_lines:
		await _pause(start_line_seconds)
		_dos.append(line)
		queue_redraw()
	var modem := _speaker(MODEM_SPEAKER)
	if dialup_sound != null:
		if modem != null:
			modem.stream = dialup_sound
			modem.play()
		await _pause(dialup_sound.get_length())
	for line: String in connect_lines:
		await _pause(start_line_seconds)
		_dos.append(line)
		queue_redraw()
	await _pause(start_line_seconds * 2.0)
	if is_instance_valid(modem):
		modem.stop()
	_dos.clear()
	_starting = false
	Game.start_db()


func _pause(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _on_click(button: InputEventMouseButton) -> void:
	var cell := Vector2i((button.position / CELL).floor())
	var column := _column_at(cell.x)
	if column < 0 or _starting or _offline():
		return
	if button.button_index == MOUSE_BUTTON_WHEEL_UP or button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		var step := -1 if button.button_index == MOUSE_BUTTON_WHEEL_UP else 1
		var count := _lines(column, _entries(column)).size()
		_scroll[column] = clampi(_scroll[column] + step, 0, maxi(count - (LIST_BOTTOM - LIST_TOP + 1), 0))
		queue_redraw()
		return
	if button.button_index != MOUSE_BUTTON_LEFT:
		return
	_status = ""
	if cell.y == FRAME_ROWS[0] + 1 and column == Column.SEARCH:  # the field
		_column = Column.SEARCH
		queue_redraw()
		return
	if cell.y == FRAME_ROWS[-1]:
		var buttons := _buttons()
		for text: String in buttons:
			var x := _button_x(buttons[text], text)
			if cell.x >= x and cell.x < x + text.length():
				if text == PRINT_FIX_BUTTON:
					_print_fix()
				else:
					_print()
				queue_redraw()
				return
	if cell.y < LIST_TOP or cell.y > LIST_BOTTOM:
		return
	var lines := _lines(column, _entries(column))
	var line := _scroll[column] + cell.y - LIST_TOP
	if line >= lines.size():
		return
	if not _entries(column)[lines[line][0]].pick:  # a heading
		return
	_column = column
	_select(lines[line][0])
	_act()
	queue_redraw()


func _on_key(key: InputEventKey) -> bool:
	if _starting or _offline():
		return false
	var typing := _column == Column.SEARCH
	if key.keycode == KEY_ESCAPE or (not typing and key.is_action(&"go_back") and key.keycode != KEY_DOWN):
		return false  # main.gd goes back, as the Back button does
	_status = ""
	match key.keycode:
		KEY_UP:
			_move(-1)
		KEY_DOWN:
			_move(1)
		KEY_LEFT:
			_change_column(-1)
		KEY_RIGHT, KEY_TAB:
			_change_column(1)
		KEY_ENTER, KEY_KP_ENTER when typing and _typed != _searched:
			_run_search()
		KEY_ENTER, KEY_KP_ENTER:
			_act()
		KEY_BACKSPACE when typing:
			_type(_typed.left(-1))
		KEY_SPACE when not typing:
			_act()
		KEY_P when not typing:
			_print()
		KEY_F when not typing:
			_print_fix()
		_:
			var letter := char(key.unicode) if key.unicode >= 32 else ""
			if not typing or letter.is_empty() or key.is_command_or_control_pressed() or key.alt_pressed:
				return false
			_type((_typed + letter).left(SEARCH_LENGTH))
	queue_redraw()
	return true


# Sets what SEARCH holds: what an earlier search found goes, and a search that runs stops.
func _type(text: String) -> void:
	_typed = text
	_search_count += 1
	_searching = false
	_searched = ""
	_hits.clear()
	_selected[Column.SEARCH] = 0
	_scroll[Column.SEARCH] = 0


# Searches for the words typed: the symptoms found show one at a time, each after its seek.
func _run_search() -> void:
	_type(_typed)
	_searched = _typed
	var count := _search_count
	_searching = true
	var found := _found(_typed)
	if not await _read(randf_range(search_seconds.x, search_seconds.y), count):
		return
	for symptom: String in found:
		if not await _read(randf_range(hit_seconds.x, hit_seconds.y), count):
			return
		_hits.append(symptom)
		queue_redraw()
	_searching = false
	queue_redraw()


# The hard drive seeks for [param seconds]; false when another search or typing took over meanwhile.
func _read(seconds: float, count: int) -> bool:
	var speaker := _speaker(MODEM_SPEAKER) if hdd_seek != null else null
	while seconds > 0.0:
		if speaker != null:
			hdd_seek.play_at(speaker)
		var wait := minf(seconds, randf_range(seek_seconds.x, seek_seconds.y))
		seconds -= wait
		await _pause(wait)
		if count != _search_count or not is_inside_tree():
			return false
	return true


# Prints the search's checklist on the shop's Printer.
func _print() -> void:
	if Game.db_search != null:
		_print_page(_page())


# Prints the search's FIX steps alone on the shop's Printer; nothing while it has none.
func _print_fix() -> void:
	if not _entries(Column.FIXES).is_empty():
		_print_page(_page("FIX", [Column.FIXES]))


func _print_page(page: PackedStringArray) -> void:
	var printer := get_tree().get_first_node_in_group(Printer.GROUP) as Printer
	if printer == null:
		push_error("CompuFunDB: no Printer in group '%s' to print '%s' on" % [Printer.GROUP, page[0]])
		_status = "Printer not ready"
		return
	printer.print_page(page)
	_status = "Printing on LPT1"


# A printout of the search: a heading with [param title], the symptom searched for, and [param columns]
# as on screen; a column without lines is left out.
func _page(title: String = "CHECKLIST", columns: Array[Column] = [Column.CHECKS, Column.FIXES]) -> PackedStringArray:
	var page := PackedStringArray(["CompuFunDB 1.0  %s  %s" % [title, _date_text()], ""])
	page.append_array(_wrap("SEARCH: " + Game.db_search.query, _spans[Column.CHECKS].y - _spans[Column.CHECKS].x + 1))
	for column: Column in columns:
		var lines := _lines(column, _entries(column))
		if lines.is_empty():
			continue
		page.append_array(PackedStringArray(["", HEADERS[column]]))
		for line: Array in lines:
			page.append((line[1] as String).strip_edges(false, true))
	return page


func _date_text() -> String:
	var date: Dictionary = Game.date
	return "%02d/%02d/%02d" % [date.month, date.day, date.year % 100]


# The buttons that show in the bottom frame, each with the column that it is centred under.
func _buttons() -> Dictionary[String, Column]:
	var buttons: Dictionary[String, Column] = {}
	if Game.db_search != null:
		buttons[PRINT_BUTTON] = Column.CHECKS
		if not _entries(Column.FIXES).is_empty():
			buttons[PRINT_FIX_BUTTON] = Column.FIXES
	return buttons


# The first x of the button [param text], centred under [param column].
func _button_x(column: Column, text: String) -> int:
	var span := _spans[column]
	return span.x + (span.y - span.x + 1 - text.length()) / 2


# Acts on the entry under the cursor: a symptom found picks it for the search, a symptom to check or
# a step toggles.
func _act() -> void:
	var entries := _entries(_column)
	var index := _selected[_column]
	if index >= entries.size() or not entries[index].pick:
		return
	var entry := entries[index]
	match _column:
		Column.SEARCH:
			_search(entry.text)
		Column.CHECKS:
			Game.mark_check(entry.text, not entry.check)
		Column.FIXES:
			Game.tick_repair(entry.text, not entry.check)
	queue_redraw()


# Moves the cursor [param step] entries, past the headings; 0 settles it on an entry.
func _move(step: int) -> void:
	var entries := _entries(_column)
	var index := clampi(_selected[_column] + step, 0, maxi(entries.size() - 1, 0))
	var direction := -1 if step < 0 else 1
	while index >= 0 and index < entries.size() and not entries[index].pick:
		index += direction
	if index >= 0 and index < entries.size():
		_select(index)
	queue_redraw()


func _change_column(step: int) -> void:
	var column := clampi(_column + step, 0, Column.size() - 1) as Column
	if column != Column.SEARCH and Game.db_search == null:
		return
	_column = column
	_move(0)


# Selects entry [param index] of the current column and scrolls it into view.
func _select(index: int) -> void:
	_selected[_column] = index
	var entries := _entries(_column)
	var lines := _lines(_column, entries)
	var height := LIST_BOTTOM - LIST_TOP + 1
	var shown := index  # the entry, and the headings right above it
	while shown > 0 and shown <= entries.size() and not entries[shown - 1].pick:
		shown -= 1
	var first := -1
	var last := -1
	for i: int in lines.size():
		if lines[i][0] >= shown and lines[i][0] <= index:
			last = i
			if first < 0:
				first = i
	if first < 0:
		return
	if first < _scroll[_column]:
		_scroll[_column] = first
	elif last >= _scroll[_column] + height:
		_scroll[_column] = last - height + 1


# Keeps the cursors on entries that exist, and in SEARCH while there is no search.
func _reconcile() -> void:
	if Game.db_search == null:
		_column = Column.SEARCH
	for column: int in Column.size():
		_selected[column] = clampi(_selected[column], 0, maxi(_entries(column as Column).size() - 1, 0))


func _column_at(x: int) -> int:
	for column: int in _spans.size():
		if x >= _spans[column].x and x <= _spans[column].y:
			return column
	return -1


func _offline() -> bool:
	return Game.phase == Game.Phase.CALLING


func _draw() -> void:
	_chars.resize(COLUMNS * ROWS)
	_chars.fill(" ")
	_fg.resize(COLUMNS * ROWS)
	_fg.fill(text_color)
	_bg.resize(COLUMNS * ROWS)
	_bg.fill(background)
	_paint()
	draw_rect(Rect2(Vector2.ZERO, size), background)
	var ascent := font.get_ascent(int(CELL.y)) if font != null else 0.0
	for y: int in ROWS:
		for x: int in COLUMNS:
			var i := y * COLUMNS + x
			var fg := _fg[i]
			var bg := _bg[i]
			if Vector2i(x, y) == _mouse_cell:  # the text-mode mouse: the cell in reverse
				var swap := fg
				fg = bg
				bg = swap
			var at := Vector2(x, y) * CELL
			if bg != background:
				draw_rect(Rect2(at, CELL), bg)
			if _chars[i] != " " and font != null:
				draw_char(font, at + Vector2(0, ascent), _chars[i], int(CELL.y), fg)


func _paint() -> void:
	if _starting:
		for row: int in mini(_dos.size(), ROWS):
			var line := _dos[_dos.size() - mini(_dos.size(), ROWS) + row]
			_put(0, row, line + ("_" if row == mini(_dos.size(), ROWS) - 1 else ""), text_color)
		return
	if not has_picture():
		return
	_reconcile()
	_bar(0, " CompuFunDB 1.0", _date_text() + " ", bar_color)
	_frame()
	for column: int in Column.size():
		_put(_spans[column].x, FRAME_ROWS[0] + 1, HEADERS[column], bright_color)
	_paint_field()
	if _offline():
		_put(30, 15, " OFFLINE: LINE IN USE ", bright_color, bar_color)
		_bar(28, " CompuFunDB", "", bar_color)
		return
	for column: int in Column.size():
		_paint_column(column as Column)
	var count := "%d found " % _hits.size() if not _searched.is_empty() else ""
	var buttons := _buttons()
	for text: String in buttons:
		_put(_button_x(buttons[text], text), FRAME_ROWS[-1], text, bright_color, bar_color)
	var status := _status if not _status.is_empty() else ("Searching..." if _searching else HEADERS[_column])
	_bar(28, " %s" % status, count, bar_color)
	_put(1, 29, "Type Search  \u2191\u2193 Move  \u2190\u2192 Column  Enter Pick  P Print  F Print fix  Esc Leave", text_color)


# What the player typed, after the SEARCH header: its end, if it is longer than the column.
func _paint_field() -> void:
	var x := _spans[Column.SEARCH].x + HEADERS[Column.SEARCH].length()
	_put(x, FRAME_ROWS[0] + 1, ":", bright_color)
	var fg := bright_color if _column == Column.SEARCH else text_color
	_put(x + 1, FRAME_ROWS[0] + 1, (_typed + ("_" if _column == Column.SEARCH else "")).right(_spans[Column.SEARCH].y - x), fg)


func _paint_column(column: Column) -> void:
	var entries := _entries(column)
	var lines := _lines(column, entries)
	var span := _spans[column]
	for row: int in LIST_BOTTOM - LIST_TOP + 1:
		var line := _scroll[column] + row
		if line >= lines.size():
			break
		var index: int = lines[line][0]
		var entry := entries[index]
		var fg := text_color if entry.pick else dim_color
		var bg := background
		if column == _column and index == _selected[column]:
			fg = bright_color
			bg = bar_color
		_put(span.x, LIST_TOP + row, (lines[line][1] as String).rpad(span.y - span.x + 1), fg, bg)
	if _scroll[column] > 0:
		_put(span.y, LIST_TOP, "↑", bright_color)
	if lines.size() > _scroll[column] + LIST_BOTTOM - LIST_TOP + 1:
		_put(span.y, LIST_BOTTOM, "↓", bright_color)


func _frame() -> void:
	var seps: Array[int] = [0, _spans[0].y + 1, _spans[1].y + 1, COLUMNS - 1]
	for y: int in range(FRAME_ROWS[0], FRAME_ROWS[-1] + 1):
		for x: int in seps:
			_put(x, y, "\u2551", text_color)
	for y: int in FRAME_ROWS:
		_put(1, y, "\u2550".repeat(COLUMNS - 2), text_color)
		for x: int in seps:
			var left := x == 0
			var right := x == COLUMNS - 1
			var glyph: String
			if y == FRAME_ROWS[0]:
				glyph = "\u2554" if left else ("\u2557" if right else "\u2566")
			elif y == FRAME_ROWS[-1]:
				glyph = "\u255a" if left else ("\u255d" if right else "\u2569")
			else:
				glyph = "\u2560" if left else ("\u2563" if right else "\u256c")
			_put(x, y, glyph, text_color)


func _bar(y: int, left: String, right: String, color: Color) -> void:
	_put(0, y, left.rpad(COLUMNS - right.length()) + right, bright_color, color)


func _put(x: int, y: int, text: String, fg: Color, bg: Color = background) -> void:
	for i: int in text.length():
		if x + i >= COLUMNS:
			return
		var cell := y * COLUMNS + x + i
		_chars[cell] = text[i]
		_fg[cell] = fg
		_bg[cell] = bg
