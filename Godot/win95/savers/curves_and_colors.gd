extends Saver
## Curves and Colors: on black, a closed loop of Bezier curves whose control points bounce off the
## edges of the rect. Each move draws a new copy of the loop and drops the oldest, so the trail
## sweeps out a ribbon; each copy takes the colour of the moment, which runs through the hues.
## Any key, click or mouse move ends it.

## The Bezier curves that make up the loop, end to end.
@export_range(1, 6) var curves: int = 2
## The copies of the loop on screen: the newest and its trail.
@export_range(1, 100) var length: int = 24
## Moves per second; each move draws a new copy and drops the oldest.
@export var steps_per_second: float = 30.0
## The speed of a control point in pixels per move, picked from this range at each bounce.
@export var speed: Vector2 = Vector2(3.0, 8.0)
## The moves that the colour takes to run once through every hue.
@export_range(1, 3600) var hue_steps: int = 300
## Line segments drawn per Bezier curve.
@export_range(4, 64) var smoothness: int = 24

var _points: PackedVector2Array = []
var _velocities: PackedVector2Array = []
## The copies on screen as polylines, oldest first, and the colour that each was drawn in.
var _trail: Array[PackedVector2Array] = []
var _colours: PackedColorArray = []
var _hue := 0.0
var _due := 0.0


func _process(delta: float) -> void:
	if size.x < 1.0 or size.y < 1.0:
		return
	if _points.is_empty():
		_hue = randf()
		for i in curves * 3:
			_points.append(Vector2(randf() * size.x, randf() * size.y))
			_velocities.append(Vector2(_random_speed() * _random_sign(), _random_speed() * _random_sign()))
	_due += delta * steps_per_second
	while _due >= 1.0:
		_due -= 1.0
		_step()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	for i: int in _trail.size():
		draw_polyline(_trail[i], _colours[i], -1.0)


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
	_trail.append(_loop())
	_colours.append(Color.from_hsv(_hue, 1.0, 1.0))
	while _trail.size() > length:
		_trail.pop_front()
		_colours.remove_at(0)


# Every third point is where two curves meet; the two between are the curve's control points.
func _loop() -> PackedVector2Array:
	var line: PackedVector2Array = []
	var count := _points.size()
	for curve: int in curves:
		var start := _points[curve * 3]
		var end := _points[(curve * 3 + 3) % count]
		for s: int in smoothness:
			var t := float(s) / smoothness
			line.append(start.bezier_interpolate(_points[curve * 3 + 1], _points[curve * 3 + 2], end, t))
	line.append(line[0])
	return line


func _random_speed() -> float:
	return randf_range(speed.x, speed.y)


func _random_sign() -> float:
	return 1.0 if randf() < 0.5 else -1.0
