class_name CompufunDB
extends Control
## CompufunDB on the work computer: a DOS database in text mode, 80 x 30 characters. Three columns:
## the customers that the player creates, the symptoms of every Problem (the player marks the ones
## that match), and the repair steps of each problem whose symptoms are all marked (the player ticks
## them off). It reads every Problem file, so its text is never a second copy of the problems.
## Keys: arrows and Tab move, Space or Enter acts. The mouse clicks and scrolls.

const PROBLEMS_DIR: String = "res://problems/"
const COLUMNS: int = 80
const ROWS: int = 30
const CELL: Vector2 = Vector2(8, 16)
## The first and last row of the lists, between the headers and the bottom frame.
const LIST_TOP: int = 4
const LIST_BOTTOM: int = 26
const NAME_LENGTH: int = 16
const NEW_CUSTOMER: String = "<New customer>"

enum Column { CUSTOMERS, SYMPTOMS, REPAIRS }

## The text-mode font: one glyph per 8 x 16 cell.
@export var font: Font = preload("res://compufun_db/fonts/Px437_IBM_VGA_8x16.ttf")
@export var background: Color = Color.BLACK
@export var text_color: Color = Color(0.667, 0.667, 0.667)
@export var bright_color: Color = Color.WHITE
@export var dim_color: Color = Color(0.333, 0.333, 0.333)
## The CompuFun red of the bars, the headers and the selection.
@export var bar_color: Color = Color(0.89, 0, 0)

## The first and last x of each column's text, inside the frame.
var _spans: Array[Vector2i] = [Vector2i(1, 16), Vector2i(18, 47), Vector2i(49, 78)]
var _problems: Array[Problem] = []
var _symptoms: PackedStringArray = []
var _records: Array[Record] = []
var _record: Record
var _column: Column = Column.CUSTOMERS
var _selected: Array[int] = [0, 0, 0]
var _scroll: Array[int] = [0, 0, 0]
var _naming: bool = false
var _name: String = ""
var _mouse_cell: Vector2i = Vector2i(-1, -1)
# The grid that _draw paints: one character, foreground and background per cell.
var _chars: PackedStringArray = []
var _fg: PackedColorArray = []
var _bg: PackedColorArray = []


## One customer that the player made in the database, and what they marked and ticked for it.
class Record:
	var name: String
	## The marked symptoms: symptom text to true.
	var marked: Dictionary[String, bool] = {}
	## The ticked repair steps: step text to true.
	var done: Dictionary[String, bool] = {}


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	if font == null:
		push_error("CompufunDB: font is empty")
	_load_problems()
	mouse_exited.connect(_on_mouse_exited)
	Game.changed.connect(queue_redraw)
	grab_focus.call_deferred()


func _on_mouse_exited() -> void:
	_mouse_cell = Vector2i(-1, -1)
	queue_redraw()


func _load_problems() -> void:
	for file: String in ResourceLoader.list_directory(PROBLEMS_DIR):
		if not file.ends_with(".tres"):
			continue
		var problem := load(PROBLEMS_DIR + file) as Problem
		if problem == null:
			push_error("CompufunDB: %s%s is not a Problem" % [PROBLEMS_DIR, file])
			continue
		_problems.append(problem)
		for symptom: String in problem.symptoms:
			if symptom not in _symptoms:
				_symptoms.append(symptom)
	if _problems.is_empty():
		push_error("CompufunDB: no Problem files in %s" % PROBLEMS_DIR)


# An entry of a column: its text, its check box (null: none) and whether the player can pick it.
func _entries(column: Column) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	match column:
		Column.CUSTOMERS:
			for record: Record in _records:
				entries.append({text = record.name, check = null, pick = true})
			entries.append({text = NEW_CUSTOMER, check = null, pick = true})
		Column.SYMPTOMS:
			if _record != null:
				for symptom: String in _symptoms:
					entries.append({text = symptom, check = _record.marked.has(symptom), pick = true})
		Column.REPAIRS:
			if _record != null:
				for problem: Problem in _matches():
					_add_steps(entries, "Hardware", problem.hardware_steps)
					_add_steps(entries, "Software", problem.software_steps)
	return entries


func _add_steps(entries: Array[Dictionary], title: String, steps: PackedStringArray) -> void:
	if steps.is_empty():
		return
	entries.append({text = "-- %s --" % title, check = null, pick = false})
	for step: String in steps:
		entries.append({text = step, check = _record.done.has(step), pick = true})


# The problems whose symptoms are all marked on the selected customer.
func _matches() -> Array[Problem]:
	var found: Array[Problem] = []
	for problem: Problem in _problems:
		if problem.symptoms.is_empty():
			continue
		var all_marked := true
		for symptom: String in problem.symptoms:
			all_marked = all_marked and _record.marked.has(symptom)
		if all_marked:
			found.append(problem)
	return found


# The screen lines of a column: [entry index, text], with the entries wrapped to the column's width.
func _lines(column: Column, entries: Array[Dictionary]) -> Array[Array]:
	var width := _spans[column].y - _spans[column].x + 1
	var lines: Array[Array] = []
	for i: int in entries.size():
		var entry := entries[i]
		var prefix := "" if entry.check == null else ("[X] " if entry.check else "[ ] ")
		var wrapped := _wrap(entry.text, width - prefix.length())
		for j: int in wrapped.size():
			lines.append([i, (prefix if j == 0 else " ".repeat(prefix.length())) + wrapped[j]])
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
	var key := event as InputEventKey
	if key != null and key.pressed and _on_key(key):
		accept_event()


func _on_click(button: InputEventMouseButton) -> void:
	grab_focus()
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
	if button.button_index != MOUSE_BUTTON_LEFT or cell.y < LIST_TOP or cell.y > LIST_BOTTOM:
		return
	var lines := _lines(column, _entries(column))
	var line := _scroll[column] + cell.y - LIST_TOP
	if line >= lines.size():
		return
	_naming = false
	_column = column
	_select(lines[line][0])
	_act()


func _on_key(key: InputEventKey) -> bool:
	if _offline():
		return false
	if _naming:
		return _on_name_key(key)
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
		_:
			return false
	return true


func _on_name_key(key: InputEventKey) -> bool:
	match key.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			if not _name.strip_edges().is_empty():
				var record := Record.new()
				record.name = _name.strip_edges()
				_records.append(record)
				_record = record
				_selected[Column.SYMPTOMS] = 0
				_scroll[Column.SYMPTOMS] = 0
				_naming = false
		KEY_ESCAPE:
			_naming = false
		KEY_BACKSPACE:
			_name = _name.left(-1)
		_:
			var typed := char(key.unicode) if key.unicode >= 32 and key.unicode < 127 else ""
			if typed.is_empty():
				return true  # the name line keeps every key, so typing never turns the room
			if _name.length() < NAME_LENGTH:
				_name += typed
	queue_redraw()
	return true


# Picks the entry under the cursor: makes or selects a customer, marks a symptom, ticks a step.
func _act() -> void:
	var entries := _entries(_column)
	var index := _selected[_column]
	if index >= entries.size() or not entries[index].pick:
		return
	match _column:
		Column.CUSTOMERS:
			if index == _records.size():
				_naming = true
				_name = ""
			else:
				_record = _records[index]
				_selected[Column.SYMPTOMS] = 0
				_scroll[Column.SYMPTOMS] = 0
		Column.SYMPTOMS:
			_toggle(_record.marked, entries[index].text)
		Column.REPAIRS:
			_toggle(_record.done, entries[index].text)
	queue_redraw()


func _toggle(flags: Dictionary[String, bool], key: String) -> void:
	if flags.has(key):
		flags.erase(key)
	else:
		flags[key] = true


func _move(step: int) -> void:
	var entries := _entries(_column)
	var index := _selected[_column] + step
	while index >= 0 and index < entries.size() and not entries[index].pick:
		index += step
	if index >= 0 and index < entries.size():
		_select(index)
	queue_redraw()


func _change_column(step: int) -> void:
	var column := wrapi(_column + step, 0, Column.size()) as Column
	if column != Column.CUSTOMERS and _record == null:
		return
	_column = column
	_move(0)


# Selects entry [param index] of the current column and scrolls it into view.
func _select(index: int) -> void:
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
	var date: Dictionary = Game.date
	_bar(0, " CompufunDB 1.0", "%02d/%02d/%02d " % [date.month, date.day, date.year % 100], bar_color)
	_frame()
	_put(_spans[0].x, 2, "CUSTOMER", bright_color)
	_put(_spans[1].x, 2, "SYMPTOMS", bright_color)
	_put(_spans[2].x, 2, "REPAIRS", bright_color)
	if _offline():
		_put(30, 14, " OFFLINE: LINE IN USE ", bright_color, bar_color)
		_bar(28, " CompufunDB", "", bar_color)
		return
	for column: int in Column.size():
		_paint_column(column as Column)
	var status := " %s" % Column.find_key(_column)
	var record := "Rec %d/%d " % [_records.find(_record) + 1, _records.size()] if _record != null else "No customer "
	_bar(28, status, record, bar_color)
	if _naming:
		_put(1, 29, "Customer name: %s_" % _name, bright_color)
	elif _record == null:
		_put(1, 29, "Create a customer: Enter on " + NEW_CUSTOMER, text_color)
	else:
		_put(1, 29, "↑↓ Move  ←→ Column  Space Mark  Esc Leave", text_color)


func _paint_column(column: Column) -> void:
	var entries := _entries(column)
	var lines := _lines(column, entries)
	var span := _spans[column]
	if column != Column.CUSTOMERS and _record == null:
		return
	if column == Column.REPAIRS and entries.is_empty():
		_put(span.x, LIST_TOP, "Mark the symptoms", dim_color)
		_put(span.x, LIST_TOP + 1, "that match.", dim_color)
		return
	for row: int in LIST_BOTTOM - LIST_TOP + 1:
		var line := _scroll[column] + row
		if line >= lines.size():
			break
		var index: int = lines[line][0]
		var entry := entries[index]
		var fg := text_color if entry.pick else dim_color
		var bg := background
		if column == Column.CUSTOMERS and index < _records.size() and _records[index] == _record:
			fg = bright_color
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
	for y: int in range(1, 28):
		for x: int in seps:
			_put(x, y, "║", text_color)
	for y: int in [1, 3, 27]:
		_put(1, y, "═".repeat(COLUMNS - 2), text_color)
		for x: int in seps:
			var left := x == 0
			var right := x == COLUMNS - 1
			var glyph: String
			match y:
				1: glyph = "╔" if left else ("╗" if right else "╦")
				3: glyph = "╠" if left else ("╣" if right else "╬")
				_: glyph = "╚" if left else ("╝" if right else "╩")
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
