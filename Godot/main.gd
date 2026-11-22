extends Node
## The game: the world buffer with the room, the UI on top, and the day that starts.

## The dev tools (F3); the folder is left out of exports, so a shipped game has none.
const DEV_MENU: String = "res://dev/dev_menu.tscn"

## The day that starts when the game starts.
@export var first_day: Day

## The Game.arrival whose conversation started; it starts when the player first faces the visitor.
var _dialogue_for: int = -1
## The hotspot beside the open screen that the mouse is over, or null (see _hover_beside_screen).
var _hovered_beside_screen: Hotspot

@onready var _shop: Shop = %Shop
@onready var _nav: ViewNav = %ViewNav
@onready var _dialogue: DialogueOverlay = %DialogueOverlay
@onready var _calling: CustomerCalling = %CustomerCalling
@onready var _screen_views: Array[ScreenView] = [%ScreenView, %CompuFunDBView]
@onready var _post_it_label: PostItLabel = %PostItLabel
@onready var _end_of_day: EndOfDay = %EndOfDay
@onready var _phone: PhoneCall = %PhoneCall
@onready var _printout: CarriedPrintout = %CarriedPrintout
@onready var _world: SubViewportContainer = $World
@onready var _world_buffer: SubViewport = $World/WorldBuffer



## Renders every view once, behind the loading screen, so that no shader compiles while the player
## plays (see Shop.warm_up).
func warm_up() -> void:
	await _shop.warm_up()

func _ready() -> void:
	if OS.is_debug_build() and ResourceLoader.exists(DEV_MENU):
		add_child(load(DEV_MENU).instantiate())
	for view: ScreenView in _screen_views:
		view.add_look(_shop.set_screen_texture(view.screen, view.screen_texture()))
		view.fade_seconds = _shop.turn_seconds
		view.outside_clicked.connect(_click_outside_screen)
	# Right before drawing, after the camera tween moved: the copy never lags behind the 3D screen.
	RenderingServer.frame_pre_draw.connect(_follow_camera)
	_shop.view_requested.connect(Game.go_to_view)
	_nav.view_requested.connect(Game.go_to_view)
	_shop.back_strip_hovered.connect(func(on: bool) -> void: _nav.show_back_strip(on, _shop.back_strip_height))
	_shop.close_requested.connect(_end_of_day.ask)
	_shop.crashed.connect(func() -> void: Finale.start(get_tree()))  # the pipes end in the finale
	_shop.phone_requested.connect(_phone.open)
	_shop.degauss_requested.connect((%ScreenView as ScreenView).degauss)
	var work_screen: ScreenView = %CompuFunDBView
	work_screen.picture_changed.connect(func() -> void: _shop.work_computer_running = work_screen.has_picture())
	_shop.work_computer_running = work_screen.has_picture()
	_dialogue.finished.connect(Game.dialogue_finished)
	Game.changed.connect(_sync)
	Game.start_day(first_day)
	_sync()


func _process(_delta: float) -> void:
	# frame_pre_draw fires only when a frame is drawn; a headless run draws none.
	_follow_camera()


func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_follow_camera):
		RenderingServer.frame_pre_draw.disconnect(_follow_camera)


func _follow_camera() -> void:
	_dialogue.position.x = _shop.turn_from_main() * _dialogue.size.x
	_calling.point_to(_shop.customer_direction(), _nav.button_rects())
	var scale := _world.size / Vector2(_world_buffer.size)
	var post_it := _shop.pinned_post_it()
	var paper := _shop.post_it_rect(post_it) if post_it != null else Rect2()
	var on_screen := paper.has_area() and paper.intersects(Rect2(Vector2.ZERO, Vector2(_world_buffer.size)))
	_post_it_label.visible = on_screen
	if on_screen:
		_post_it_label.job = post_it.job
		_post_it_label.follow(Rect2(_world.position + paper.position * scale, paper.size * scale), _shop.post_it_quarter_turns(post_it))
	if _end_of_day.asking():
		# Over the sign while the camera sees it, otherwise in the middle of the screen.
		var board := _shop.open_sign_rect()
		if not (board.has_area() and board.intersects(Rect2(Vector2.ZERO, Vector2(_world_buffer.size)))):
			board = Rect2(Vector2.ZERO, Vector2(_world_buffer.size))
		_end_of_day.follow(Rect2(_world.position + board.position * scale, board.size * scale))
	for view: ScreenView in _screen_views:
		if view.visible:
			var pixels := _shop.screen_rect(view.screen)
			view.follow(Rect2(_world.position + pixels.position * scale, pixels.size * scale))
	_printout.lay_out_around((%CompuFunDBView as ScreenView).open_rect(), _nav.button_rects())


# Cmd+N (Ctrl+N) in debug builds skips to the next event; _input, so a screen that eats keys can't hide it.
func _input(event: InputEvent) -> void:
	# _input, before the buttons, the back strip and the hotspots: while the post-it is up close, a click
	# or Esc only puts it back.
	var button := event as InputEventMouseButton
	var closes := button != null and button.pressed and button.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]
	if _shop.reading_post_it() and (closes or event.is_action_pressed(&"go_back")):
		_shop.close_post_it()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		_hover_beside_screen((event as InputEventMouseMotion).position)
	var key := event as InputEventKey
	if key != null and not key.echo and key.is_action_pressed(&"skip_ahead") and OS.is_debug_build():
		if not _shop.skip_walk():
			Game.skip_wait()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	var marker := _shop.view_marker(Game.view)
	if marker == null:
		return
	if event.is_action_pressed(&"turn_left"):
		_nav.press(&"left")
		Game.go_to_view(marker.left)
	elif event.is_action_pressed(&"turn_right"):
		_nav.press(&"right")
		Game.go_to_view(marker.right)
	elif event.is_action_pressed(&"look_up") and marker.up != &"":
		Game.go_to_view(marker.up)
	elif event.is_action_pressed(&"go_back"):
		_nav.press(&"back")
		_go_back()
	else:
		return
	get_viewport().set_input_as_handled()


# Zoomed in, a click beside the screen presses the hotspot there (the Degauss button) or leaves.
func _click_outside_screen(at: Vector2) -> void:
	var hotspot := _hotspot_beside_screen(at)
	if hotspot != null:
		hotspot.clicked.emit(hotspot)
	else:
		_go_back()


# The open Screen View takes the mouse from the world, so the hotspots beside it get their hover here.
func _hover_beside_screen(at: Vector2) -> void:
	var hotspot := _hotspot_beside_screen(at)
	if hotspot == _hovered_beside_screen:
		return
	if _hovered_beside_screen != null:
		_hovered_beside_screen.mouse_exited.emit()
	_hovered_beside_screen = hotspot
	if hotspot != null:
		hotspot.mouse_entered.emit()


# The hotspot at [param at] in the window beside a zoomed-in screen, or null: over the screen, with no
# screen zoomed in, or the hotspot that opens the current view.
func _hotspot_beside_screen(at: Vector2) -> Hotspot:
	for view: ScreenView in _screen_views:
		var rect := view.open_rect()
		if rect.has_area() and not rect.has_point(at):
			var world_at := (_world.get_global_transform_with_canvas().affine_inverse() * at) / float(_world.stretch_shrink)
			var hotspot := _shop.hotspot_at(world_at)
			if hotspot != null and not (hotspot.action == Hotspot.Action.GO_TO_VIEW and hotspot.view == Game.view):
				return hotspot
	return null


func _go_back() -> void:
	var marker := _shop.view_marker(Game.view)
	if marker != null:
		Game.go_to_view(marker.back)


func _sync() -> void:
	if Game.ending() == &"finale":
		Finale.start(get_tree())
	var marker := _shop.view_marker(Game.view)
	_nav.show_marker(marker)
	var screen := marker.screen if marker != null else ViewMarker.Screen.NONE
	for view: ScreenView in _screen_views:
		view.set_open(screen == view.screen)
	_hover_beside_screen(get_viewport().get_mouse_position())
	var talking := Game.visitor_state == Game.VisitorState.TALKING
	var facing := talking and marker != null and marker.faces_customer
	# Looking away hushes the line, and looking back says it again from its start.
	if facing and _dialogue_for != Game.arrival:
		_dialogue_for = Game.arrival
		_dialogue.start(Game.visitor, Game.conversation)
	elif facing and not _dialogue.visible:
		_dialogue.replay()
	elif not facing and _dialogue.visible:
		_dialogue.hush()
	_dialogue.visible = facing
	if talking and not facing:
		_calling.call_out(Game.visitor)
	else:
		_calling.stop()
