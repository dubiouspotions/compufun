extends CorruptionSign
## Now and then, when the mouse leaves the open bench screen while the connected computer runs
## Cambion (Game.runs_cambion), the Win95 arrow comes along: it stays the mouse cursor over the shop
## for [member linger_seconds], or until the mouse is back on the screen, before the game's cursor
## returns (wiki: In-world - Corruption Signs). Day 3 starts it and day 6 ends it.

## The chance, 0 to 1, that the arrow comes along each time the mouse leaves the screen.
@export_range(0.0, 1.0) var escape_chance: float = 0.2
## The seconds that the arrow stays the cursor off the screen.
@export var linger_seconds: float = 3.0

var _random := RandomNumberGenerator.new()
var _seeded_jump: int = -1
var _view: ScreenView  # the view whose arrow lingers; null while none does
var _left: float = 0.0
var _arrow: Image


## True while the Win95 arrow stands in for the game's cursor.
func is_lingering() -> bool:
	return _view != null


func _apply(shown_stage: int) -> void:
	if Game.jump != _seeded_jump:
		_seeded_jump = Game.jump
		_random.seed = hash(Game.day_number)  # every start or restore of a day rolls the same: the week bot and restores repeat
	if shown_stage > 0:
		_listen.call_deferred()  # the screens are in the main scene's UI, which is ready after the shop
	if shown_stage <= 0 or not _cambion_connected():
		_end()


func _listen() -> void:
	for node: Node in get_tree().get_nodes_in_group(CrtScreen.GROUP):
		var screen := node as CrtScreen
		var view := screen.get_parent() as ScreenView
		if view == null or view.screen != ViewMarker.Screen.WIN95 or screen.mouse_entered.is_connected(_end):
			continue
		screen.mouse_exited.connect(_on_screen_left.bind(view))
		screen.mouse_entered.connect(_end)


func _on_screen_left(view: ScreenView) -> void:
	if stage() <= 0 or not _cambion_connected() or _windows_cursor_shown() or _random.randf() >= escape_chance:
		return
	var screen := view.crt_screen()
	if _arrow == null:
		_arrow = screen.arrow_cursor.get_image()
		if _arrow == null:
			push_error("pointer_escape: the arrow %s has no image" % screen.arrow_cursor)
			return
		_arrow.resize(_arrow.get_width() * view.zoom, _arrow.get_height() * view.zoom, Image.INTERPOLATE_NEAREST)
	ScreenView.set_cursor(_arrow, Input.CURSOR_ARROW, screen.arrow_hotspot * view.zoom)
	_view = view
	_left = linger_seconds
	set_process(true)


func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		_end()


# Gives the game's cursor back.
func _end() -> void:
	set_process(false)
	if _view != null and not _windows_cursor_shown():
		ScreenView.set_cursor(_view.game_cursor, Input.CURSOR_ARROW, _view.game_cursor_hotspot)
	_view = null


# The display server outlives the image and logs a leak at exit unless it is cleared.
func _exit_tree() -> void:
	if _view != null:
		ScreenView.set_cursor(null, Input.CURSOR_ARROW)
		_view = null


func _cambion_connected() -> bool:
	return Game.connected != null and Game.runs_cambion(Game.connected.customer)


# The sign win_cursor already makes the shop's cursor the Win95 arrow, and owns it.
func _windows_cursor_shown() -> bool:
	for node: Node in get_tree().get_nodes_in_group(CorruptionSign.GROUP):
		var other := node as CorruptionSign
		if other.id() == &"win_cursor" and other.stage() > 0:
			return true
	return false
