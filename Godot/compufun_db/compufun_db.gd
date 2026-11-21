class_name CompuFunDB
extends Control
## CompuFunDB on the work computer: a DOS database in text mode, 80 x 30 characters. Three columns:
## what each customer reported (one row per job on the counter: its problem's perceived issue), what
## to check (every symptom of every Problem, whatever was reported; the player marks what is wrong),
## and what to fix (the repair steps of each problem whose symptoms are all marked; the player ticks
## them off). Marking the wrong symptoms leads to the wrong fix. The marks and ticks are the job's; this screen keeps only its cursor. It
## reads every Problem file, so its text is never a second copy of the problems.
## Keys: arrows and Tab move, Space or Enter acts. The mouse clicks and scrolls.

const PROBLEMS_DIR: String = "res://problems/"
const COLUMNS: int = 80
const ROWS: int = 30
const CELL: Vector2 = Vector2(8, 16)
## The rows of the frame's lines: the top, under the headers, the bottom.
const FRAME_ROWS: Array[int] = [1, 3, 27]
## The first and last row of the lists, between the headers and the bottom frame.
const LIST_TOP: int = 4
const LIST_BOTTOM: int = 26

enum Column { REPORTED, CHECKS, FIXES }

const HEADERS: Array[String] = ["REPORTED", "CHECK", "FIX"]

## The text-mode font: one glyph per 8 x 16 cell.
@export var font: Font = preload("res://compufun_db/fonts/Px437_IBM_VGA_8x16.ttf")
@export var background: Color = Color.BLACK
@export var text_color: Color = Color(0.667, 0.667, 0.667)
@export var bright_color: Color = Color.WHITE
@export var dim_color: Color = Color(0.333, 0.333, 0.333)
## The CompuFun red of the bars, the headers and the selection.
@export var bar_color: Color = Color(0.89, 0, 0)

## The first and last x of each column's text, inside the frame.
var _spans: Array[Vector2i] = [Vector2i(1, 24), Vector2i(26, 51), Vector2i(53, 78)]
var _problems: Array[Problem] = []
## Every symptom of every problem, once each, in the order of the problems.
var _symptoms: PackedStringArray = []
var _column: Column = Column.REPORTED
var _selected: Array[int] = [0, 0, 0]
var _scroll: Array[int] = [0, 0, 0]
var _mouse_cell: Vector2i = Vector2i(-1, -1)
# The grid that _draw paints: one character, foreground and background per cell.
var _chars: PackedStringArray = []
var _fg: PackedColorArray = []
var _bg: PackedColorArray = []


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	if font == null:
		push_error("CompuFunDB: font is empty")
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
		Column.REPORTED:
			for job: Job in _jobs():
				entries.append({text = job.problem.perceived_issue, check = null, pick = true})
		Column.CHECKS:
			var job := _job()
			if job != null:
				for symptom: String in _symptoms:
					entries.append({text = symptom, check = symptom in job.marked_symptoms, pick = true})
		Column.FIXES:
			var job := _job()
			if job != null:
				for problem: Problem in _matches(job):
					_add_steps(entries, job, "Hardware", problem.hardware_steps)
					_add_steps(entries, job, "Software", problem.software_steps)
	return entries


func _add_steps(entries: Array[Dictionary], job: Job, title: String, steps: PackedStringArray) -> void:
	if steps.is_empty():
		return
	entries.append({text = "-- %s --" % title, check = null, pick = false})
	for step: String in steps:
		entries.append({text = step, check = step in job.ticked_repairs, pick = true})


# The jobs on the counter, oldest first: the rows of the reported column.
func _jobs() -> Array[Job]:
	var jobs := Game.jobs.duplicate()
	jobs.sort_custom(func(a: Job, b: Job) -> bool: return a.order < b.order)
	return jobs


# The job under the reported cursor, or null when the counter is empty.
func _job() -> Job:
	var jobs := _jobs()
	return jobs[mini(_selected[Column.REPORTED], jobs.size() - 1)] if not jobs.is_empty() else null


# The problems whose symptoms are all marked on [param job].
func _matches(job: Job) -> Array[Problem]:
	var found: Array[Problem] = []
	for problem: Problem in _problems:
		if problem.symptoms.is_empty():
			continue
		var all_marked := true
		for symptom: String in problem.symptoms:
			all_marked = all_marked and symptom in job.marked_symptoms
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
	_column = column
	_select(lines[line][0])
	_act()


func _on_key(key: InputEventKey) -> bool:
	if _offline():
		return false
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


# Acts on the entry under the cursor: a customer opens its symptoms, a symptom or a step toggles.
func _act() -> void:
	var entries := _entries(_column)
	var index := _selected[_column]
	if index >= entries.size() or not entries[index].pick:
		return
	var entry := entries[index]
	match _column:
		Column.REPORTED:
			_change_column(1)
		Column.CHECKS:
			Game.mark_symptom(_job(), entry.text, not entry.check)
		Column.FIXES:
			Game.tick_repair(_job(), entry.text, not entry.check)
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
	var column := wrapi(_column + step, 0, Column.size()) as Column
	if column != Column.REPORTED and _job() == null:
		return
	_column = column
	_move(0)


# Selects entry [param index] of the current column and scrolls it into view.
func _select(index: int) -> void:
	if _column == Column.REPORTED and index != _selected[_column]:
		for column: Column in [Column.CHECKS, Column.FIXES]:
			_selected[column] = 0
			_scroll[column] = 0
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


# Keeps the cursors on the counter as it is: a job that left takes its row and its columns along.
func _reconcile() -> void:
	var count := _jobs().size()
	if count == 0:
		_column = Column.REPORTED
	_selected[Column.REPORTED] = clampi(_selected[Column.REPORTED], 0, maxi(count - 1, 0))
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
	_reconcile()
	var date: Dictionary = Game.date
	_bar(0, " CompuFunDB 1.0", "%02d/%02d/%02d " % [date.month, date.day, date.year % 100], bar_color)
	_frame()
	for column: int in Column.size():
		_put(_spans[column].x, FRAME_ROWS[0] + 1, HEADERS[column], bright_color)
	if _offline():
		_put(30, 15, " OFFLINE: LINE IN USE ", bright_color, bar_color)
		_bar(28, " CompuFunDB", "", bar_color)
		return
	var job := _job()
	for column: int in Column.size():
		_paint_column(column as Column)
	var jobs := _jobs()
	var record := "%s  Rec %d/%d " % [job.customer.display_name, jobs.find(job) + 1, jobs.size()] if job != null else "No records "
	_bar(28, " %s" % HEADERS[_column], record, bar_color)
	if job == null:
		_put(1, 29, "No computers on the counter.", text_color)
	else:
		_put(1, 29, "\u2191\u2193 Move  \u2190\u2192 Column  Space Mark  Esc Leave", text_color)


func _paint_column(column: Column) -> void:
	var entries := _entries(column)
	var lines := _lines(column, entries)
	var span := _spans[column]
	if column != Column.REPORTED and _job() == null:
		return
	if column == Column.FIXES and entries.is_empty():
		_put(span.x, LIST_TOP, "Mark what is wrong.", dim_color)
		return
	for row: int in LIST_BOTTOM - LIST_TOP + 1:
		var line := _scroll[column] + row
		if line >= lines.size():
			break
		var index: int = lines[line][0]
		var entry := entries[index]
		var fg := text_color if entry.pick else dim_color
		var bg := background
		if column == Column.REPORTED and index == _selected[column]:
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
