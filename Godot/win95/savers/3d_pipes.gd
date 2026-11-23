extends "res://win95/cover_screen.gd"
## The 3D Pipes screensaver: pipes in the Win95 colours grow cell by cell, turn at ball joints, and
## the screen clears once it is full. Any key or click ends it.

## The size of one cell of the pipes' grid, in pixels.
var cell: int = 24
## New pipe segments per second.
var speed: float = 12.0
## How many segments fill the screen before it clears.
var full: int = 260

const _COLOURS: Array[Color] = [Color("aa0000"), Color("00aa00"), Color("aaaa00"), Color("0000aa"),
		Color("aa00aa"), Color("00aaaa"), Color("aaaaaa")]
const _TURNS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

## Each segment: [from cell, to cell, colour, joint at the start].
var _segments: Array = []
var _head := Vector2i.ZERO
var _heading := Vector2i.RIGHT
var _colour := Color.WHITE
var _due := 0.0


func _ready() -> void:
	super()
	_new_pipe()


func _process(delta: float) -> void:
	_due += delta * speed
	while _due >= 1.0:
		_due -= 1.0
		_grow()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	var width := cell * 0.42
	for segment: Array in _segments:
		var from := _centre(segment[0])
		var to := _centre(segment[1])
		var colour: Color = segment[2]
		draw_line(from, to, colour.darkened(0.45), width)
		draw_line(from, to, colour, width * 0.6)
		draw_line(from, to, colour.lightened(0.45), width * 0.18)
		if segment[3]:
			draw_circle(from, width * 0.62, colour.darkened(0.3))
			draw_circle(from - Vector2.ONE * width * 0.15, width * 0.3, colour.lightened(0.35))


func _grid() -> Vector2i:
	return Vector2i(maxi(1, int(size.x / cell)), maxi(1, int(size.y / cell)))


func _centre(at: Vector2i) -> Vector2:
	return (Vector2(at) + Vector2.ONE * 0.5) * cell


func _new_pipe() -> void:
	var grid := _grid()
	_head = Vector2i(randi() % grid.x, randi() % grid.y)
	_heading = _TURNS[randi() % _TURNS.size()]
	_colour = _COLOURS[randi() % _COLOURS.size()]


func _grow() -> void:
	if _segments.size() >= full:
		_segments.clear()
		_new_pipe()
	var turned := randf() < 0.25
	if turned:
		_heading = _TURNS[randi() % _TURNS.size()]
	var grid := _grid()
	var next := _head + _heading
	if next.x < 0 or next.y < 0 or next.x >= grid.x or next.y >= grid.y:
		_new_pipe()
		return
	_segments.append([_head, next, _colour, turned])
	_head = next
