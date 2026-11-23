extends Saver
## Mystify Your Mind: on black, outlines whose corners bounce off the edges of the rect, each
## trailing copies of itself. Each new copy takes the colour of the moment, which fades from one
## random colour to the next, so a trail shows the fade. Any key, click or mouse move ends it.

## The outlines that move at once.
@export_range(1, 8) var shapes: int = 2
## The corners of each outline.
@export_range(2, 8) var corners: int = 4
## The copies of each outline on screen: the newest and its trail.
@export_range(1, 64) var lines: int = 7
## Moves per second; each move draws a new copy of every outline and drops its oldest.
@export var steps_per_second: float = 20.0
## The speed of a corner in pixels per move, picked from this range at each bounce.
@export var speed: Vector2 = Vector2(5.0, 12.0)
## The moves that one colour takes to fade into the next.
@export_range(1, 600) var fade_steps: int = 90


class Shape:
	var corners: PackedVector2Array = []
	var velocities: PackedVector2Array = []
	## The copies on screen, oldest first, and the colour that each was drawn in.
	var trail: Array[PackedVector2Array] = []
	var colours: PackedColorArray = []
	var from: Color
	var to: Color
	var faded: int = 0


var _shapes: Array[Shape] = []
var _due := 0.0


func _process(delta: float) -> void:
	if size.x < 1.0 or size.y < 1.0:
		return
	if _shapes.is_empty():
		for i in shapes:
			_shapes.append(_new_shape())
	_due += delta * steps_per_second
	while _due >= 1.0:
		_due -= 1.0
		for shape: Shape in _shapes:
			_step(shape)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	for shape: Shape in _shapes:
		for i: int in shape.trail.size():
			var outline := shape.trail[i].duplicate()
			outline.append(outline[0])
			draw_polyline(outline, shape.colours[i], -1.0)


func _new_shape() -> Shape:
	var shape := Shape.new()
	for i in corners:
		shape.corners.append(Vector2(randf() * size.x, randf() * size.y))
		shape.velocities.append(Vector2(_random_speed() * _random_sign(), _random_speed() * _random_sign()))
	shape.from = _random_colour()
	shape.to = _random_colour()
	return shape


func _step(shape: Shape) -> void:
	for i: int in shape.corners.size():
		var at := shape.corners[i] + shape.velocities[i]
		var velocity := shape.velocities[i]
		for axis: int in 2:
			if at[axis] < 0.0:
				at[axis] = -at[axis]
				velocity[axis] = _random_speed()
			elif at[axis] > size[axis] - 1.0:
				at[axis] = 2.0 * (size[axis] - 1.0) - at[axis]
				velocity[axis] = -_random_speed()
		shape.corners[i] = at
		shape.velocities[i] = velocity
	shape.faded += 1
	if shape.faded >= fade_steps:
		shape.faded = 0
		shape.from = shape.to
		shape.to = _random_colour()
	shape.trail.append(shape.corners.duplicate())
	shape.colours.append(shape.from.lerp(shape.to, float(shape.faded) / fade_steps))
	while shape.trail.size() > lines:
		shape.trail.pop_front()
		shape.colours.remove_at(0)


func _random_speed() -> float:
	return randf_range(speed.x, speed.y)


func _random_sign() -> float:
	return 1.0 if randf() < 0.5 else -1.0


func _random_colour() -> Color:
	return Color.from_hsv(randf(), randf_range(0.6, 1.0), 1.0)
