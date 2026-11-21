extends Node
## The game: the world buffer with the room, the UI on top, and the day that starts.

## The day that starts when the game starts.
@export var first_day: Day

var _dialogue_for: int = -1

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
	RenderingServer.frame_pre_draw.connect(_follow_screen)
	_shop.view_requested.connect(Game.go_to_view)
	_nav.view_requested.connect(Game.go_to_view)
	_dialogue.finished.connect(Game.dialogue_finished)
	_post_it.ticked.connect(Game.tick_post_it)
	Game.changed.connect(_sync)
	Game.start_day(first_day)
	_sync()


func _process(_delta: float) -> void:
	# frame_pre_draw fires only when a frame is drawn; a headless run draws none.
	_follow_screen()


func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_follow_screen):
		RenderingServer.frame_pre_draw.disconnect(_follow_screen)


func _follow_screen() -> void:
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
	elif event.is_action_pressed(&"ui_cancel"):
		Game.go_to_view(marker.back)
	else:
		return
	get_viewport().set_input_as_handled()


func _sync() -> void:
	var marker := _shop.view_marker(Game.view)
	_nav.show_marker(marker)
	var screen := marker.screen if marker != null else ViewMarker.Screen.NONE
	_compufun_db.visible = screen == ViewMarker.Screen.COMPUFUN_DB
	_workview.visible = screen == ViewMarker.Screen.WORKVIEW
	_screen_view.set_open(screen == ViewMarker.Screen.WIN95)
	_post_it.visible = Game.phase == Game.Phase.REPAIR or Game.phase == Game.Phase.CALLING
	var talking := Game.phase == Game.Phase.TALKING
	if talking and _dialogue_for != Game.customer_index:
		_dialogue_for = Game.customer_index
		_dialogue.start(Game.customer)
	_dialogue.visible = talking
