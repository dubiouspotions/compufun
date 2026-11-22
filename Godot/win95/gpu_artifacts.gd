extends Control
## Over everything on a Win95 screen: the coloured blocks and torn lines of an overheating GPU,
## while the computer runs with a problem whose screen_artifacts is above 0 and the hardware isn't
## fixed. They flicker; a higher screen_artifacts draws more of them.

## The computer whose screen this is. Set before the node enters the tree.
var state: ComputerState
## The seconds between two new sets of artifacts.
var step_seconds: float = 0.12

const _VGA: Array[Color] = [Color("aa0000"), Color("00aa00"), Color("aa5500"), Color("0000aa"), Color("aa00aa"),
		Color("00aaaa"), Color("aaaaaa"), Color("ff5555"), Color("55ff55"), Color("ffff55"), Color("5555ff"),
		Color("ff55ff"), Color("55ffff"), Color("ffffff")]

var _rects: Array = []
var _due: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100  # above the boot screens and windows that come later
	Game.changed.connect(_sync)
	_sync()


func _strength() -> float:
	if state == null or state.job == null or not state.is_on or state.job.hardware_fixed:
		return 0.0
	return state.job.problem.screen_artifacts


func _sync() -> void:
	visible = _strength() > 0.0
	set_process(visible)
	size = get_viewport_rect().size  # the Win95 root is not laid out over the screen


func _process(delta: float) -> void:
	_sync()
	_due -= delta
	if _due > 0.0:
		return
	_due = step_seconds
	_new_artifacts(_strength())
	queue_redraw()


# Blocks snapped to an 8-pixel grid, some as checkerboards, and a torn band or two across the screen.
func _new_artifacts(strength: float) -> void:
	_rects.clear()
	if randf() < 0.25:
		return  # a clean frame now and then makes it flicker
	for i: int in int(lerpf(6.0, 60.0, strength)):
		var at := Vector2(randi() % int(maxf(size.x, 8.0)), randi() % int(maxf(size.y, 8.0))).snapped(Vector2(8, 8))
		var block := Vector2(8 * (1 + randi() % 6), 4 * (1 + randi() % 3))
		_rects.append([Rect2(at, block), _VGA[randi() % _VGA.size()], randf() < 0.4])
	for i: int in 1 + randi() % int(1.0 + 3.0 * strength):
		var y := float(randi() % int(maxf(size.y, 1.0)))
		_rects.append([Rect2(0.0, y, size.x, 2.0 + randi() % 4), _VGA[randi() % _VGA.size()] * Color(1, 1, 1, 0.6), false])


func _draw() -> void:
	for each: Array in _rects:
		var rect: Rect2 = each[0]
		var colour: Color = each[1]
		if not each[2]:
			draw_rect(rect, colour)
			continue
		for x: int in int(rect.size.x / 4.0):
			for y: int in int(rect.size.y / 4.0):
				if (x + y) % 2 == 0:
					draw_rect(Rect2(rect.position + Vector2(x, y) * 4.0, Vector2(4, 4)), colour)
