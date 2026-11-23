class_name CompuFunDB
extends Control
## CompuFunDB on the work computer: a DOS database in text mode, 80 x 30 characters. Three columns:
## SEARCH (the player types words and presses Enter: the symptoms of every Problem that hold them
## all), CHECK (the checks of every cause of the symptom picked: the Game.db_search; the player ticks what is true on the computer) and CAUSES
## (every Problem with that symptom, by its cause; a ticked check rules out a cause that says no: to
## it, or that doesn't say yes: to a check another cause says yes: to). F prints the selected cause's fix, its steps ending in [member test_step], on the
## shop's Printer; P prints the checklist. The work computer is slow: a column's entries come in one
## at a time, each after a seek of the hard drive, whenever what it shows changes. This screen keeps
## only its cursor and the typed words. It reads every Problem file, so its text is never a second
## copy of the problems.
## The first time the player opens it on a day, the work computer boots, the character starts the
## program at the DOS prompt and the modem dials up; until then the computer is off. Nothing skips
## the start-up; the player can leave meanwhile, and it goes on.
## Keys: in SEARCH, letters type, Backspace erases, and Enter searches, or picks a symptom found for
## the words as typed; arrows and Tab move; Enter and Space tick a check or print the cause under the
## cursor; outside SEARCH, P and F print, and the go_back keys but Down leave the view, as the Back
## button does; Esc always does. The mouse clicks and scrolls.

const PROBLEMS_DIR: String = "res://problems/"
const COLUMNS: int = 80
const ROWS: int = 30
const CELL: Vector2 = Vector2(8, 16)
## The rows of the frame's lines: the top, under the headers, the bottom.
const FRAME_ROWS: Array[int] = [1, 3, 27]
## The first and last row of the lists, between the headers and the bottom frame.
const LIST_TOP: int = 4
const LIST_BOTTOM: int = 26
## The buttons in the bottom frame, under the CHECK and the CAUSES column, that do what P and F do.
const PRINT_BUTTON: String = "[ PRINT CHECKLIST ]"
const PRINT_FIX_BUTTON: String = "[ PRINT FIX ]"

enum Column { SEARCH, CHECKS, CAUSES }

const HEADERS: Array[String] = ["SEARCH", "CHECK", "CAUSES"]
## The most characters that the player can type into SEARCH.
const SEARCH_LENGTH: int = 40
## The print box over the middle of the screen: its width and its top row, and its OK button.
const PRINT_BOX_WIDTH: int = 36
const PRINT_BOX_TOP: int = 12
const OK_BUTTON: String = "[ OK ]"

## The text-mode font: one glyph per 8 x 16 cell.
@export var font: Font = preload("res://compufun_db/fonts/Px437_IBM_VGA_8x16.ttf")
@export var background: Color = Color.BLACK
@export var text_color: Color = Color(0.667, 0.667, 0.667)
@export var bright_color: Color = Color.WHITE
@export var dim_color: Color = Color(0.333, 0.333, 0.333)
## The CompuFun red of the bars, the headers and the selection.
@export var bar_color: Color = Color(0.89, 0, 0)
## The last repair step of every fix but a software-only one, after its hardware and software steps
## (see Job.tested). A software fix lands on a running Windows, which tests it at once.
@export var test_step: String = "Test the computer"
## The sound of each key that the character types.
@export var keystroke: SoundSet = preload("res://sounds/keystroke.tres")
## The sound of the space bar; null plays [member keystroke].
@export var space_bar: SoundSet = preload("res://sounds/keystroke_space.tres")
## The seconds that SEARCH's cursor stays on, and then off.
@export var cursor_blink_seconds: float = 0.5
## The seconds between two keys, picked between x and y for each key.
@export var key_seconds: Vector2 = Vector2(0.03, 0.09)
@export_group("Search")
## The seconds that a search reads before its first symptom shows, picked between x and y.
@export var search_seconds: Vector2 = Vector2(0.6, 1.0)
## The seconds that each symptom found takes to show, picked between x and y for each; the more
## found, the longer the search.
@export var hit_seconds: Vector2 = Vector2(0.3, 0.7)
## The seconds between two seeks of the hard drive while it reads, picked between x and y.
@export var seek_seconds: Vector2 = Vector2(0.05, 0.2)
## The hard drive seeking, dry, from beside the work modem's speaker by the tower; null is silent.
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
## Every symptom of every problem, once each, in the order of the problems.
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
## How many entries of CHECK and CAUSES the slow computer has read in so far, and the search it read
## them for: a new search reads them in again, one entry at a time.
var _loaded: Array[int] = [0, 0, 0]
var _loaded_key: Array[String] = ["", "", ""]
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
## The printer that prints the page named [member _printing], while the print box shows over the
## screen; null when nothing prints. Once the page is out, [member _print_done] shows "Print complete"
## until the player presses its OK.
var _printer: Printer
var _printing: String = ""
var _print_done: bool = false
## SEARCH's cursor shows, for this half of its blink.
var _cursor_on: bool = true
## The frame of the spinner in the header of a column that the computer is reading in.
var _spin: int = 0
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
	set_process(false)
	Game.changed.connect(queue_redraw)
	Game.changed.connect(_check_day)
	Game.changed.connect(_reconcile)
	Game.changed.connect(_reload)
	var blink := Timer.new()
	blink.wait_time = cursor_blink_seconds
	blink.timeout.connect(func() -> void:
		_cursor_on = not _cursor_on
		if _column == Column.SEARCH:
			queue_redraw())
	add_child(blink)
	blink.start()
	var spinner := Timer.new()
	spinner.wait_time = 0.12
	spinner.timeout.connect(func() -> void:
		if Column.values().any(_busy):
			_spin += 1
			queue_redraw())
	add_child(spinner)
	spinner.start()


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
			if symptom not in _symptoms:
				_symptoms.append(symptom)
	if _problems.is_empty():
		push_error("CompuFunDB: no Problem files in %s" % PROBLEMS_DIR)


# The entries of a column that show: CHECK and CAUSES only as far as the computer has read them in.
func _entries(column: Column) -> Array[Dictionary]:
	var entries := _all_entries(column)
	return entries if column == Column.SEARCH else entries.slice(0, _loaded[column])


# An entry of a column: its text, its check box (null: none), whether the player can pick it, and for
# a cause, its problem.
func _all_entries(column: Column) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var search := _picked()
	match column:
		Column.SEARCH:
			for symptom: String in _hits:
				entries.append({text = symptom, check = null, pick = true})
		Column.CHECKS:
			if search != null:
				for check: String in search.offered:
					entries.append({text = check, check = check in search.ticked_checks, pick = true})
		Column.CAUSES:
			for problem: Problem in _causes():
				entries.append({text = problem.cause_name(), check = null, pick = _possible(problem), problem = problem})
	return entries


# Adds a section of numbered steps, the first numbered [param number]; returns the next number.
func _add_steps(entries: Array[Dictionary], title: String, steps: PackedStringArray, number: int) -> int:
	if steps.is_empty():
		return number
	entries.append({text = "-- %s --" % title, check = null, pick = false})
	for step: String in steps:
		entries.append({text = step, check = false, pick = true, number = number})
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


# Game's search while its symptom is listed under SEARCH, picked; null otherwise: CHECK and CAUSES
# show nothing until the player picks a symptom that the words typed found.
func _picked() -> DbSearch:
	var search := Game.db_search
	return search if search != null and search.query in _hits else null


# The problems with the symptom searched for, in the order of the problems.
func _causes() -> Array[Problem]:
	var search := _picked()
	return _problems.filter(func(p: Problem) -> bool: return search != null and search.query in p.symptoms)


# False once a ticked check rules [param problem] out: one it says no: to, or one that another
# problem says yes: to and it doesn't (a computer has one cause).
func _possible(problem: Problem) -> bool:
	var findings := _findings()
	for check: String in Game.db_search.ticked_checks:
		if problem.check_yes.has(check) and not problem.check_yes[check]:
			return false
		if not problem.check_yes.has(check) and findings.has(check):
			return false
	return true


# Every check that some problem says yes: to.
func _findings() -> Dictionary[String, bool]:
	var found: Dictionary[String, bool] = {}
	for problem: Problem in _problems:
		for check: String in problem.check_yes:
			if problem.check_yes[check]:
				found[check] = true
	return found


# Starts the search for [param query]: what to check is the checks of every problem that has it, in
# the order of the problems.
func _search(query: String) -> void:
	var offered: Array[String] = []
	for problem: Problem in _problems:
		if query in problem.symptoms:
			for check: String in problem.checks:
				if check not in offered:
					offered.append(check)
	if Game.search_db(query, offered) == null:
		return
	_column = Column.CHECKS
	for column: Column in [Column.CHECKS, Column.CAUSES]:
		_selected[column] = 0
		_scroll[column] = 0
	_move(0)



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


# The hard drive's player beside the work modem's speaker: dry, on the Shop bus, past the sound
# zones, whose reverb smears the fast ticks into an echo. null, with an error, without the speaker.
func _drive() -> AudioStreamPlayer3D:
	var speaker := _speaker(MODEM_SPEAKER)
	if speaker == null:
		return null
	var drive := speaker.get_node_or_null(^"HardDrive") as AudioStreamPlayer3D
	if drive == null:
		drive = AudioStreamPlayer3D.new()
		drive.name = "HardDrive"
		drive.area_mask = 0
		drive.bus = &"Shop"
		drive.unit_size = speaker.unit_size
		speaker.add_child(drive)
	return drive


func _pause(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _on_click(button: InputEventMouseButton) -> void:
	var cell := Vector2i((button.position / CELL).floor())
	if _print_done:  # the box is modal: only its OK does anything
		var ok := _ok_cell()
		if button.button_index == MOUSE_BUTTON_LEFT and cell.y == ok.y and cell.x >= ok.x and cell.x < ok.x + OK_BUTTON.length():
			_close_print_box()
		return
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
	if _print_done:  # the box is modal: Enter, Space or Esc press its OK, other keys do nothing
		if key.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]:
			_close_print_box()
		return true
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
	var still := func() -> bool: return count == _search_count
	_searching = true
	var found := _found(_typed)
	if not await _read(randf_range(search_seconds.x, search_seconds.y), still):
		return
	for symptom: String in found:
		if not await _read(randf_range(hit_seconds.x, hit_seconds.y), still):
			return
		_hits.append(symptom)
		queue_redraw()
	_searching = false
	queue_redraw()


# Reads CHECK and CAUSES in again, one entry at a time, when what they show changed: a new search.
func _reload() -> void:
	var search := Game.db_search
	var keys := ["", "", ""]
	if search != null:
		keys[Column.CHECKS] = str(search.get_instance_id())  # a new search, even for the same symptom
		keys[Column.CAUSES] = keys[Column.CHECKS]
	for column: Column in [Column.CHECKS, Column.CAUSES]:
		if keys[column] != _loaded_key[column]:
			_loaded_key[column] = keys[column]
			_loaded[column] = 0
			if keys[column] != "":
				_load(column, keys[column])


func _load(column: Column, key: String) -> void:
	var still := func() -> bool: return _loaded_key[column] == key
	while column == Column.CAUSES and still.call() and _busy(Column.CHECKS) and is_inside_tree():
		await get_tree().process_frame  # one column at a time: CAUSES after CHECK
	while still.call() and _loaded[column] < _all_entries(column).size():
		if not await _read(randf_range(hit_seconds.x, hit_seconds.y), still):
			return
		_loaded[column] += 1
		queue_redraw()


# True while the computer reads CHECK or CAUSES in.
func _loading() -> bool:
	return [Column.CHECKS, Column.CAUSES].any(func(c: Column) -> bool: return _loaded[c] < _all_entries(c).size())


# True while the computer reads [param column] in: SEARCH while it searches, the others until all
# their entries show; CAUSES only once CHECK is done, as it waits until then.
func _busy(column: Column) -> bool:
	if column == Column.SEARCH:
		return _searching
	if column == Column.CAUSES and _busy(Column.CHECKS):
		return false
	return _loaded[column] < _all_entries(column).size()


# The hard drive seeks for [param seconds]; false when [param still] stops holding meanwhile (another
# search, typing, or the column now shows something else).
func _read(seconds: float, still: Callable) -> bool:
	var drive := _drive() if hdd_seek != null else null
	while seconds > 0.0:
		if drive != null:
			hdd_seek.play_on(drive)  # one player: a tick cuts the last one off rather than doubling it
		var wait := minf(seconds, randf_range(seek_seconds.x, seek_seconds.y))
		seconds -= wait
		await _pause(wait)
		if not still.call() or not is_inside_tree():
			return false
	return true


# Prints the search's checklist on the shop's Printer.
func _print() -> void:
	if _picked() != null:
		_print_page(_page())


# Prints the fix of the cause under the CAUSES cursor on the shop's Printer; nothing while it is ruled
# out or not read in yet.
func _print_fix() -> void:
	var cause := _selected_cause()
	if cause == null:
		_status = "Pick a possible cause"
		return
	_print_page(_fix_page(cause))


# The cause under the CAUSES cursor, while it shows and is possible; null otherwise.
func _selected_cause() -> Problem:
	var entries := _entries(Column.CAUSES)
	var index := _selected[Column.CAUSES]
	if index >= entries.size() or not entries[index].pick:
		return null
	return entries[index].problem


func _print_page(page: PackedStringArray) -> void:
	var printer := get_tree().get_first_node_in_group(Printer.GROUP) as Printer
	if printer == null:
		push_error("CompuFunDB: no Printer in group '%s' to print '%s' on" % [Printer.GROUP, page[0]])
		_status = "Printer not ready"
		return
	printer.print_page(page)
	_status = "Printing on LPT1"
	_printer = printer
	_printing = page[0].get_slice("  ", 1)  # the heading's title: CHECKLIST or FIX
	set_process(true)


# Redraws the print box while the page prints; when it is out, the box says so until OK.
func _process(_delta: float) -> void:
	if not is_instance_valid(_printer) or _printer.progress() < 0.0:
		_printer = null
		_print_done = true
		set_process(false)
	queue_redraw()


# Closes "Print complete" and clears the search, ready for the next.
func _close_print_box() -> void:
	_printing = ""
	_print_done = false
	_type("")
	_column = Column.SEARCH
	queue_redraw()


# The print box in the middle of the screen: what prints and how far, in a bar of blocks; then that
# it is done, with an OK button.
func _paint_printing() -> void:
	var left := (COLUMNS - PRINT_BOX_WIDTH) / 2
	var inner := PRINT_BOX_WIDTH - 4
	var middle: String
	var lines: PackedStringArray
	if _print_done:
		lines = [" Print complete", " %s printed on LPT1." % _printing]
		middle = ""
	else:
		var done := roundi(_printer.progress() * inner) if _printer != null else inner
		lines = [" Print", " Printing %s on LPT1..." % _printing]
		middle = " " + "".rpad(done, "\u2588") + "".rpad(inner - done, "\u2591") + " "  # repeat(0) is an error
	var rows: PackedStringArray = ["\u2554" + "\u2550".repeat(PRINT_BOX_WIDTH - 2) + "\u2557"]
	for line: String in lines:
		rows.append("\u2551" + line.rpad(PRINT_BOX_WIDTH - 2) + "\u2551")
	rows.append("\u2551" + middle.rpad(PRINT_BOX_WIDTH - 2) + "\u2551")
	rows.append("\u255a" + "\u2550".repeat(PRINT_BOX_WIDTH - 2) + "\u255d")
	for i: int in rows.size():
		_put(left, PRINT_BOX_TOP + i, rows[i], bright_color, bar_color)
	if _print_done:
		_put(_ok_cell().x, _ok_cell().y, OK_BUTTON, bar_color, bright_color)


# The first cell of the print box's OK button.
func _ok_cell() -> Vector2i:
	return Vector2i((COLUMNS - OK_BUTTON.length()) / 2, PRINT_BOX_TOP + 3)


# The checklist: the symptom searched for, the checks with their ticks, and the causes still possible.
func _page() -> PackedStringArray:
	var page := _heading("CHECKLIST")
	for column: Column in [Column.CHECKS, Column.CAUSES]:
		var entries := _all_entries(column).filter(func(e: Dictionary) -> bool: return e.pick)
		var lines := _lines(column, entries)
		if lines.is_empty():
			continue
		page.append_array(PackedStringArray(["", HEADERS[column] if column != Column.CAUSES else "POSSIBLE CAUSES"]))
		for line: Array in lines:
			page.append((line[1] as String).strip_edges(false, true))
	return page


# The fix of [param cause]: its name, then its steps, numbered, each with a check box.
func _fix_page(cause: Problem) -> PackedStringArray:
	var page := _heading("FIX")
	page.append_array(PackedStringArray(["", "CAUSE"]))
	page.append_array(_wrap(cause.cause_name(), _width(Column.CAUSES)))
	var entries: Array[Dictionary] = []
	var number := _add_steps(entries, "Hardware", cause.hardware_steps, 1)
	number = _add_steps(entries, "Software", cause.software_steps, number)
	if cause.location != Problem.Location.SOFTWARE:
		_add_steps(entries, "Test", PackedStringArray([test_step]), number)
	page.append("")
	for line: Array in _lines(Column.CAUSES, entries):
		page.append((line[1] as String).strip_edges(false, true))
	return page


func _heading(title: String) -> PackedStringArray:
	var page := PackedStringArray(["CompuFunDB 1.0  %s  %s" % [title, _date_text()], ""])
	if Game.db_search != null:
		page.append_array(_wrap("SEARCH: " + Game.db_search.query, _width(Column.CHECKS)))
	return page


func _width(column: Column) -> int:
	return _spans[column].y - _spans[column].x + 1


func _date_text() -> String:
	var date: Dictionary = Game.date
	return "%02d/%02d/%02d" % [date.month, date.day, date.year % 100]


# The buttons that show in the bottom frame, each with the column that it is centred under.
func _buttons() -> Dictionary[String, Column]:
	var buttons: Dictionary[String, Column] = {}
	if _picked() != null:
		buttons[PRINT_BUTTON] = Column.CHECKS
		if _selected_cause() != null:
			buttons[PRINT_FIX_BUTTON] = Column.CAUSES
	return buttons


# The first x of the button [param text], centred under [param column].
func _button_x(column: Column, text: String) -> int:
	var span := _spans[column]
	return span.x + (span.y - span.x + 1 - text.length()) / 2


# Acts on the entry under the cursor: a symptom found picks it for the search, a check toggles, a
# cause prints its fix.
func _act() -> void:
	var entries := _entries(_column)
	var index := _selected[_column]
	if index >= entries.size() or not entries[index].pick:
		return
	var entry := entries[index]
	match _column:
		Column.SEARCH:
			if _picked() != null and entry.text == _picked().query:
				_change_column(1)  # picked already: keep its checks and ticks
			else:
				_search(entry.text)
		Column.CHECKS:
			Game.mark_check(entry.text, not entry.check)
		Column.CAUSES:
			_print_fix()
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
	if column != Column.SEARCH and _picked() == null:
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
	if _picked() == null:
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
	for column: int in Column.size():
		if _busy(column as Column):  # a spinner at the header's end while the column reads in
			_put(_spans[column].y - 1, FRAME_ROWS[0] + 1, "|/-\\"[_spin % 4], bright_color)  # a cell clear of the border
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
	var status := _status if not _status.is_empty() else ("Searching..." if _searching else ("Reading..." if _loading() else HEADERS[_column]))
	_bar(28, " %s" % status, count, bar_color)
	if _printing != "":
		_paint_printing()
	_put(1, 29, "Type Search  \u2191\u2193 Move  \u2190\u2192 Column  Enter Pick  P Checklist  F Fix  Esc Leave", text_color)


# What the player typed, after the SEARCH header: its end, if it is longer than the column.
func _paint_field() -> void:
	var x := _spans[Column.SEARCH].x + HEADERS[Column.SEARCH].length()
	_put(x, FRAME_ROWS[0] + 1, ":", bright_color)
	var fg := bright_color if _column == Column.SEARCH else text_color
	var cursor := "_" if _column == Column.SEARCH and _cursor_on else " "  # blinks, to draw the eye to the field
	_put(x + 1, FRAME_ROWS[0] + 1, (_typed + cursor).right(_spans[Column.SEARCH].y - x), fg)


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
		if column == Column.SEARCH and _picked() != null and entry.text == _picked().query:
			fg = bright_color  # the symptom picked stays marked while the player works in the other columns
			bg = dim_color
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
