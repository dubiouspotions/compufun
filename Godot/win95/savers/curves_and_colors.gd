extends Saver
## Curves and Colors: on black, one smooth closed loop of Bezier curves whose points bounce off the
## edges of the rect, drawn as a few copies a little apart, so it looks like a ribbon of lines. The
## whole loop is one colour, which runs slowly through the hues. Any key, click or mouse move
## ends it.

## The Bezier curves that make up the loop, end to end ("Curves" in Win95's settings).
@export_range(2, 20) var curves: int = 10
## The copies of the loop on screen: the newest and those behind it ("Lines").
@export_range(1, 10) var lines: int = 2
## The moves between two copies: more spreads the copies apart ("Density", Sparse at its default).
@export_range(1, 10) var spacing: int = 3
## Moves per second.
@export var steps_per_second: float = 30.0
## The speed of a point in pixels per move, picked from this range at each bounce.
@export var speed: Vector2 = Vector2(1.0, 5.0)
## The moves that the colour takes to run once through every hue.
@export_range(1, 3600) var hue_steps: int = 510
## Line segments drawn per Bezier curve.
@export_range(4, 64) var smoothness: int = 16

# Two per curve: curve i's control points are points 2i and 2i + 1, and it starts and ends half
# way between them and their neighbours, so the loop is smooth and stays inside the points' hull.
var _points: PackedVector2Array = []
var _velocities: PackedVector2Array = []
## The loops of the last moves as polylines, oldest first; every [member spacing]th one shows.
var _history: Array[PackedVector2Array] = []
var _hue := 0.0
var _due := 0.0


func _process(delta: float) -> void:
	if size.x < 1.0 or size.y < 1.0:
		return
	if _points.is_empty():
		_hue = randf()
		for i in curves * 2:
			_points.append(_random_point())
			_velocities.append(Vector2(_random_speed() * _random_sign(), _random_speed() * _random_sign()))
	_due += delta * steps_per_second
	while _due >= 1.0:
		_due -= 1.0
		_step()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	var colour := Color.from_hsv(_hue, 1.0, 1.0)
	for i: int in range(_history.size() - 1, -1, -spacing):
		draw_polyline(_history[i], colour, -1.0)


func _step() -> void:
	for i: int in _points.size():
		var at := _points[i] + _velocities[i]
		var velocity := _velocities[i]
		for axis: int in 2:
			if at[axis] < 0.0:
				at[axis] = -at[axis]
				velocity[axis] = _random_speed()
			elif at[axis] > size[axis] - 1.0:
				at[axis] = 2.0 * (size[axis] - 1.0) - at[axis]
				velocity[axis] = -_random_speed()
		_points[i] = at
		_velocities[i] = velocity
	_hue = fposmod(_hue + 1.0 / hue_steps, 1.0)
	_history.append(_loop())
	while _history.size() > (lines - 1) * spacing + 1:
		_history.pop_front()


func _loop() -> PackedVector2Array:
	var line: PackedVector2Array = []
	var count := _points.size()
	for i: int in curves:
		var first := _points[2 * i]
		var second := _points[2 * i + 1]
		var start := (_points[(2 * i - 1 + count) % count] + first) * 0.5
		var end := (second + _points[(2 * i + 2) % count]) * 0.5
		for s: int in smoothness:
			line.append(start.bezier_interpolate(first, second, end, float(s) / smoothness))
	line.append(line[0])
	return line


func _random_point() -> Vector2:
	return Vector2(randf() * size.x, randf() * size.y)


func _random_speed() -> float:
	return randf_range(speed.x, speed.y)


func _random_sign() -> float:
	return 1.0 if randf() < 0.5 else -1.0
