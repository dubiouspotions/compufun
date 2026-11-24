class_name PrintoutPaper
extends Control
## A printout drawn as a sheet of green-bar continuous paper: the printed lines in the printer's
## font, and a pencil tick over each check box that the player ticked. Its size follows the text.

## The printer's font; the page is monospaced.
@export var font: Font = preload("res://compufun_db/fonts/Px437_IBM_VGA_8x16.ttf")
## The font size in pixels; the VGA font is sharpest at multiples of 16.
@export var font_size: int = 16:
	set(value):
		font_size = value
		_relayout()
@export var paper_color: Color = Color(0.95, 0.94, 0.88)
## The colour of every other band of [member bar_lines] lines.
@export var bar_color: Color = Color(0.82, 0.92, 0.82)
@export var bar_lines: int = 3
@export var ink_color: Color = Color(0.22, 0.22, 0.28)
@export var pencil_color: Color = Color(0.42, 0.42, 0.46)
## The blank columns on each side, where the tractor holes are.
@export var margin_chars: int = 3
## The top-left corner is folded over (see [method fold_rect]).
@export var folded: bool = false
## The colour of the fold's back, and of the fold under the mouse.
@export var fold_color: Color = Color(0.84, 0.83, 0.76)
@export var fold_hover_color: Color = Color(1.0, 0.98, 0.9)

## The printed lines.
var lines: PackedStringArray = []:
	set(value):
		lines = value
		_relayout()
## True while the mouse is over the fold: it lights up.
var fold_hovered: bool = false:
	set(value):
		if value != fold_hovered:
			fold_hovered = value
			queue_redraw()
## The indices of the lines whose check box is ticked.
var ticks: Array[int] = []:
	set(value):
		ticks = value
		queue_redraw()


## The size of one character cell at [member font_size], in pixels.
func cell() -> Vector2:
	return Vector2(font.get_char_size(ord("M"), font_size).x, font.get_height(font_size))


## The paper's size at [member font_size]: the longest line and every line, with the margins.
func page_size() -> Vector2:
	var columns := 0
	for line: String in lines:
		columns = maxi(columns, line.length())
	return cell() * Vector2(columns + 2 * margin_chars, lines.size() + 2)


## The index of the line at [param at], in this control's coordinates, or -1 off the text.
func line_at(at: Vector2) -> int:
	var row := floori(at.y / cell().y) - 1
	return row if row >= 0 and row < lines.size() and at.x >= 0.0 and at.x < size.x else -1


## Where the check box of line [param line] is drawn, in this control's coordinates; empty when the
## line has none.
func box_rect(line: int) -> Rect2:
	@warning_ignore("static_called_on_instance")
	var column := Game.printout_box(lines[line]) if line >= 0 and line < lines.size() else -1
	if column < 0:
		return Rect2()
	return Rect2(cell() * Vector2(margin_chars + column, line + 1), cell() * Vector2(3, 1))


## The folded corner, in this control's coordinates: the left margin's width, square; empty unless
## [member folded].
func fold_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2.ONE * cell().x * margin_chars) if folded else Rect2()


func _relayout() -> void:
	custom_minimum_size = page_size()
	size = custom_minimum_size
	queue_redraw()


func _draw() -> void:
	var c := cell()
	var fold := fold_rect().size.x
	draw_colored_polygon(PackedVector2Array([Vector2(fold, 0.0), Vector2(size.x, 0.0), size, Vector2(0.0, size.y), Vector2(0.0, fold)]), paper_color)
	var band := c.y * bar_lines
	var y := c.y
	while y < size.y:
		draw_rect(Rect2(c.x * margin_chars * 0.75, y, size.x - c.x * margin_chars * 1.5, minf(band, size.y - y)), bar_color)
		y += band * 2.0
	var hole := c.x * 0.3
	y = c.y * 0.5
	while y < size.y:
		for x: float in [c.x * margin_chars * 0.375, size.x - c.x * margin_chars * 0.375]:
			if x + y >= fold:  # none in the folded corner
				draw_circle(Vector2(x, y), hole, bar_color.darkened(0.15))
		y += c.y
	if folded:
		var flap := PackedVector2Array([Vector2(fold, 0.0), Vector2(fold, fold), Vector2(0.0, fold)])
		draw_colored_polygon(PackedVector2Array([flap[0] + Vector2(2.0, 0.0), flap[1] + Vector2(2.0, 2.0), flap[2] + Vector2(0.0, 2.0)]), Color(0.0, 0.0, 0.0, 0.25))
		draw_colored_polygon(flap, fold_hover_color if fold_hovered else fold_color)
	var ascent := font.get_ascent(font_size)
	for i: int in lines.size():
		draw_string(font, Vector2(c.x * margin_chars, c.y * (i + 1) + ascent), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink_color)
	for line: int in ticks:
		var box := box_rect(line)
		if box.has_area():
			var tick := PackedVector2Array([box.position + box.size * Vector2(0.15, 0.5), box.position + box.size * Vector2(0.42, 0.85), box.position + box.size * Vector2(0.95, -0.15)])
			draw_polyline(tick, pencil_color, maxf(2.0, c.y / 8.0), true)
