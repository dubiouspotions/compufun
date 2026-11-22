class_name CompuFunDB
extends Control
## CompuFunDB on the work computer: a DOS database in text mode, 80 x 30 characters. Three columns:
## the customers (the Game.records of the computers on the counter: a record leaves the list when its
## computer leaves the counter; New record makes the character type up the next computer on the
## counter, key by key), what to check (every symptom of every Problem; the player marks what is
## wrong on the selected record), and what to fix (the repair steps of each problem whose symptoms
## are all marked, numbered and ending in [member test_step]; the player ticks them off). Marking
## the wrong symptoms leads to the wrong fix. This screen keeps only its cursor and the typing. It
## reads every Problem file, so its text is never a second copy of the problems.
## The first time the player opens it on a day, the work computer boots, the character starts the
## program at the DOS prompt and the modem dials up; until then the computer is off. Any key or
## click skips to the database.
## Keys: arrows and Tab move, Space or Enter acts, P prints the selected record's checklist on
## the shop's Printer, F only its FIX steps. The mouse clicks and scrolls.

const PROBLEMS_DIR: String = "res://problems/"
const COLUMNS: int = 80
const ROWS: int = 30
const CELL: Vector2 = Vector2(8, 16)
## The rows of the frame's lines: the top, under the headers, the bottom.
const FRAME_ROWS: Array[int] = [1, 3, 27]
## The first and last row of the lists, between the headers and the bottom frame.
const LIST_TOP: int = 4
const LIST_BOTTOM: int = 26
const NEW_RECORD: String = "<New record>"
## The buttons in the bottom frame, under the CHECK and the FIX column, that do what P and F do.
const PRINT_BUTTON: String = "[ PRINT CHECKLIST ]"
const PRINT_FIX_BUTTON: String = "[ PRINT FIX ]"

enum Column { RECORDS, CHECKS, FIXES }

const HEADERS: Array[String] = ["CUSTOMER", "CHECK", "FIX"]

## The text-mode font: one glyph per 8 x 16 cell.
@export var font: Font = preload("res://compufun_db/fonts/Px437_IBM_VGA_8x16.ttf")
@export var background: Color = Color.BLACK
@export var text_color: Color = Color(0.667, 0.667, 0.667)
@export var bright_color: Color = Color.WHITE
@export var dim_color: Color = Color(0.333, 0.333, 0.333)
## The CompuFun red of the bars, the headers and the selection.
@export var bar_color: Color = Color(0.89, 0, 0)
## The last repair step of every problem, after its hardware and software steps (see Job.tested).
@export var test_step: String = "Test the computer"
## The sound of each key that the character types.
@export var keystroke: SoundSet = preload("res://sounds/keystroke.tres")
## The seconds between two keys, picked between x and y for each key.
@export var key_seconds: Vector2 = Vector2(0.03, 0.09)
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

## The picture changed: the computer started, or a new day turned it off.
signal picture_changed

## The first and last x of each column's text, inside the frame.
var _spans: Array[Vector2i] = [Vector2i(1, 24), Vector2i(26, 51), Vector2i(53, 78)]
var _problems: Array[Problem] = []
## Every symptom of every problem, once each, in the order of the problems.
var _symptoms: PackedStringArray = []
var _column: Column = Column.RECORDS
var _selected: Array[int] = [0, 0, 0]
var _scroll: Array[int] = [0, 0, 0]
## The Job.order of each record in the first column at the last [method _reconcile], so that the
## cursor follows its record when the list changes.
var _listed: Array[int] = []
var _mouse_cell: Vector2i = Vector2i(-1, -1)
## The record that the character is typing up, or null; [member _shown] of its characters show.
var _typing: DbRecord
var _shown: int = 0
var _next_key: float = 0.0
var _keys: AudioStreamPlayer
## True from the first opening of a day until the database shows.
var _starting: bool = false
## The player skipped the start-up.
var _skip: bool = false
## The DOS screen of the start-up, line by line.
var _dos: PackedStringArray = []
var _modem: AudioStreamPlayer
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
	_keys = AudioStreamPlayer.new()
	add_child(_keys)
	_modem = AudioStreamPlayer.new()
	_modem.stream = dialup_sound
	add_child(_modem)
	set_process(false)
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
		_problems.append(problem)
		for symptom: String in problem.symptoms:
			if symptom not in _symptoms:
				_symptoms.append(symptom)
	if _problems.is_empty():
		push_error("CompuFunDB: no Problem files in %s" % PROBLEMS_DIR)


# An entry of a column: its text, its check box (null: none) and whether the player can pick it.
func _entries(column: Column) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	match column:
		Column.RECORDS:
			for record: DbRecord in _records():
				var text := record.text.left(_shown) + "_" if record == _typing else record.text
				entries.append({text = text, check = null, pick = true})
			if _waiting_job() != null and _typing == null:
				entries.append({text = NEW_RECORD, check = null, pick = true})
		Column.CHECKS:
			var record := _record()
			if record != null:
				for symptom: String in _symptoms:
					entries.append({text = symptom, check = symptom in record.marked_symptoms, pick = true})
		Column.FIXES:
			var record := _record()
			if record != null:
				for problem: Problem in _matches(record):
					var number := _add_steps(entries, record, "Hardware", problem.hardware_steps, 1)
					number = _add_steps(entries, record, "Software", problem.software_steps, number)
					_add_steps(entries, record, "Test", PackedStringArray([test_step]), number)
	return entries


# Adds a section of numbered steps, the first numbered [param number]; returns the next number.
func _add_steps(entries: Array[Dictionary], record: DbRecord, title: String, steps: PackedStringArray, number: int) -> int:
	if steps.is_empty():
		return number
	entries.append({text = "-- %s --" % title, check = null, pick = false})
	for step: String in steps:
		entries.append({text = step, check = step in record.ticked_repairs, pick = true, number = number})
		number += 1
	return number


# The record under the first column's cursor, or null on <New record> or while it is typed up.
func _record() -> DbRecord:
	var records := _records()
	var index := _selected[Column.RECORDS]
	var record: DbRecord = records[index] if index < records.size() else null
	return record if record != _typing else null


# The records of the computers on the counter, oldest first.
func _records() -> Array[DbRecord]:
	var on_counter: Array[int] = []
	for job: Job in Game.jobs:
		on_counter.append(job.order)
	var listed: Array[DbRecord] = []
	for record: DbRecord in Game.records:
		if record.job_order in on_counter:
			listed.append(record)
	return listed


# The oldest computer on the counter without a record, or null.
func _waiting_job() -> Job:
	var waiting: Job = null
	for job: Job in Game.jobs:
		if Game.record_of(job) == null and (waiting == null or job.order < waiting.order):
			waiting = job
	return waiting


# Types the next key of [member _typing], with its sound, until the record is all there.
func _process(delta: float) -> void:
	_next_key -= delta
	if _next_key > 0.0:
		return
	_shown += 1
	if keystroke != null:
		keystroke.play_on(_keys)
	_next_key = randf_range(key_seconds.x, key_seconds.y)
	if _typing == null or _shown >= _typing.text.length():
		_typing = null
		set_process(false)
		if _waiting_job() != null:
			_type_up(_waiting_job())
		else:
			_column = Column.CHECKS
			_move(0)
	queue_redraw()


# The problems whose symptoms are all marked on [param record].
func _matches(record: DbRecord) -> Array[Problem]:
	var found: Array[Problem] = []
	for problem: Problem in _problems:
		if problem.symptoms.is_empty():
			continue
		var all_marked := true
		for symptom: String in problem.symptoms:
			all_marked = all_marked and symptom in record.marked_symptoms
		if all_marked:
			found.append(problem)
	return found


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


## The player opened the screen: the computer starts up if it hasn't today; then the character
## types up every computer on the counter that has no record yet.
func screen_opened() -> void:
	if not has_picture():
		_start_up()
	elif not _starting and _typing == null and _waiting_job() != null:
		_type_up(_waiting_job())


## False while the work computer is off: before its first start-up of the day.
func has_picture() -> bool:
	return _starting or Game.db_day == Game.day_number


# A new day turns the computer off, until the player opens it.
func _check_day() -> void:
	if Game.day_number != _shown_day:
		_shown_day = Game.day_number
		picture_changed.emit()


# The boot, the program at the DOS prompt, the dial-up; then the database. Any key or click skips.
func _start_up() -> void:
	_starting = true
	_skip = false
	_dos.clear()
	picture_changed.emit()
	var boot := boot_scene.instantiate() if boot_scene != null else null
	if boot != null:
		add_child(boot)
	while is_instance_valid(boot) and boot.visible and not _skip:
		await get_tree().process_frame
	if is_instance_valid(boot):
		boot.queue_free()
	if not _skip:
		_dos.append("C:\\>")
		for letter: String in command:
			if not await _pause(randf_range(key_seconds.x, key_seconds.y) * 2.0):
				break
			_dos[-1] += letter
			if keystroke != null:
				keystroke.play_on(_keys)
			queue_redraw()
	for line: String in banner_lines:
		if _skip or not await _pause(start_line_seconds):
			break
		_dos.append(line)
		queue_redraw()
	if not _skip and dialup_sound != null:
		_modem.play()
		await _pause(dialup_sound.get_length())
	for line: String in connect_lines:
		if _skip or not await _pause(start_line_seconds):
			break
		_dos.append(line)
		queue_redraw()
	if not _skip:
		await _pause(start_line_seconds * 2.0)
	_modem.stop()
	_dos.clear()
	_starting = false
	Game.start_db()
	screen_opened()


# Waits [param seconds]; false when the player skipped meanwhile.
func _pause(seconds: float) -> bool:
	var left := seconds
	while left > 0.0 and not _skip:
		await get_tree().process_frame
		left -= get_process_delta_time()
	return not _skip


# During the start-up, a key or a click skips all of it, the boot too, straight to the database.
func _input(event: InputEvent) -> void:
	if not _starting or not event.is_pressed() or event is InputEventMouseMotion:
		return
	var key := event as InputEventKey
	if key != null and key.keycode == KEY_ESCAPE:
		return  # leaves the screen; the start-up goes on
	_skip = true
	get_viewport().set_input_as_handled()


func _on_click(button: InputEventMouseButton) -> void:
	var cell := Vector2i((button.position / CELL).floor())
	var column := _column_at(cell.x)
	if column < 0 or _offline():
		return
	if button.button_index == MOUSE_BUTTON_WHEEL_UP or button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		var step := -1 if button.button_index == MOUSE_BUTTON_WHEEL_UP else 1
		var count := _lines(column, _entries(column)).size()
		_scroll[column] = clampi(_scroll[column] + step, 0, maxi(count - (LIST_BOTTOM - LIST_TOP + 1), 0))
		queue_redraw()
		return
	if button.button_index != MOUSE_BUTTON_LEFT:
		return
	_finish_typing()
	_status = ""
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
	_column = column
	_select(lines[line][0])
	if column != Column.RECORDS or _record() == null:  # a click on a record only selects it
		_act()
	queue_redraw()


func _on_key(key: InputEventKey) -> bool:
	if _offline():
		return false
	if key.keycode == KEY_ESCAPE:
		return false  # leaves the screen; the typing goes on
	_finish_typing()
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
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			_act()
		KEY_P:
			_print()
		KEY_F:
			_print_fix()
		_:
			return false
	queue_redraw()
	return true


# Prints the selected record's checklist on the shop's Printer.
func _print() -> void:
	var record := _record()
	if record != null:
		_print_page(_page(record))


# Prints the selected record's FIX steps alone on the shop's Printer; nothing while it has none.
func _print_fix() -> void:
	var record := _record()
	if record != null and not _entries(Column.FIXES).is_empty():
		_print_page(_page(record, "FIX", [Column.FIXES]))


func _print_page(page: PackedStringArray) -> void:
	var printer := get_tree().get_first_node_in_group(Printer.GROUP) as Printer
	if printer == null:
		push_error("CompuFunDB: no Printer in group '%s' to print '%s' on" % [Printer.GROUP, page[0]])
		_status = "Printer not ready"
		return
	printer.print_page(page)
	_status = "Printing on LPT1"


# A printout of [param record]: a heading with [param title], the record, and [param columns] as on
# screen; a column without lines is left out.
func _page(record: DbRecord, title: String = "CHECKLIST", columns: Array[Column] = [Column.CHECKS, Column.FIXES]) -> PackedStringArray:
	var page := PackedStringArray(["CompuFunDB 1.0  %s  %s" % [title, _date_text()], ""])
	page.append_array(_wrap(record.text, _spans[Column.CHECKS].y - _spans[Column.CHECKS].x + 1))
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
	if _record() != null:
		buttons[PRINT_BUTTON] = Column.CHECKS
		if not _entries(Column.FIXES).is_empty():
			buttons[PRINT_FIX_BUTTON] = Column.FIXES
	return buttons


# The first x of the button [param text], centred under [param column].
func _button_x(column: Column, text: String) -> int:
	var span := _spans[column]
	return span.x + (span.y - span.x + 1 - text.length()) / 2


# Acts on the entry under the cursor: <New record> types up the next computer, a record opens its
# checks, a symptom or a step toggles.
func _act() -> void:
	var entries := _entries(_column)
	var index := _selected[_column]
	if index >= entries.size() or not entries[index].pick:
		return
	var entry := entries[index]
	match _column:
		Column.RECORDS:
			if index == _records().size():
				_type_up(_waiting_job())
			else:
				_change_column(1)
		Column.CHECKS:
			Game.mark_symptom(_record(), entry.text, not entry.check)
		Column.FIXES:
			Game.tick_repair(_record(), entry.text, not entry.check)
	queue_redraw()


func _type_up(job: Job) -> void:
	_typing = Game.enter_job(job, _record_text(job))
	if _typing == null:
		return
	_shown = 0
	_next_key = 0.0
	_selected[Column.RECORDS] = _records().size() - 1
	set_process(true)


# Shows the rest of the typing at once, and types up the other waiting computers without the keys:
# the player wants the screen now.
func _finish_typing() -> void:
	if _typing == null:
		return
	_typing = null
	set_process(false)
	var job := _waiting_job()
	while job != null and Game.enter_job(job, _record_text(job)) != null:
		job = _waiting_job()
	_selected[Column.RECORDS] = _records().size() - 1


func _record_text(job: Job) -> String:
	return "%s: %s" % [job.customer.display_name, job.problem.perceived_issue]


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
	var column := wrapi(_column + step, 0, Column.size()) as Column
	if column != Column.RECORDS and _record() == null:
		return
	_column = column
	_move(0)


# Selects entry [param index] of the current column and scrolls it into view.
func _select(index: int) -> void:
	if _column == Column.RECORDS and index != _selected[_column]:
		_reset_record_columns()
	_selected[_column] = index
	var lines := _lines(_column, _entries(_column))
	var height := LIST_BOTTOM - LIST_TOP + 1
	var first := -1
	var last := -1
	for i: int in lines.size():
		if lines[i][0] == index:
			last = i
			if first < 0:
				first = i
	if first < 0:
		return
	if first < _scroll[_column]:
		_scroll[_column] = first
	elif last >= _scroll[_column] + height:
		_scroll[_column] = last - height + 1


func _reset_record_columns() -> void:
	for column: Column in [Column.CHECKS, Column.FIXES]:
		_selected[column] = 0
		_scroll[column] = 0


# Keeps the cursors on entries that exist, and in the first column while no record is picked. When
# the list changes, the cursor follows its record; when that record left, the cursor goes back to
# the first column, on the record that took its place.
func _reconcile() -> void:
	var listed: Array[int] = []
	for record: DbRecord in _records():
		listed.append(record.job_order)
	if listed != _listed:
		var index := _selected[Column.RECORDS]
		var was := _listed[index] if index < _listed.size() else -1
		if was in listed:
			_selected[Column.RECORDS] = listed.find(was)
		elif was >= 0:
			_column = Column.RECORDS
			_reset_record_columns()
		_listed = listed
	_selected[Column.RECORDS] = clampi(_selected[Column.RECORDS], 0, maxi(_entries(Column.RECORDS).size() - 1, 0))
	if _record() == null:
		_column = Column.RECORDS
	for column: Column in [Column.CHECKS, Column.FIXES]:
		var size := _entries(column).size()
		_selected[column] = clampi(_selected[column], 0, maxi(size - 1, 0))


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
	if _offline():
		_put(30, 15, " OFFLINE: LINE IN USE ", bright_color, bar_color)
		_bar(28, " CompuFunDB", "", bar_color)
		return
	var record := _record()
	for column: int in Column.size():
		_paint_column(column as Column)
	var count := "Rec %d/%d " % [_selected[Column.RECORDS] + 1, _records().size()] if record != null else "Rec None "
	var buttons := _buttons()
	for text: String in buttons:
		_put(_button_x(buttons[text], text), FRAME_ROWS[-1], text, bright_color, bar_color)
	_bar(28, " %s" % (_status if not _status.is_empty() else HEADERS[_column]), count, bar_color)
	_put(1, 29, "\u2191\u2193 Move  \u2190\u2192 Column  Space Mark  P Print  F Print fix  Esc Leave", text_color)


func _paint_column(column: Column) -> void:
	var entries := _entries(column)
	var lines := _lines(column, entries)
	var span := _spans[column]
	if column != Column.RECORDS and _record() == null:
		return
	for row: int in LIST_BOTTOM - LIST_TOP + 1:
		var line := _scroll[column] + row
		if line >= lines.size():
			break
		var index: int = lines[line][0]
		var entry := entries[index]
		var fg := text_color if entry.pick else dim_color
		var bg := background
		if column == Column.RECORDS and index == _selected[column]:
			fg = bright_color
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
