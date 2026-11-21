extends Node
## The game: the world buffer with the room, the UI on top, and the day that starts.

## The dev tools (F3); the folder is left out of exports, so a shipped game has none.
const DEV_MENU: String = "res://dev/dev_menu.tscn"

## The day that starts when the game starts.
@export var first_day: Day

## The Game.arrival whose conversation started; it starts when the player first faces the visitor.
var _dialogue_for: int = -1

@onready var _shop: Shop = %Shop
@onready var _nav: ViewNav = %ViewNav
@onready var _dialogue: DialogueOverlay = %DialogueOverlay
@onready var _calling: CustomerCalling = %CustomerCalling
@onready var _workview: WorkviewPanel = %WorkviewPanel
@onready var _screen_views: Array[ScreenView] = [%ScreenView, %CompuFunDBView]
@onready var _post_it_label: PostItLabel = %PostItLabel
@onready var _end_of_day: EndOfDay = %EndOfDay
@onready var _crash: Crash = %Crash
@onready var _phone: PhoneCall = %PhoneCall
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
		view.outside_clicked.connect(_go_back)
	# Right before drawing, after the camera tween moved: the copy never lags behind the 3D screen.
	RenderingServer.frame_pre_draw.connect(_follow_camera)
	_shop.view_requested.connect(Game.go_to_view)
	_nav.view_requested.connect(Game.go_to_view)
	_shop.close_requested.connect(_end_of_day.ask)
	_shop.crashed.connect(_crash.show_crash)
	_shop.phone_requested.connect(_phone.open)
	_shop.degauss_requested.connect((%ScreenView as ScreenView).degauss)
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
	var scale := _world.size / Vector2(_world_buffer.size)
	var post_it := _shop.pinned_post_it()
	var paper := _shop.post_it_rect(post_it) if post_it != null else Rect2()
	var on_screen := paper.has_area() and paper.intersects(Rect2(Vector2.ZERO, Vector2(_world_buffer.size)))
	_post_it_label.visible = on_screen
	if on_screen:
		_post_it_label.job = post_it.job
		_post_it_label.follow(Rect2(_world.position + paper.position * scale, paper.size * scale))
	for view: ScreenView in _screen_views:
		if view.visible:
			var pixels := _shop.screen_rect(view.screen)
			view.follow(Rect2(_world.position + pixels.position * scale, pixels.size * scale))


# Cmd+N (Ctrl+N) in debug builds skips to the next event; _input, so a screen that eats keys can't hide it.
func _input(event: InputEvent) -> void:
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
		Game.go_to_view(marker.left)
	elif event.is_action_pressed(&"turn_right"):
		Game.go_to_view(marker.right)
	elif event.is_action_pressed(&"look_up") and marker.up != &"":
		Game.go_to_view(marker.up)
	elif event.is_action_pressed(&"go_back"):
		_go_back()
	else:
		return
	get_viewport().set_input_as_handled()


func _go_back() -> void:
	var marker := _shop.view_marker(Game.view)
	if marker != null:
		Game.go_to_view(marker.back)


func _sync() -> void:
	var marker := _shop.view_marker(Game.view)
	_nav.show_marker(marker)
	var screen := marker.screen if marker != null else ViewMarker.Screen.NONE
	_workview.visible = screen == ViewMarker.Screen.WORKVIEW
	for view: ScreenView in _screen_views:
		view.set_open(screen == view.screen)
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
