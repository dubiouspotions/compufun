extends "res://win95/cover_screen.gd"
## The Flying Through Space screensaver: stars on black fly out from the centre of the screen, from dim
## grey dots to bright white ones as they come closer, as if the viewer flies through a starfield.
## Any key or click ends it.

## How fast the viewer flies, as Win95's Warp speed slider (0 to 20).
@export_range(0, 20) var warp_speed: int = 10
## How many stars are on screen at once, as Win95's Starfield density (10 to 200).
@export_range(10, 200) var density: int = 50

const _FAR := 1.0
const _NEAR := 0.02
## Depth per second at warp speed 0; each step of the slider adds as much again.
const _SPEED_PER_WARP := 0.04

## Each star: Vector3(x, y, depth), x and y in -1..1 of the half-screen at depth 1.
var _stars: Array[Vector3] = []


func _ready() -> void:
	super()
	for i in density:
		_stars.append(_spawn(randf_range(_NEAR, _FAR)))


func _process(delta: float) -> void:
	var step := delta * _SPEED_PER_WARP * (warp_speed + 1)
	for i in _stars.size():
		var star := _stars[i]
		star.z -= step
		if star.z <= _NEAR or not Rect2(Vector2.ZERO, size).has_point(_project(star)):
			star = _spawn(_FAR)
		_stars[i] = star
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	for star: Vector3 in _stars:
		var near := star.z <= 0.3
		var colour := Color.WHITE if near else Color("c0c0c0") if star.z <= 0.6 else Color("808080")
		draw_rect(Rect2(_project(star).floor(), Vector2.ONE * (2.0 if near else 1.0)), colour)


func _spawn(depth: float) -> Vector3:
	return Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), depth)


func _project(star: Vector3) -> Vector2:
	var half := size * 0.5
	return half + Vector2(star.x, star.y) * half * 0.4 / star.z
