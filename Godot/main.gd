extends Node
## The game: the world buffer with the room, the UI on top, and day 1 of the week that Game loaded.

## The dev tools (F3); the folder is left out of exports, so a shipped game has none.
const DEV_MENU: String = "res://dev/dev_menu.tscn"

## While true, the visitor's conversation waits to start: no dialogue box, no call-out, no Skip
## tutorial button. The loading screen holds it until its zoom is part way, so that the first line
## comes as the shop comes into view.
var talk_held: bool = false:
	set(value):
		talk_held = value
		if is_node_ready():
			_sync_talk()

## The Game.arrival whose conversation started; it starts when the player first faces the visitor.
var _dialogue_for: int = -1
## A look of the conversation turned the player away from the visitor, and they haven't faced the
## visitor since: the conversation goes on in the call-out box.
var _led_away: bool = false
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
@onready var _skip_tutorial: Button = %SkipTutorial
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
	_nav.focus_requested.connect(Game.focus_job)
	_shop.back_strip_hovered.connect(func(on: bool) -> void: _nav.show_back_strip(on, _shop.back_strip_height))
	_shop.close_requested.connect(_end_of_day.ask)
	_shop.crashed.connect(func() -> void: Finale.start(get_tree()))  # the pipes end in the finale
	_shop.phone_requested.connect(_phone.open)
	_shop.degauss_requested.connect((%ScreenView as ScreenView).degauss)
	var work_screen: ScreenView = %CompuFunDBView
	work_screen.picture_changed.connect(func() -> void: _shop.work_computer_running = work_screen.has_picture())
	_shop.work_computer_running = work_screen.has_picture()
	_shop.work_power_requested.connect(work_screen.power_on)
	_dialogue.finished.connect(Game.dialogue_finished)
	_skip_tutorial.pressed.connect(Game.skip_before_opening)
	_dialogue.looked.connect(_look)
	_calling.line_read.connect(_on_line_read)
	Game.changed.connect(_sync)
	if Game.week != null:
		Game.start_day(Game.week.days[0])
		_restore_from_args()
	else:
		_show_story_errors()
	_sync()


# A debug run started with "-- --restore <file>" starts in the state that the file holds, in the
# format of Game.snapshot() (an F2 preset or "Copy state").
func _restore_from_args() -> void:
	var args := OS.get_cmdline_user_args()
	var at := args.find("--restore")
	if not OS.is_debug_build() or at < 0:
		return
	var path := args[at + 1] if at + 1 < args.size() else ""
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("--restore: can't read '%s': %s" % [path, error_string(FileAccess.get_open_error())])
		return
	var state: Variant = JSON.parse_string(text)
	if not state is Dictionary:
		push_error("--restore: '%s' is not a JSON object" % path)
		return
	var refused := Game.restore(state)
	if refused != "":
		push_error("--restore: Game refused '%s': %s" % [path, refused])


# The loading screen shows them first; this box is for a run of main.tscn alone.
func _show_story_errors() -> void:
	var box := AcceptDialog.new()
	box.title = "The story files have errors"
	box.dialog_text = "No day can start until they are fixed:\n" + "\n".join(Game.story_errors)
	add_child(box)
	box.popup_centered()


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
		_nav.turn(&"left")
	elif event.is_action_pressed(&"turn_right"):
		_nav.turn(&"right")
	elif event.is_action_pressed(&"look_up") and Game.view == &"Main" and _shop.centred_job() != null:
		_shop.work_on(_shop.centred_job())
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
	_sync_talk()


# Shows the visitor's conversation in the box while the player faces them, in the call-out box while
# a look of its own turned the player away; otherwise the visitor calls out that they wait.
func _sync_talk() -> void:
	var marker := _shop.view_marker(Game.view)
	var talking := Game.visitor_state == Game.VisitorState.TALKING and not talk_held
	_skip_tutorial.visible = Game.can_skip_before_opening() and not talk_held
	var facing := talking and marker != null and marker.faces_customer
	if facing or not talking or _dialogue_for != Game.arrival:
		_led_away = false
	var was_shown := _dialogue.visible
	if not facing and was_shown:
		_dialogue.hush()
	_dialogue.visible = facing
	var line := _dialogue.shown_line() if _led_away else null
	if line != null:
		_calling.say(Game.visitor, line, Game.conversation)
	elif talking and not facing:
		_calling.call_out(Game.visitor, Game.call_outs_of(Game.visitor))
	elif not Game.leaving_lines.is_empty():
		_calling.call_out_leaving(Game.visitor, Game.leaving_lines)
	else:
		_calling.stop()
	# Last: a look of the line that starts comes back here. Looking away on one's own hushes the line,
	# and looking back says it again from its start.
	if facing and _dialogue_for != Game.arrival:
		_dialogue_for = Game.arrival
		_dialogue.start(Game.visitor, Game.conversation)
	elif facing and not was_shown:
		_dialogue.replay()


# A look of the conversation turns the player's view; turned away, its lines go on in the call-out box.
func _look(look: StringName) -> void:
	var view: StringName = DialogueLine.LOOKS.get(look, &"")
	var marker := _shop.view_marker(view)
	if marker == null:
		push_error("Main: the look '%s' of a line in %s names no view of the shop (%s); the view stays" % [look, String(Game.conversation.id) if Game.conversation != null else "no conversation", view])
		return
	_led_away = not marker.faces_customer
	Game.go_to_view(view)
	_sync_talk()  # also when the view was there already


func _on_line_read(line: DialogueLine) -> void:
	if not _led_away or line != _dialogue.shown_line():
		return
	_dialogue.next_line()
	_sync_talk()
