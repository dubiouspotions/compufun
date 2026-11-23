extends Saver
## The Flying Windows screensaver: Windows flags fly out of the middle of a black screen towards the
## viewer, growing as they come, and a new one starts far away when one leaves the screen. Any key,
## click or mouse move ends it.

## How many flags fly at once.
var density: int = 20
## How far a flag comes towards the viewer each second, in distances of the screen from the viewer.
var speed: float = 1.2
## A flag's width, as a share of the screen's height, when it is as close as the screen.
var flag_width: float = 0.12

const _FAR := 4.0  # far enough that a new flag is a dot near the middle
const _NEAR := 0.04
# The 16-colour VGA flag: red, green, blue and yellow panes, as Win95 draws it at 640x480.
const _PANES: Array[Color] = [Color("ff0000"), Color("00ff00"), Color("0000ff"), Color("ffff00")]
const _GAP := 0.06  # between the panes, as a share of the flag's width
const _SAMPLES := 6  # points along each pane's wavy top and bottom edge
const _SMALL := 12.0  # narrower flags, in pixels, are four plain squares: too few pixels for the wave

## Each flag: x and y across the view at the screen's distance (-1 to 1 spans its height), z its
## distance in those units.
var _flags: Array[Vector3] = []


func _ready() -> void:
	super()
	for i: int in density:
		_flags.append(_new_flag(randf_range(_NEAR, _FAR)))


func _process(delta: float) -> void:
	for i: int in _flags.size():
		var flag := _flags[i]
		flag.z -= speed * delta
		_flags[i] = flag if flag.z > _NEAR and _on_screen(flag) else _new_flag(_FAR)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	var by_distance := _flags.duplicate()
	by_distance.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.z > b.z)
	for flag: Vector3 in by_distance:
		_draw_flag(_project(flag), flag_width / flag.z * size.y * 0.5)


func _new_flag(z: float) -> Vector3:
	var aspect := size.x / maxf(size.y, 1.0)
	return Vector3(randf_range(-aspect, aspect), randf_range(-1.0, 1.0), z)


func _project(flag: Vector3) -> Vector2:
	return (size * 0.5 + Vector2(flag.x, flag.y) / flag.z * size.y * 0.5).round()


func _on_screen(flag: Vector3) -> bool:
	var reach := flag_width / flag.z * size.y * 0.5
	return Rect2(Vector2.ZERO, size).grow(reach).has_point(_project(flag))


# The flag waves along its width, and its right side stands taller, as in the Windows logo.
func _draw_flag(centre: Vector2, width: float) -> void:
	var height := width * 0.85
	var half := (1.0 - _GAP) * 0.5
	if width < _SMALL:
		var pane := (Vector2(width, height) * 0.5).ceil()
		for i: int in 4:
			draw_rect(Rect2(centre - pane + Vector2(i % 2, int(i >= 2)) * pane, pane), _PANES[i])
		return
	for pane: int in 4:
		var u0 := 0.0 if pane % 2 == 0 else half + _GAP
		var v0 := 0.0 if pane < 2 else half + _GAP
		var points := PackedVector2Array()
		for i: int in _SAMPLES + 1:
			points.append(_flag_point(centre, width, height, u0 + half * i / _SAMPLES, v0))
		for i: int in range(_SAMPLES, -1, -1):
			points.append(_flag_point(centre, width, height, u0 + half * i / _SAMPLES, v0 + half))
		draw_colored_polygon(points, _PANES[pane])


func _flag_point(centre: Vector2, width: float, height: float, u: float, v: float) -> Vector2:
	var tall := lerpf(0.85, 1.0, u)
	var wave := -sin(u * PI * 1.25) * 0.12 * height
	return centre + Vector2((u - 0.5) * width, (v - 0.5) * height * tall + wave)
