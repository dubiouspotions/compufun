class_name PostItLabel
extends Control
## The post-it that the player reads in the Workview, written in sharp UI text over the 3D paper (a
## PostIt3D with text_3d off) and following it as the camera moves: the perceived issue and, once the
## computer is fixed and tested, the prompt to call the customer next to the 3D check.

## The largest font size, as a fraction of the paper's width on screen. The text shrinks below it
## when it doesn't fit, as on a paper that the camera sees at a slant.
@export_range(0.02, 0.5) var font_fraction: float = 0.1
## The largest font size in pixels, however close the paper comes.
@export_range(1, 256) var max_font_size: int = 48

## The job whose post-it this is, or null to show nothing.
var job: Job:
	set(value):
		if value == job:
			return
		job = value
		if is_node_ready():
			_sync()

@onready var _issue: Label = %Issue
@onready var _pickup: Label = %Pickup


func _ready() -> void:
	Game.changed.connect(_sync)
	_sync()


## Lays the text over [param rect]: the paper as the camera sees it, in canvas coordinates, with the
## text turned [param quarter_turns] quarter turns clockwise, as on a computer lying on its side (see
## [method Shop.post_it_quarter_turns]). Both texts get the same font size, the largest at which
## each fits its part of the paper.
func follow(rect: Rect2, quarter_turns: int = 0) -> void:
	size = (Vector2(rect.size.y, rect.size.x) if quarter_turns % 2 != 0 else rect.size).round()
	pivot_offset = size * 0.5
	position = (rect.get_center() - pivot_offset).round()
	rotation = quarter_turns * PI * 0.5
	var font_size := fitting_font_size()
	for label: Label in [_issue, _pickup]:
		label.add_theme_font_size_override(&"font_size", font_size)


## The largest font size, 1 to [member max_font_size], at which both texts fit their parts of the
## paper at the current [member Control.size]; 1 when none fits. Measures at most 8 sizes.
func fitting_font_size() -> int:
	var low := 1
	var high := clampi(roundi(size.x * font_fraction), 1, max_font_size)
	while low < high:
		var mid := (low + high + 1) / 2
		if _fits(_issue, mid) and _fits(_pickup, mid):
			low = mid
		else:
			high = mid - 1
	return low


# Measures from the anchors: the labels take the new size of this control only on the next frame.
func _fits(label: Label, font_size: int) -> bool:
	var box := Vector2(label.anchor_right - label.anchor_left, label.anchor_bottom - label.anchor_top) * size
	var font := label.get_theme_font(&"font")
	var text := font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, box.x, font_size)
	var lines := roundi(text.y / font.get_height(font_size))
	var spacing := label.get_theme_constant(&"line_spacing") * (lines - 1)
	return text.x <= box.x and text.y + spacing <= box.y


func _sync() -> void:
	_issue.text = job.problem.perceived_issue if job != null else ""
	_pickup.visible = job != null and job.done
