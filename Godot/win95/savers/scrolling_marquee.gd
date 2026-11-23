extends Saver
## The Scrolling Marquee screensaver: a line of text scrolls from the right edge to the left across a
## coloured screen, then starts again. The defaults are Win95's own: "Your text goes here." in magenta
## Times New Roman (Liberation Serif here) at 24 points, on navy, centred.
## Any key, click or mouse move ends it.

## The text that scrolls.
var text: String = "Your text goes here."
var text_colour: Color = Color8(255, 0, 255)
var background: Color = Color8(0, 0, 128)
## The text's size in pixels: 24 points at Win95's 96 dots per inch.
var font_size: int = 32
## How fast the text moves to the left, in pixels per second.
var speed: float = 110.0
## True scrolls each pass at a random height; false keeps it on the screen's middle.
var random_position: bool = false

const _FONT := preload("res://win95/theme/fonts/liberation_serif_regular.ttf")

## The left end of the text, in pixels from the screen's left edge.
var _x: float = INF
## The text's baseline, in pixels from the top.
var _baseline: float = 0.0


func _process(delta: float) -> void:
	var width := _FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if _x == INF or _x + width < 0.0:
		_start_pass()
	else:
		_x -= speed * delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), background)
	if _x != INF:
		draw_string(_FONT, Vector2(roundf(_x), _baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_colour)


func _start_pass() -> void:
	_x = size.x
	var ascent := _FONT.get_ascent(font_size)
	var line := ascent + _FONT.get_descent(font_size)
	var top := randf_range(0.0, maxf(0.0, size.y - line)) if random_position else (size.y - line) * 0.5
	_baseline = roundf(top + ascent)
