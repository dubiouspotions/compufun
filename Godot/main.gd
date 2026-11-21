extends Node
## The game: the world buffer with the room, the UI on top, and the day that starts.

## The day that starts when the game starts.
@export var first_day: Day

var _talking: bool = false

@onready var _shop: Shop = %Shop
@onready var _nav: ViewNav = %ViewNav
@onready var _post_it: PostIt = %PostIt
@onready var _dialogue: DialogueOverlay = %DialogueOverlay
@onready var _compufun_db: CompufunDB = %CompufunDB
@onready var _workview: WorkviewPanel = %WorkviewPanel
@onready var _screen_view: ScreenView = %ScreenView
@onready var _world: SubViewportContainer = $World
@onready var _world_buffer: SubViewport = $World/WorldBuffer


func _ready() -> void:
	_shop.set_desktop_texture(_screen_view.screen_texture())
	_screen_view.fade_seconds = _shop.turn_seconds
	# Right before drawing, after the camera tween moved: the copy never lags behind the 3D screen.
	RenderingServer.frame_pre_draw.connect(_follow_camera)
	_shop.view_requested.connect(Game.go_to_view)
	_nav.view_requested.connect(Game.go_to_view)
	_screen_view.outside_clicked.connect(_go_back)
	_dialogue.finished.connect(Game.dialogue_finished)
	_post_it.ticked.connect(Game.tick_post_it)
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
	if not _screen_view.visible:
		return
	var pixels := _shop.bench_screen_rect()
	var scale := _world.size / Vector2(_world_buffer.size)
	_screen_view.follow(Rect2(_world.position + pixels.position * scale, pixels.size * scale))


func _unhandled_input(event: InputEvent) -> void:
	var marker := _shop.view_marker(Game.view)
	if marker == null:
		return
	if event.is_action_pressed(&"turn_left"):
		Game.go_to_view(marker.left)
	elif event.is_action_pressed(&"turn_right"):
		Game.go_to_view(marker.right)
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
	_compufun_db.visible = screen == ViewMarker.Screen.COMPUFUN_DB
	_workview.visible = screen == ViewMarker.Screen.WORKVIEW
	_screen_view.set_open(screen == ViewMarker.Screen.WIN95)
	if screen == ViewMarker.Screen.WIN95 and Game.connected == null and Game.focus != null:
		Game.connect_cable.call_deferred(Game.focus)  # Bridge until the VGA cable exists: the Screen View connects the focused job.
	_post_it.job = Game.focus
	_post_it.visible = Game.focus != null
	var talking := Game.visitor_state == Game.VisitorState.TALKING
	if talking and not _talking:
		_dialogue.start(Game.visitor, Game.ARRIVE_CONVERSATION if Game.visit == Game.Visit.DROP_OFF else Game.PICKUP_CONVERSATION)
	_talking = talking
	_dialogue.visible = talking
