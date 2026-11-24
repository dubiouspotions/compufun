class_name PostItLabel
extends Control
## The post-it that the player reads in the Workview, written in sharp UI text over the 3D paper (a
## PostIt3D with text_3d off) and following it as the camera moves: the perceived issue; "Needs
## testing" next to the 3D exclamation mark while the computer is fixed but not tested; then the
## prompt to call the customer next to the 3D check.

# The paper's width in pixels at which the lines break, once per text: large, so that whole font
# sizes don't move a break. Every size shows those lines, and only the font size changes.
const LAYOUT_WIDTH: float = 1000.0

## The largest font size, as a fraction of the paper's width on screen. The text shrinks below it
## when it doesn't fit, as on a paper that the camera sees at a slant.
@export_range(0.02, 0.5) var font_fraction: float = 0.095
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
@onready var _pickup_text: String = _pickup.text  # before it is broken into lines
@onready var _testing: Label = %Testing
@onready var _testing_text: String = _testing.text


func _ready() -> void:
	Game.changed.connect(_sync)
	_sync()


## Lays the text over [param rect]: the paper as the camera sees it, in canvas coordinates, with the
## text turned [param quarter_turns] quarter turns clockwise, as on a computer lying on its side (see
## [method Shop.post_it_quarter_turns]). All texts get the same font size, the largest at which
## each fits its part of the paper.
func follow(rect: Rect2, quarter_turns: int = 0) -> void:
	size = (Vector2(rect.size.y, rect.size.x) if quarter_turns % 2 != 0 else rect.size).round()
	pivot_offset = size * 0.5
	position = (rect.get_center() - pivot_offset).round()
	rotation = quarter_turns * PI * 0.5
	var font_size := fitting_font_size()
	for label: Label in _labels():
		label.add_theme_font_size_override(&"font_size", font_size)


## The largest font size, 1 to [member max_font_size], at which all texts fit their parts of the
## paper at the current [member Control.size], in their lines; 1 when none fits. Measures at most 8
## sizes.
func fitting_font_size() -> int:
	return _largest_fitting(size, false, clampi(roundi(size.x * font_fraction), 1, max_font_size))


# The largest font size, 1 to [param high], at which all texts fit a paper of [param paper] pixels,
# wrapped to their boxes ([param wrap]) or in their lines.
func _largest_fitting(paper: Vector2, wraps: bool, high: int) -> int:
	var low := 1
	while low < high:
		@warning_ignore("integer_division")
		var mid := (low + high + 1) / 2
		if _labels().all(func(label: Label) -> bool: return _fits(label, mid, paper, wraps)):
			low = mid
		else:
			high = mid - 1
	return low


# Measures from the anchors: the labels take the new size of this control only on the next frame.
func _fits(label: Label, font_size: int, paper: Vector2, wraps: bool) -> bool:
	var box := Vector2(label.anchor_right - label.anchor_left, label.anchor_bottom - label.anchor_top) * paper
	var font := label.get_theme_font(&"font")
	var text := font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, box.x if wraps else -1.0, font_size)
	var lines := roundi(text.y / font.get_height(font_size))
	var spacing := label.get_theme_constant(&"line_spacing") * (lines - 1)
	return text.x <= box.x and text.y + spacing <= box.y


# Breaks all texts into the lines that they wrap to on a square paper LAYOUT_WIDTH pixels wide, at
# the largest font size that fits it. Every size of paper shows these lines.
func _break_lines(issue: String) -> void:
	_issue.text = issue
	_pickup.text = _pickup_text
	_testing.text = _testing_text
	var paper := Vector2(LAYOUT_WIDTH, LAYOUT_WIDTH)
	var font_size := _largest_fitting(paper, true, roundi(LAYOUT_WIDTH * font_fraction))
	for label: Label in _labels():
		var paragraph := TextParagraph.new()
		paragraph.width = (label.anchor_right - label.anchor_left) * paper.x
		paragraph.add_string(label.text, label.get_theme_font(&"font"), font_size)
		var lines: PackedStringArray = []
		for i: int in paragraph.get_line_count():
			var span := paragraph.get_line_range(i)
			lines.append(label.text.substr(span.x, span.y - span.x).strip_edges())
		label.text = "\n".join(lines)


func _sync() -> void:
	_break_lines(job.perceived_issue() if job != null else "")
	_pickup.visible = job != null and job.done
	_testing.visible = job != null and job.fixed and not job.tested


func _labels() -> Array[Label]:
	return [_issue, _pickup, _testing]
