extends Control
## The time of Date/Time: "9:05:03 PM" in a sunken field, with up and down buttons on its right.
## A click on the hour, minute, second or AM/PM selects that part; the buttons, or the Up and Down
## keys, step it. A step wraps within its part and leaves the others, so the date never changes.

## The player stepped a part; [param hour] (0 to 23), [param minute] and [param second] are the new time.
signal time_edited(hour: int, minute: int, second: int)

enum Segment { HOUR, MINUTE, SECOND, HALF }

## Where each part starts in the field, in pixels from its left edge: the hour ends at its entry,
## the others start there; then the two colons.
@export var part_x := PackedInt32Array([14, 22, 39, 55])
@export var colon_x := PackedInt32Array([17, 35])
## The width of the sunken field; the buttons take the rest.
@export var field_width: int = 77

## The part that the buttons step; the field highlights it while it has focus.
var segment := Segment.HOUR

var _hour: int = 0
var _minute: int = 0
var _second: int = 0

@onready var _up: Button = $Up
@onready var _down: Button = $Down


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	_up.pressed.connect(step.bind(1))
	_down.pressed.connect(step.bind(-1))
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	_on_theme_changed()
	theme_changed.connect(_on_theme_changed)


## Shows [param hour] (0 to 23), [param minute] and [param second].
func show_time(hour: int, minute: int, second: int) -> void:
	if [hour, minute, second] == [_hour, _minute, _second]:
		return
	_hour = hour
	_minute = minute
	_second = second
	queue_redraw()


## Moves the selected part [param by] steps, wrapping within it, and emits time_edited.
func step(by: int) -> void:
	match segment:
		Segment.HOUR:
			_hour = posmod(_hour + by, 24)
		Segment.MINUTE:
			_minute = posmod(_minute + by, 60)
		Segment.SECOND:
			_second = posmod(_second + by, 60)
		Segment.HALF:
			_hour = (_hour + 12) % 24
	queue_redraw()
	time_edited.emit(_hour, _minute, _second)


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT and button.position.x < field_width:
		accept_event()
		grab_focus()
		segment = Segment.HOUR
		for later: Segment in [Segment.MINUTE, Segment.SECOND, Segment.HALF]:
			if button.position.x >= part_x[later] - 2:
				segment = later
		queue_redraw()
	elif event.is_action_pressed(&"ui_up", true):
		accept_event()
		step(1)
	elif event.is_action_pressed(&"ui_down", true):
		accept_event()
		step(-1)


func _draw() -> void:
	draw_style_box(get_theme_stylebox("normal", &"LineEdit"), Rect2(0, 0, field_width, size.y))
	var font := get_theme_font("font", &"Label")
	var font_size := get_theme_font_size("font_size", &"Label")
	var texts := ["%d" % ((_hour + 11) % 12 + 1), "%02d" % _minute, "%02d" % _second, "PM" if _hour >= 12 else "AM"]
	# Capitals are 9 px tall, from 1 px below the font's top: centre them on the field.
	var baseline := floorf(size.y / 2.0) - 5.0 + font.get_ascent(font_size)
	var ink := get_theme_color("font_color", &"Label")
	for i in texts.size():
		var width := font.get_string_size(texts[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var x := part_x[i] - width if i == Segment.HOUR else float(part_x[i])
		var color := ink
		if i == segment and has_focus():
			draw_rect(Rect2(x - 1.0, baseline - font.get_ascent(font_size) + 1.0, width + 2.0, 11.0), (get_theme_stylebox("normal", &"IconLabelSelected") as StyleBoxFlat).bg_color)
			color = get_theme_color("font_color", &"IconLabelSelected")
		draw_string(font, Vector2(x, baseline), texts[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	for x in colon_x:
		draw_string(font, Vector2(x, baseline), ":", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)


# The buttons wear SpinBox's arrows, so they match the year's spin box.
func _on_theme_changed() -> void:
	_up.icon = get_theme_icon("up", &"SpinBox")
	_down.icon = get_theme_icon("down", &"SpinBox")
