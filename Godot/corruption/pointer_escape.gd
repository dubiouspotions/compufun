extends CorruptionSign
## Now and then, while the player looks at the Win95 screen, its pointer slides off the nearest
## edge of the screen and comes back a moment later (wiki: In-world - Corruption Signs). The
## mouse still points and clicks where it is; only the drawn pointer goes.

## The fewest seconds between two escapes, counted only while the player looks at the screen.
@export var wait_min: float = 8.0
## The most seconds between two escapes.
@export var wait_max: float = 20.0
## The seconds that the pointer takes to slide off the screen.
@export var slide_seconds: float = 0.3
## The seconds that it stays off the screen.
@export var away_seconds: float = 1.5
## The seconds that it takes to slide back to the mouse.
@export var return_seconds: float = 0.5
## How far past the edge it goes, in screen buffer pixels: more than the pointer's size.
@export var beyond: float = 40.0

var _on: bool = false
var _wait: float = 0.0
## How far out the pointer is: 0 at the mouse, 1 past the edge.
var _away: float = 0.0
var _side: Side = SIDE_RIGHT
var _escape: Tween


func _apply(shown_stage: int) -> void:
	var on := shown_stage > 0
	set_process(on)
	if on == _on:
		return
	_on = on
	_wait = randf_range(wait_min, wait_max)
	if not on:
		if _escape != null:
			_escape.kill()
		_away = 0.0
		_push()


func _process(delta: float) -> void:
	if _escape != null and _escape.is_running():
		_push()
		return
	var watched := _watched()
	if watched == null:
		return
	_wait -= delta
	if _wait <= 0.0:
		_start(watched)


func _start(screen: CrtScreen) -> void:
	var at := screen.cursor_at() / Vector2(screen.buffer.size)
	var gaps: Dictionary[Side, float] = {SIDE_LEFT: at.x, SIDE_RIGHT: 1.0 - at.x, SIDE_TOP: at.y, SIDE_BOTTOM: 1.0 - at.y}
	_side = SIDE_LEFT
	for side: Side in gaps:
		if gaps[side] < gaps[_side]:
			_side = side
	_escape = create_tween()
	_escape.tween_property(self, ^"_away", 1.0, slide_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_escape.tween_interval(away_seconds)
	_escape.tween_property(self, ^"_away", 0.0, return_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_escape.tween_callback(func() -> void:
		_wait = randf_range(wait_min, wait_max)
		_push())


# The Win95 screen that the player looks at: a CRT screen on view that draws its pointer.
func _watched() -> CrtScreen:
	for node: Node in get_tree().get_nodes_in_group(CrtScreen.GROUP):
		var screen := node as CrtScreen
		if screen.is_visible_in_tree() and screen.cursor_visible and screen.buffer != null:
			return screen
	return null


# Moves every screen's pointer _away of the way from the mouse to past the edge on _side.
func _push() -> void:
	for node: Node in get_tree().get_nodes_in_group(CrtScreen.GROUP):
		var screen := node as CrtScreen
		if screen.buffer == null:
			continue
		var at := screen.cursor_at()
		var size := Vector2(screen.buffer.size)
		var out := Vector2.ZERO
		match _side:
			SIDE_LEFT:
				out.x = -at.x - beyond
			SIDE_RIGHT:
				out.x = size.x - at.x + beyond
			SIDE_TOP:
				out.y = -at.y - beyond
			SIDE_BOTTOM:
				out.y = size.y - at.y + beyond
		screen.cursor_offset = out * _away
