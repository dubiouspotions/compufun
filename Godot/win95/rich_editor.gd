class_name RichEditor
extends Control
## The page of Word and WordPad: edits a RichDocument with the keyboard and the mouse, in Times New
## Roman (Liberation Serif) at Windows' 96 dpi. Ctrl+B, Ctrl+I and Ctrl+U toggle bold, italic and
## underline, Ctrl+L, Ctrl+E, Ctrl+R and Ctrl+J align, Ctrl+Z and Ctrl+Y undo and redo, Ctrl+X, Ctrl+C
## and Ctrl+V use the clipboard as plain text. With [member spell_check] on, misspelt words get Word's
## red squiggle. Put it in a ScrollContainer: it grows as tall as its text and keeps the caret in view.

## The document changed: typing, a deletion, a format or an undo.
signal changed
## The caret moved or the selection changed; the toolbar reads [method selection_has] and friends.
signal caret_moved

const _FONTS: Array[FontFile] = [
	preload("res://win95/theme/fonts/liberation_serif_regular.ttf"), preload("res://win95/theme/fonts/liberation_serif_bold.ttf"),
	preload("res://win95/theme/fonts/liberation_serif_italic.ttf"), preload("res://win95/theme/fonts/liberation_serif_bold_italic.ttf"),
]
const _TAB_STOP := 48.0  # Word's default tab stops: every half inch
const _UNDO_STEPS := 100
const _BLINK_SECONDS := 0.5

## The width that the text wraps at, in pixels (Word's 6 inch line is 576); 0 wraps at the control's
## width, as WordPad's "Wrap to window" does.
@export var line_width: float = 0.0
## The blank space left of the text and above it, in pixels.
@export var margin: Vector2 = Vector2(4, 2)
## Red squiggles under the words that Spelling doesn't know.
@export var spell_check: bool = false

## The document being edited. Set it with [method set_document].
var document := RichDocument.new()
## The caret, as a position in [member document].
var caret := Vector2i.ZERO
## The other end of the selection; equal to [member caret] when nothing is selected.
var anchor := Vector2i.ZERO

## One laid-out line: where its characters stand.
class Line:
	var row: int
	var start: int
	var stop: int  # the first column after the line, its trailing spaces included
	var y: float
	var height: float
	var ascent: float
	var xs: PackedFloat32Array = []  # the left edge of each character, and the end

var _lines: Array[Line] = []
var _typing_format := -1  # the format for the next typed character; -1 takes the caret's
var _undo: Array[Array] = []
var _redo: Array[Array] = []
var _typing := false  # the last edit was typing, so the next character joins its undo step
var _goal_x := -1.0  # the x that up and down keep to
var _blink := 0.0
var _caret_on := true
var _dragging := false
var _misspelt: Dictionary[int, Array] = {}  # the misspelt ranges of each paragraph


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_IBEAM
	clip_contents = true
	resized.connect(_relayout)
	_relayout()


## Replaces the document, puts the caret at its start and forgets the undo steps.
func set_document(new_document: RichDocument) -> void:
	document = new_document
	caret = Vector2i.ZERO
	anchor = caret
	_undo.clear()
	_redo.clear()
	_typing_format = -1
	_relayout()
	caret_moved.emit()


## True while text is selected.
func has_selection() -> bool:
	return caret != anchor


## The format that typing would use now: the typing format after a toolbar change, else the format at
## the caret.
func current_format() -> int:
	return _typing_format if _typing_format >= 0 else document.format_at(RichDocument.mini_pos(caret, anchor) if has_selection() else caret)


## True when the selection, or the typing format, has every bit of [param mask].
func selection_has(mask: int) -> bool:
	if has_selection():
		return document.all_have(caret, anchor, mask)
	return current_format() & mask == mask


## The alignment of the caret's paragraph.
func current_align() -> RichDocument.Align:
	return document.paragraphs[caret.x].align


## Turns [param mask]'s bits on for the selection, or off when it has them all; with no selection,
## for what is typed next.
func toggle(mask: int) -> void:
	var on := not selection_has(mask)
	if has_selection():
		_snapshot()
		document.set_bits(caret, anchor, mask, on)
		_changed()
	else:
		_typing_format = (current_format() | mask) if on else (current_format() & ~mask)
		caret_moved.emit()


## Sets the font size of the selection, or of what is typed next, to [param points].
func set_font_size(points: float) -> void:
	var half := roundi(points * 2.0)
	if has_selection():
		_snapshot()
		document.set_size(caret, anchor, half)
		_changed()
	else:
		_typing_format = RichDocument.with_size(current_format(), half)
		caret_moved.emit()


## Aligns the paragraphs that the selection touches.
func set_align(align: RichDocument.Align) -> void:
	_snapshot()
	document.set_align(caret, anchor, align)
	_changed()


## Types [param text] at the caret, over the selection.
func type_text(text: String) -> void:
	if not _typing or has_selection():
		_snapshot()
	var format := current_format()
	if has_selection():
		caret = document.delete(caret, anchor)
	caret = document.insert(caret, text, format)
	anchor = caret
	_typing = true
	_typing_format = -1
	_changed()


## Undoes the last edit.
func undo() -> void:
	if _undo.is_empty():
		return
	_redo.append([document, caret, anchor])
	_restore(_undo.pop_back())


## Redoes the last undone edit.
func redo() -> void:
	if _redo.is_empty():
		return
	_undo.append([document, caret, anchor])
	_restore(_redo.pop_back())


## Selects the whole document.
func select_all() -> void:
	anchor = Vector2i.ZERO
	caret = document.end()
	_moved()


## Copies the selection to the clipboard as plain text.
func copy() -> void:
	if has_selection():
		DisplayServer.clipboard_set(document.text_between(caret, anchor))


## Copies the selection and deletes it.
func cut() -> void:
	if has_selection():
		copy()
		_erase_selection()


## Types the clipboard's text at the caret.
func paste() -> void:
	var text := DisplayServer.clipboard_get().replace("\r\n", "\n")
	if text != "":
		_typing = false
		type_text(text)


## The top of the caret's line, in pixels from the top of the text.
func caret_top() -> float:
	return _caret_rect().position.y - margin.y


## The line and column of the caret, from 1, as Word's status bar shows them.
func caret_line_and_column() -> Vector2i:
	var line := _line_index(caret)
	return Vector2i(line + 1, caret.y - _lines[line].start + 1) if line >= 0 else Vector2i.ONE


func _snapshot() -> void:
	_undo.append([document.copy(), caret, anchor])
	if _undo.size() > _UNDO_STEPS:
		_undo.pop_front()
	_redo.clear()
	_typing = false


func _restore(state: Array) -> void:
	document = state[0]
	caret = state[1]
	anchor = state[2]
	_typing = false
	_changed()


func _changed() -> void:
	_relayout()
	_moved()
	changed.emit()


func _moved() -> void:
	_blink = 0.0
	_caret_on = true
	_reveal_caret()
	queue_redraw()
	caret_moved.emit()


func _erase_selection() -> void:
	_snapshot()
	caret = document.delete(caret, anchor)
	anchor = caret
	_changed()


# --- Layout -----------------------------------------------------------------------------------

static func font_of(format: int) -> FontFile:
	return _FONTS[(1 if format & RichDocument.BOLD else 0) + (2 if format & RichDocument.ITALIC else 0)]


## The pixel size of [param format]'s font at 96 dpi.
static func pixels_of(format: int) -> int:
	return maxi(roundi(RichDocument.half_points(format) * 96.0 / 144.0), 1)


func _wrap_width() -> float:
	return line_width if line_width > 0.0 else maxf(size.x - margin.x * 2.0, 16.0)


func _relayout() -> void:
	_lines.clear()
	_misspelt.clear()
	var width := _wrap_width()
	var y := margin.y
	for row: int in document.paragraphs.size():
		var paragraph := document.paragraphs[row]
		if spell_check:
			_misspelt[row] = Spelling.misspelt(paragraph.text)
		var advances := PackedFloat32Array()
		var x := 0.0
		for column: int in paragraph.text.length():
			var advance := _advance(paragraph.text[column], paragraph.formats[column], x)
			advances.append(advance)
			x += advance
		var start := 0
		while true:
			var line := Line.new()
			line.row = row
			line.start = start
			var stop := start
			var used := 0.0
			var last_break := -1
			while stop < paragraph.text.length():
				var advance := advances[stop]
				if paragraph.text[stop] == "\t":
					advance = (floorf(used / _TAB_STOP) + 1.0) * _TAB_STOP - used
				if used + advance > width and stop > start and paragraph.text[stop] != " ":
					break
				if paragraph.text[stop] == " ":
					last_break = stop + 1
				used += advance
				stop += 1
			if stop < paragraph.text.length() and last_break > start:
				stop = last_break
			line.stop = stop
			_measure(line, paragraph, advances)
			line.y = y
			y += line.height
			_lines.append(line)
			start = stop
			if start >= paragraph.text.length():
				break
	custom_minimum_size.y = y + margin.y
	queue_redraw()


func _advance(c: String, format: int, _x: float) -> float:
	if c == "\t":
		return _TAB_STOP
	return font_of(format).get_char_size(c.unicode_at(0), pixels_of(format)).x


# The heights and the x of every character of [param line], aligned in the wrap width.
func _measure(line: Line, paragraph: RichDocument.Paragraph, advances: PackedFloat32Array) -> void:
	var formats := paragraph.formats.slice(line.start, line.stop) if line.stop > line.start else PackedInt32Array([paragraph.end_format])
	for format: int in formats:
		var font := font_of(format)
		line.height = maxf(line.height, font.get_height(pixels_of(format)))
		line.ascent = maxf(line.ascent, font.get_ascent(pixels_of(format)))
	var x := 0.0
	var visible_end := 0.0
	line.xs.append(0.0)
	for column: int in range(line.start, line.stop):
		var advance := advances[column]
		if paragraph.text[column] == "\t":
			advance = (floorf(x / _TAB_STOP) + 1.0) * _TAB_STOP - x
		x += advance
		line.xs.append(x)
		if paragraph.text[column] != " ":
			visible_end = x
	var spare := _wrap_width() - visible_end
	var shift := 0.0
	match paragraph.align:
		RichDocument.Align.CENTER:
			shift = floorf(spare / 2.0)
		RichDocument.Align.RIGHT:
			shift = spare
		RichDocument.Align.JUSTIFY:
			if line.stop < paragraph.text.length():
				_justify(line, paragraph, spare)
	for i: int in line.xs.size():
		line.xs[i] += margin.x + shift


# Spreads [param spare] pixels over the spaces inside [param line].
func _justify(line: Line, paragraph: RichDocument.Paragraph, spare: float) -> void:
	var last := line.stop
	while last > line.start and paragraph.text[last - 1] == " ":
		last -= 1
	var spaces := 0
	for column: int in range(line.start, last):
		if paragraph.text[column] == " ":
			spaces += 1
	if spaces == 0:
		return
	var added := 0.0
	for column: int in range(line.start, line.stop):
		if column < last and paragraph.text[column] == " ":
			added += spare / spaces
		line.xs[column - line.start + 1] += added


func _line_index(at: Vector2i) -> int:
	for i: int in _lines.size():
		var line := _lines[i]
		if line.row == at.x and at.y >= line.start and (at.y < line.stop or (at.y == line.stop and (i + 1 >= _lines.size() or _lines[i + 1].row != at.x))):
			return i
	return _lines.size() - 1


func _caret_rect() -> Rect2:
	var index := _line_index(caret)
	if index < 0:
		return Rect2(margin, Vector2(1, 16))
	var line := _lines[index]
	return Rect2(line.xs[caret.y - line.start], line.y, 1, line.height)


func _reveal_caret() -> void:
	var scroll := get_parent() as ScrollContainer
	if scroll == null:
		return
	var rect := _caret_rect()
	if rect.position.y < scroll.scroll_vertical:
		scroll.scroll_vertical = int(rect.position.y)
	elif rect.end.y > scroll.scroll_vertical + scroll.size.y:
		scroll.scroll_vertical = int(rect.end.y - scroll.size.y) + 1


func _position_at(point: Vector2) -> Vector2i:
	if _lines.is_empty():
		return Vector2i.ZERO
	var line := _lines[-1]
	for candidate: Line in _lines:
		if point.y < candidate.y + candidate.height:
			line = candidate
			break
	var best := line.start
	var best_distance := INF
	var last := line.stop
	var paragraph := document.paragraphs[line.row]
	if last > line.start and last < paragraph.text.length():
		last -= 1  # the space that ends a wrapped line belongs before the break
	for column: int in range(line.start, last + 1):
		var distance := absf(line.xs[column - line.start] - point.x)
		if distance < best_distance:
			best_distance = distance
			best = column
	return Vector2i(line.row, best)


# --- Drawing ----------------------------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)
	var from := RichDocument.mini_pos(caret, anchor)
	var to := RichDocument.maxi_pos(caret, anchor)
	for line: Line in _lines:
		var paragraph := document.paragraphs[line.row]
		var baseline := line.y + line.ascent
		for column: int in range(line.start, line.stop):
			var x := line.xs[column - line.start]
			var next := line.xs[column - line.start + 1]
			var format := paragraph.formats[column]
			var selected := _between(Vector2i(line.row, column), from, to)
			if selected:
				draw_rect(Rect2(x, line.y, next - x, line.height), Color.BLACK)
			var color := Color.WHITE if selected else Color.BLACK
			var c := paragraph.text[column]
			if c != "\t" and c != " ":
				draw_char(font_of(format), Vector2(x, baseline), c, pixels_of(format), color)
			if format & RichDocument.UNDERLINE:
				draw_line(Vector2(x, baseline + 1.5), Vector2(next, baseline + 1.5), color, 1.0)
		if spell_check:
			for word: Vector2i in _misspelt.get(line.row, []):
				var start := maxi(word.x, line.start)
				var stop := mini(word.y, line.stop)
				var typing_here := line.row == caret.x and caret.y == word.y and not has_selection()
				if stop > start and not typing_here:
					_squiggle(line.xs[start - line.start], line.xs[stop - line.start], baseline + 2.0)
		if has_selection() and _between(Vector2i(line.row, line.stop), from, to) and line.stop == paragraph.text.length() and line.row < to.x:
			draw_rect(Rect2(line.xs[-1], line.y, 4, line.height), Color.BLACK)  # the selected paragraph mark
	if has_focus() and _caret_on and not has_selection():
		draw_rect(_caret_rect(), Color.BLACK)


func _squiggle(from_x: float, to_x: float, y: float) -> void:
	var points := PackedVector2Array()
	var x := from_x
	var up := true
	while x <= to_x:
		points.append(Vector2(x, y + (0.0 if up else 2.0)))
		x += 2.0
		up = not up
	if points.size() > 1:
		draw_polyline(points, Color(1, 0, 0), 1.0)


static func _between(at: Vector2i, from: Vector2i, to: Vector2i) -> bool:
	return RichDocument.mini_pos(from, at) == from and RichDocument.mini_pos(at, to) == at and at != to


func _process(delta: float) -> void:
	if not has_focus():
		return
	_blink += delta
	if _blink >= _BLINK_SECONDS:
		_blink = 0.0
		_caret_on = not _caret_on
		queue_redraw()


# --- Input ------------------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			grab_focus()
			caret = _position_at(button.position)
			if not button.shift_pressed:
				anchor = caret
			if button.double_click:
				_select_word()
			_dragging = true
			_typing = false
			_goal_x = -1.0
			_typing_format = -1
			_moved()
		else:
			_dragging = false
		accept_event()
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _dragging:
		caret = _position_at(motion.position)
		_moved()
		accept_event()
		return
	var key := event as InputEventKey
	if key != null and key.pressed:
		if _on_key(key):
			accept_event()


func _on_key(key: InputEventKey) -> bool:
	var ctrl := key.ctrl_pressed or key.meta_pressed
	var shift := key.shift_pressed
	if ctrl:
		match key.keycode:
			KEY_A: select_all()
			KEY_B: toggle(RichDocument.BOLD)
			KEY_I: toggle(RichDocument.ITALIC)
			KEY_U: toggle(RichDocument.UNDERLINE)
			KEY_L: set_align(RichDocument.Align.LEFT)
			KEY_E: set_align(RichDocument.Align.CENTER)
			KEY_R: set_align(RichDocument.Align.RIGHT)
			KEY_J: set_align(RichDocument.Align.JUSTIFY)
			KEY_Z: undo()
			KEY_Y: redo()
			KEY_C: copy()
			KEY_X: cut()
			KEY_V: paste()
			KEY_HOME: _move_to(Vector2i.ZERO, shift)
			KEY_END: _move_to(document.end(), shift)
			KEY_LEFT: _move_to(_word_left(), shift)
			KEY_RIGHT: _move_to(_word_right(), shift)
			_: return false
		return true
	match key.keycode:
		KEY_LEFT: _move_to(_step(-1) if shift or not has_selection() else RichDocument.mini_pos(caret, anchor), shift)
		KEY_RIGHT: _move_to(_step(1) if shift or not has_selection() else RichDocument.maxi_pos(caret, anchor), shift)
		KEY_UP: _move_line(-1, shift)
		KEY_DOWN: _move_line(1, shift)
		KEY_HOME: _move_to(Vector2i(caret.x, _lines[_line_index(caret)].start), shift)
		KEY_END: _move_to(_line_end(), shift)
		KEY_BACKSPACE:
			if has_selection():
				_erase_selection()
			elif caret != Vector2i.ZERO:
				_erase_to(_step(-1))
		KEY_DELETE:
			if has_selection():
				_erase_selection()
			elif caret != document.end():
				_erase_to(_step(1))
		KEY_ENTER, KEY_KP_ENTER:
			_typing = false
			type_text("\n")
		KEY_TAB:
			type_text("\t")
		_:
			if key.unicode >= 32:
				type_text(String.chr(key.unicode))
			else:
				return false
	return true


func _erase_to(other: Vector2i) -> void:
	if not _typing:
		_snapshot()
	caret = document.delete(caret, other)
	anchor = caret
	_typing = true
	_changed()


func _move_to(to: Vector2i, extend: bool) -> void:
	caret = document.clamp_pos(to)
	if not extend:
		anchor = caret
	_typing = false
	_typing_format = -1
	_goal_x = -1.0
	_moved()


func _step(direction: int) -> Vector2i:
	var at := caret
	if direction < 0:
		if at.y > 0:
			return Vector2i(at.x, at.y - 1)
		return Vector2i(at.x - 1, document.paragraphs[at.x - 1].text.length()) if at.x > 0 else at
	if at.y < document.paragraphs[at.x].text.length():
		return Vector2i(at.x, at.y + 1)
	return Vector2i(at.x + 1, 0) if at.x + 1 < document.paragraphs.size() else at


func _move_line(direction: int, extend: bool) -> void:
	var index := _line_index(caret)
	var rect := _caret_rect()
	if _goal_x < 0.0:
		_goal_x = rect.position.x
	var target := clampi(index + direction, 0, _lines.size() - 1)
	var goal := _goal_x
	var to := _position_at(Vector2(goal, _lines[target].y + 1.0))
	caret = to
	if not extend:
		anchor = caret
	_typing = false
	_typing_format = -1
	_moved()
	_goal_x = goal


func _line_end() -> Vector2i:
	var line := _lines[_line_index(caret)]
	var paragraph := document.paragraphs[line.row]
	var stop := line.stop
	if stop < paragraph.text.length() and stop > line.start:
		stop -= 1
	return Vector2i(line.row, stop)


func _word_left() -> Vector2i:
	var text := document.paragraphs[caret.x].text
	var column := caret.y
	if column == 0:
		return _step(-1)
	while column > 0 and text[column - 1] == " ":
		column -= 1
	while column > 0 and text[column - 1] != " ":
		column -= 1
	return Vector2i(caret.x, column)


func _word_right() -> Vector2i:
	var text := document.paragraphs[caret.x].text
	var column := caret.y
	if column == text.length():
		return _step(1)
	while column < text.length() and text[column] != " ":
		column += 1
	while column < text.length() and text[column] == " ":
		column += 1
	return Vector2i(caret.x, column)


func _select_word() -> void:
	var text := document.paragraphs[caret.x].text
	var start := caret.y
	var stop := caret.y
	while start > 0 and text[start - 1] != " ":
		start -= 1
	while stop < text.length() and text[stop] != " ":
		stop += 1
	while stop < text.length() and text[stop] == " ":
		stop += 1
	anchor = Vector2i(caret.x, start)
	caret = Vector2i(caret.x, stop)
