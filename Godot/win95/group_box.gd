@tool
class_name GroupBox
extends Control
## A Win95 group box: an etched frame around related controls, with a caption that breaks its top
## edge. The frame fills the node's rect and the caption sits across its top edge, so the caption
## reaches 4 px above the rect. Lay the controls out as children, at absolute positions.

static var _palette: Win95Palette = preload("res://win95/theme/palette.tres")
## From the frame's left edge to the caption's first pixel.
const _CAPTION_X := 10.0
## The gap in the top edge, before and after the caption.
const _GAP_BEFORE := 3.0
const _GAP_AFTER := 2.0
## From the frame's top edge down to the caption's baseline.
const _BASELINE := 5.0

## The caption; empty draws an unbroken frame.
@export var text := "":
	set(value):
		text = value
		queue_redraw()
## Draws the caption in the gray of disabled text.
@export var disabled := false:
	set(value):
		disabled = value
		queue_redraw()


func _ready() -> void:
	_palette.changed.connect(queue_redraw)


func _draw() -> void:
	var w := size.x
	var h := size.y
	var shadow := _palette.shadow_color
	var light := _palette.highlight_color
	draw_rect(Rect2(0, 0, w - 1, 1), shadow)
	draw_rect(Rect2(0, 0, 1, h - 1), shadow)
	draw_rect(Rect2(1, h - 2, w - 2, 1), shadow)
	draw_rect(Rect2(w - 2, 1, 1, h - 2), shadow)
	draw_rect(Rect2(1, 1, w - 3, 1), light)
	draw_rect(Rect2(1, 1, 1, h - 3), light)
	draw_rect(Rect2(0, h - 1, w, 1), light)
	draw_rect(Rect2(w - 1, 0, 1, h), light)
	if text.is_empty():
		return
	var font := get_theme_font(&"font", &"Label")
	var font_size := get_theme_font_size(&"font_size", &"Label")
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_rect(Rect2(_CAPTION_X - _GAP_BEFORE, 0, _GAP_BEFORE + width + _GAP_AFTER, 2), _palette.face_color)
	draw_string(font, Vector2(_CAPTION_X, _BASELINE), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, get_theme_color(&"font_color", &"DisabledLabel" if disabled else &"Label"))
