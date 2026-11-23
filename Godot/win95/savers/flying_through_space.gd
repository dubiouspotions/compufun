extends Saver
## The Flying Through Space screensaver: white stars on black, all over the screen, fly away from its
## centre ever faster and grow from 1 to 3 pixels as they come closer, as if the viewer flies through
## a starfield. A star that leaves the screen comes back somewhere else, far away.
## Any key, click or mouse move ends it.

## How fast the viewer flies, as Win95's Warp speed slider (0 to 20).
@export_range(0, 20) var warp_speed: int = 10
## How many stars are on screen at once, as Win95's Starfield density (10 to 200).
@export_range(10, 200) var density: int = 25

## A new star's depth is between this and 1; on screen, depth divides its distance from the centre.
const _NEAREST_NEW := 0.2
## A star closer than this starts over, so that one at the very centre doesn't stay forever.
const _NEAREST := 0.02
## The share of its depth that a star loses per second, per step of the warp speed slider plus one.
const _SPEED_PER_WARP := 0.037
## Closer than these depths, a star is 2 and then 3 pixels wide.
const _DEPTH_2PX := 0.35
const _DEPTH_3PX := 0.15

## Each star: x and y, its offset from the centre times its depth; z, its depth.
var _stars: Array[Vector3] = []


func _process(delta: float) -> void:
	if size == Vector2.ZERO:
		return
	_stars.resize(density)
	var shrink := exp(-delta * _SPEED_PER_WARP * (warp_speed + 1))
	for i in _stars.size():
		var star := _stars[i]
		star.z *= shrink
		if star.z < _NEAREST or not Rect2(Vector2.ZERO, size).has_point(_project(star)):
			star = _new_star()
		_stars[i] = star
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	for star: Vector3 in _stars:
		var side := 1.0 if star.z >= _DEPTH_2PX else 2.0 if star.z >= _DEPTH_3PX else 3.0
		draw_rect(Rect2((_project(star) - Vector2.ONE * side * 0.5).floor(), Vector2.ONE * side), Color.WHITE)


func _new_star() -> Vector3:
	var depth := randf_range(_NEAREST_NEW, 1.0)
	var offset := (Vector2(randf() * size.x, randf() * size.y) - size * 0.5) * depth
	return Vector3(offset.x, offset.y, depth)


func _project(star: Vector3) -> Vector2:
	return size * 0.5 + Vector2(star.x, star.y) / star.z
