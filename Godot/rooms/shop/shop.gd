class_name Shop
extends Node3D
## The shop room: the view markers, the hotspots and the customer path. It shows the Game state.

## A hotspot asks to go to a view.
signal view_requested(view: StringName)
## The player clicked the Open sign while [method Game.can_close] is true.
signal close_requested
## The end has played in the room: time for the bluescreen.
signal crashed
## The player clicked the phone while [method Game.can_call] is true, to call a customer. While the
## shop is closed and a computer is done, a click on the phone shakes the Open sign instead. With no
## computer done, the phone takes no clicks.
signal phone_requested
## The player pressed the Degauss button of the bench screen.
signal degauss_requested
## The player pressed the power button of the work computer while it was off.
signal work_power_requested
## The mouse came onto the back strip ([param on] true) or left it (see [member back_strip_height]).
signal back_strip_hovered(on: bool)
## A finger swiped across the world, and lifted: [param direction] is the way that it moved,
## Vector2i.LEFT, RIGHT, UP or DOWN. Never for a mouse, nor while the player drags the plug or a part.
signal swiped(direction: Vector2i)

## The close-up of the computer in focus.
const WORKVIEW: StringName = &"Workview"

## The seconds that the camera takes to move to another view.
@export var turn_seconds: float = 0.35
## The tint of the work computer's power button while the mouse is over it.
@export var work_power_hover_color: Color = Color(1.0, 0.84, 0.35)
## The seconds that a customer takes from the alley to the counter, and back.
@export var walk_seconds: float = 7.0
## The seconds that a customer takes to turn around at the counter before walking out.
@export var about_face_seconds: float = 0.4
## The height of the back strip, as a share of the view's height: the strip along the bottom of a
## view with Back and no screen (Workview, Storage, Up). A click there that hits nothing clickable
## (a hotspot, the part in the hand) goes back, like the Back button.
@export_range(0.0, 0.5) var back_strip_height: float = 0.18
## How far the mouse moves, in pixels of the world buffer, between the press that grabs the plug and
## its release, for the release to drop the plug there. A shorter move is a click: the plug stays in
## the hand and follows the mouse until the next click drops it. A turn to another view lays it down.
@export var plug_drag_threshold: float = 3.0
## How far a finger may move between touching and lifting and still tap, as a share of the view's
## height (TapGate). Further, and it clicks nothing.
@export_range(0.0, 0.2) var tap_slop: float = 0.02
## How far a finger must move to swipe, as a share of the view's width.
@export_range(0.0, 1.0) var swipe_distance: float = 0.1
## The longest that a swipe takes from touch to lift, in seconds; a slower drag doesn't swipe.
@export var swipe_max_seconds: float = 0.6
## How many times further than across its axis a finger must move along it to swipe that way.
@export var swipe_axis_ratio: float = 2.0
## How far in front of the Workview camera the post-it comes when the player clicks it, in metres.
@export var post_it_read_distance: float = 0.2
## The seconds that the post-it takes to come up close, and to go back onto the computer.
@export var post_it_read_seconds: float = 0.3
## The phone's outline while a click calls (Game.can_call): pulsing, or the hover colour under the
## mouse; and how far it stands out from the phone, in metres.
@export var phone_outline: ClickableOutline = preload("res://rooms/clickable_outline.tres")
@export var phone_outline_width: float = 0.01

@onready var _camera: ViewCamera = %Camera
@onready var _views: Node3D = %Views
@onready var _follow: PathFollow3D = %CustomerFollow
@onready var _path: Path3D = $CustomerPath
# By Game.AlleyEnd: the scene's customer path comes in from the right end, the left's is its mirror image.
@onready var _alley_paths: Array[Curve3D] = [_path.curve, _mirrored(_path.curve)]
## How high the customer's head is above their feet, in metres, for the call-out's arrow.
@export var head_height: float = 1.6

@onready var _body: CustomerBody = %CustomerBody
@onready var _pop_up_spot: Marker3D = %PopUpSpot
## Takes the click on a visitor who waits beside the computer that they show.
@onready var _visitor_hotspot: Hotspot = %VisitorHotspot
@onready var _job_slots: JobSlots = %JobSlots
@onready var _bench: Bench = %Bench
@onready var _pipedream: Pipedream = %Pipedream
@onready var _work_monitor: CrtMonitor = %WorkMonitor
@onready var _work_tower: PcTower = $Room/WorkTower
@onready var _work_power: Hotspot = %PowerHotspot
@onready var _open_sign: OpenSign = %OpenSign
@onready var _door_bell: AudioStreamPlayer3D = %DoorBell
@onready var _phone_receiver: AudioStreamPlayer3D = %PhoneReceiver
@onready var _phone_hotspot: Hotspot = %Phone
@onready var _phone_body: MeshInstance3D = $Room/PhoneProp/Body
@onready var _the_end: TheEnd = %TheEnd
@onready var _hand: Hand = %Hand

## Plays when a part comes into the player's hand, and when it leaves it (put in, on the mat, away).
@export var part_take_sound: SoundSet = preload("res://sounds/part_take.tres")
@export var part_put_sound: SoundSet = preload("res://sounds/part_put.tres")
## Plays at a computer's socket when the keyboard cable goes in, and when it comes out.
@export var plug_in_sound: SoundSet = preload("res://sounds/cable_plug_in.tres")
@export var plug_out_sound: SoundSet = preload("res://sounds/cable_plug_out.tres")
## How far the view jolts as a problem's reveal stab plays (Problem.reveal_stab), in metres, and how
## long it takes to settle, in seconds.
@export var stab_shake_metres: float = 0.025
@export var stab_shake_seconds: float = 0.6
## An event's pop-up (Game.VisitorState.POPPING_UP): the customer rises from pop_up_depth metres below
## the PopUpSpot marker in pop_up_seconds, the view jolts by pop_up_shake_metres and the body
## wobbles by up to pop_up_wobble_degrees over pop_up_shake_seconds; they stay pop_up_stay_seconds,
## then step to the counter in pop_up_step_seconds. Until that step, their photo relief shows the
## portrait of the pop-up line's mood.
@export var pop_up_depth: float = 1.0
## In the Workview the customer peeks over the counter instead, as far back as the PopUpSpot: their
## face shows at this point of the view's 16:9 frame, from (0, 0) in the middle to (1, 1) at its top
## right corner. The default is beside the open case, which stands up into the top of the view.
@export var pop_up_peek_at: Vector2 = Vector2(0.6, 0.6)
@export var pop_up_seconds: float = 0.25
@export var pop_up_shake_metres: float = 0.05
@export var pop_up_wobble_degrees: float = 6.0
@export var pop_up_shake_seconds: float = 0.7
@export var pop_up_stay_seconds: float = 1.2
@export var pop_up_step_seconds: float = 0.6

## Whether the work computer runs; its fans hum while it does.
var work_computer_running: bool = false:
	set(value):
		work_computer_running = value
		_work_tower.running = value
		_work_power.set_enabled(not value)

var _shown_view: StringName = &""
## What the hand held and where the cable was at the last sync, to hear what changed since.
var _heard_hand: Variant = null
var _heard_cable: Job
var _heard_jump: int = -1  # the Game.jump at the last sync: no change sounds over a jump
var _workview_job: Job
var _workview_lying: bool = false
var _walk_in_arrival: int = -1
var _walk_out_arrival: int = -1
var _pop_up_arrival: int = -1
var _walk_tween: Tween
var _calling: bool = false
var _camera_tween: Tween
var _camera_seconds: float = 0.0
var _stab_shake: Tween
# The jobs whose case was open at the last sync.
var _heard_open: Array[Job] = []
var _mouse := Vector2(-1.0, -1.0)  # in pixels of the world buffer
var _press_at := Vector2(-1.0, -1.0)  # where the left button last went down, in pixels of the world buffer
var _grab_held: bool = false  # from the press that grabbed the plug until its release
var _swipe_from := Vector2.INF  # where the finger that may swipe touched, in pixels of the world buffer; INF while none
var _swipe_seconds: float = 0.0  # since that touch
var _on_back_strip: bool = false
var _over_post_it: bool = false
var _read_post_it: PostIt3D  # the post-it up close or on its way there or back, or null
var _read_rest: Transform3D  # its transform on the computer
var _read_weight: float = 0.0  # 0 on the computer, 1 up close
var _read_open: bool = false
var _read_tween: Tween
var _view_hotspots: Array[Hotspot] = []  # GO_TO_VIEW hotspots, off in their own view so the back strip and the cursor see past them
var _phone_hovered: bool = false
var _phone_outline: StandardMaterial3D
var _phone_pulse_outline: StandardMaterial3D
var _phone_pulse: Tween


func _ready() -> void:
	for node: Node in find_children("*", "Area3D"):
		var hotspot := node as Hotspot
		if hotspot != null:
			hotspot.clicked.connect(_on_hotspot_clicked)
			if hotspot.action == Hotspot.Action.GO_TO_VIEW:
				_view_hotspots.append(hotspot)
	_job_slots.job_clicked.connect(work_on)
	_job_slots.computer_moved.connect(_on_computer_moved)
	_job_slots.power_clicked.connect(func(job: Job) -> void: Game.set_powered(job, not job.powered))
	_job_slots.floppy_clicked.connect(func(job: Job) -> void:
		if Game.has_floppy(job):
			Game.eject_floppy(job)
		else:
			Game.insert_floppy(job))
	_job_slots.screwdriver_clicked.connect(func(job: Job) -> void:
		if job.lying:
			Game.stand_up(job)
		else:
			Game.lay_down(job))
	_bench.view_requested.connect(view_requested.emit)
	_bench.plug_grabbed.connect(_on_plug_grabbed)
	_the_end.view_requested.connect(view_requested.emit)
	_the_end.crashed.connect(crashed.emit)
	_bench.degauss_pressed.connect(degauss_requested.emit)
	_work_power.highlight_on_hover(_work_tower.get_node(^"Power"), work_power_hover_color)
	_open_sign.open_requested.connect(Game.open_shop)
	_open_sign.close_requested.connect(close_requested.emit)
	_phone_outline = phone_outline.hover_material(phone_outline_width)
	_phone_pulse_outline = phone_outline.pulse_material(phone_outline_width)
	_phone_hotspot.mouse_entered.connect(_set_phone_hovered.bind(true))
	_phone_hotspot.mouse_exited.connect(_set_phone_hovered.bind(false))
	Game.changed.connect(_sync)
	_sync()


## The view marker with this name, or null (with an error) when the room has none.
## Shows a part in the hand, then every view, to the camera for one frame each, so that the renderer
## compiles each shader now and not on the player's first turn or take (a first turn stalled for 100
## to 200 ms, a first take for 90 ms). The camera ends where it began. The loading screen awaits it
## while it still covers the game.
func warm_up() -> void:
	var home := _camera.global_transform
	var home_fov := _camera.view_fov
	await _hand.warm_up(Part.every()[0])
	for node: Node in _views.get_children():
		var marker := node as ViewMarker
		if marker == null:
			continue
		_camera.global_transform = marker.global_transform
		_camera.view_fov = marker.fov
		await RenderingServer.frame_post_draw
	_camera.global_transform = home
	_camera.view_fov = home_fov


func view_marker(view_name: StringName) -> ViewMarker:
	var marker := _views.get_node_or_null(NodePath(String(view_name))) as ViewMarker
	if marker == null:
		push_error("Shop: no view marker named '%s' under Views" % view_name)
	return marker


## How far the camera has turned away from the Main view, where the customer stands, in widths of
## its view: 0 facing Main, positive turned left, 1 when Main has left the picture on the right.
func turn_from_main() -> float:
	var main := view_marker(&"Main")
	if main == null:
		return 0.0
	var yaw := angle_difference(main.global_rotation.y, _camera.global_rotation.y)
	return yaw / (2.0 * atan(_camera.tangents().x))


## The job whose computer stands nearest the middle of the Main View: its slot is the closest to the
## Main View's line of sight, and of two as close, the left one. null with the counter empty.
func centred_job() -> Job:
	var main := view_marker(&"Main")
	if main == null:
		return null
	var best: Job = null
	var best_off := INF
	for job: Job in Game.jobs:
		var slot := _job_slots.slot_marker(job.slot)
		if slot == null:
			continue
		var off := snappedf(absf((main.global_transform.affine_inverse() * slot.global_position).x), 0.001)  # mirrored slots tie
		if off < best_off or (off == best_off and job.slot < best.slot):
			best = job
			best_off = off
	return best


## How far the camera must turn to face the customer's head, in quarter turns: x to the right,
## y up, so (1, 0) is a quarter turn right and x reaches 2 behind. Zero while nobody is in the shop.
func customer_direction() -> Vector2:
	if not _body.visible:
		return Vector2.ZERO
	var head := _camera.global_transform.affine_inverse() * (_body.global_position + Vector3.UP * head_height)
	return Vector2(atan2(head.x, -head.z), atan2(head.y, Vector2(head.x, head.z).length())) / (PI * 0.5)


## The screen of the monitor that shows [param screen] as the camera sees it now, in pixels of the
## world buffer. Empty, with an error, when no monitor shows it.
func screen_rect(screen: ViewMarker.Screen) -> Rect2:
	var monitor := _monitor(screen)
	return _rect_on_screen(monitor.screen_corners()) if monitor != null else Rect2()


## The post-it of the computer in focus while the player reads it in the Workview, or null.
func pinned_post_it() -> PostIt3D:
	if Game.view != WORKVIEW or Game.focus == null:
		return null
	return _job_slots.pinned_post_it(Game.focus)


## True from the click that brings the pinned post-it up close until [method close_post_it].
func reading_post_it() -> bool:
	return _read_open


## Sends the post-it that the player reads up close back onto its computer.
func close_post_it() -> void:
	if _read_open:
		_read(false)


## The paper of [param post_it] as the camera sees it now: the rect around its corners, in pixels
## of the world buffer. Empty while a corner is behind the camera, as during a turn.
func post_it_rect(post_it: PostIt3D) -> Rect2:
	return _rect_in_front(post_it.paper_corners())


## How far the text on [param post_it] is turned as the camera sees it now, in quarter turns
## clockwise: 0 upright, -1 reading from the bottom up, as on a computer lying on its left side.
func post_it_quarter_turns(post_it: PostIt3D) -> int:
	var corners := post_it.paper_corners()
	var up := _camera.unproject_position(corners[0]) - _camera.unproject_position(corners[3])
	return roundi(Vector2.UP.angle_to(up) / (PI * 0.5))


## The open sign's board as the camera sees it now, in pixels of the world buffer. Empty while a
## corner is behind the camera.
func open_sign_rect() -> Rect2:
	return _rect_in_front(_open_sign.board_corners())


# The rect around [param corners] as the camera sees them, or an empty rect while one is behind it.
func _rect_in_front(corners: Array[Vector3]) -> Rect2:
	for corner: Vector3 in corners:
		if _camera.is_position_behind(corner):
			return Rect2()
	return _rect_on_screen(corners)


func _rect_on_screen(corners: Array[Vector3]) -> Rect2:
	var rect := Rect2(_camera.unproject_position(corners[0]), Vector2.ZERO)
	for corner: Vector3 in corners:
		rect = rect.expand(_camera.unproject_position(corner))
	return rect


## Shows [param texture] (a screen buffer) on the monitor that shows [param screen]. Returns that
## monitor's look, for its tube to drive; null, with an error, when no monitor shows it.
func set_screen_texture(screen: ViewMarker.Screen, texture: Texture2D) -> ShaderMaterial:
	var monitor := _monitor(screen)
	return monitor.set_screen_texture(texture) if monitor != null else null


func _monitor(screen: ViewMarker.Screen) -> CrtMonitor:
	match screen:
		ViewMarker.Screen.WIN95:
			return _bench.monitor
		ViewMarker.Screen.COMPUFUN_DB:
			return _work_monitor
	push_error("Shop: no monitor shows screen %s" % ViewMarker.Screen.find_key(screen))
	return null


func _input(event: InputEvent) -> void:
	TapGate.track(event, tap_slop * get_viewport().get_visible_rect().size.y)
	var mouse := event as InputEventMouse
	if mouse != null:
		_mouse = mouse.position
	var button := event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		_press_at = button.position


func _process(delta: float) -> void:
	_swipe_seconds += delta
	var over := _post_it_at(_mouse)
	if over != _over_post_it:
		_over_post_it = over
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if over else Input.CURSOR_ARROW)
	var on := _back_strip_at(_mouse)
	if on:
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)  # every frame: a hotspot that the mouse left resets it
	if on == _on_back_strip:
		return
	_on_back_strip = on
	if not on and _clickable_at(_mouse) == null:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	back_strip_hovered.emit(on)


# A click on the back strip goes back. The plug in the hand follows the mouse. The release that ends
# a drag, or the next click, plugs it into the computer under the mouse, or lays it down. Here, before
# physics picking: a finger's swipe that started on a hotspot doesn't reach it.
func _unhandled_input(event: InputEvent) -> void:
	if _swiped(event):
		get_viewport().set_input_as_handled()
		return
	var click: InputEventMouseButton = event as InputEventMouseButton if TapGate.clicks(event) else null
	if click != null and _post_it_at(click.position):
		get_viewport().set_input_as_handled()
		_read(true)
		return
	if click != null and _back_strip_at(click.position):
		get_viewport().set_input_as_handled()
		view_requested.emit(view_marker(Game.view).back)
		return
	if click != null and Game.focus != null and Game.focus.lying and not Game.focus.case_open and _empty_workview_at(click.position):
		get_viewport().set_input_as_handled()  # the standing case must not take this click in picking
		if Game.can_stand_up(Game.focus):
			Game.stand_up(Game.focus)  # as a click on the screwdriver's outline does
		else:
			_job_slots.blink_screws(Game.focus)  # a screw that is out keeps it lying
		return
	var mouse := event as InputEventMouse
	if not _bench.dragging or mouse == null:
		return
	var button := mouse as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()  # physics picking skips handled events: the click that drops the plug clicks nothing else
		if button.pressed:
			_drop_plug(_job_at(button.position))
		elif _grab_held:
			_end_grab(button.position)
		return
	_carry_plug(mouse.position)


# Follows a finger on the world from its touch; true when [param event] is the lift that ends a swipe,
# after [signal swiped] fired.
func _swiped(event: InputEvent) -> bool:
	var button := event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT or not TouchInput.is_touch(button):
		return false
	if button.pressed:
		_swipe_from = Vector2.INF if _bench.dragging or _hand.is_dragging() else button.position
		_swipe_seconds = 0.0
		return false
	var from := _swipe_from
	_swipe_from = Vector2.INF
	if from == Vector2.INF or _bench.dragging or _hand.is_dragging() or _swipe_seconds > swipe_max_seconds:
		return false
	var moved := button.position - from
	var along := moved.abs()
	var reach := swipe_distance * get_viewport().get_visible_rect().size.x
	var direction := Vector2i.ZERO
	if along.x >= reach and along.x >= along.y * swipe_axis_ratio:
		direction = Vector2i.RIGHT if moved.x > 0.0 else Vector2i.LEFT
	elif along.y >= reach and along.y >= along.x * swipe_axis_ratio:
		direction = Vector2i.DOWN if moved.y > 0.0 else Vector2i.UP
	if direction == Vector2i.ZERO:
		return false
	swiped.emit(direction)
	return true


# True when [param at], in pixels of the world buffer, is on the back strip with nothing clickable
# there, and nothing is being dragged.
func _back_strip_at(at: Vector2) -> bool:
	var view := get_viewport().get_visible_rect()
	if not view.has_point(at) or at.y < view.end.y - view.size.y * back_strip_height:
		return false
	var marker := view_marker(Game.view)
	if marker == null or marker.back == &"" or marker.screen not in [ViewMarker.Screen.NONE, ViewMarker.Screen.WORKVIEW]:
		return false
	if _read_open or _bench.dragging or _hand.is_dragging() or _hand.covers(at):
		return false
	return _clickable_at(at) == null and not _post_it_at(at)


# True when [param at], in pixels of the world buffer, is in the Workview, off every computer, with
# nothing clickable there, and nothing is being dragged.
func _empty_workview_at(at: Vector2) -> bool:
	if Game.view != WORKVIEW or _read_open or _bench.dragging or _hand.is_dragging() or _hand.covers(at):
		return false
	return _clickable_at(at) == null and not _post_it_at(at) and _job_at(at) == null


# True when [param at], in pixels of the world buffer, is on the pinned post-it, which a click brings
# up close.
func _post_it_at(at: Vector2) -> bool:
	var post_it := pinned_post_it()
	if post_it == null or _read_open or _bench.dragging or _hand.is_dragging() or _hand.covers(at):
		return false
	return post_it_rect(post_it).has_point(at)


# Moves the pinned post-it up close ([param open]) or back onto its computer.
func _read(open: bool) -> void:
	var post_it := pinned_post_it() if open else _read_post_it
	if post_it != _read_post_it and _read_post_it != null:
		_place_read_post_it(0.0)  # another post-it still on its way back lands at once
	if post_it != _read_post_it:
		_read_post_it = post_it
		_read_rest = post_it.transform
	_read_open = open
	if _read_tween != null:
		_read_tween.kill()
	var target := 1.0 if open else 0.0
	_read_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_read_tween.tween_method(_place_read_post_it, _read_weight, target, post_it_read_seconds * absf(target - _read_weight))
	if not open:
		_read_tween.tween_callback(func() -> void: _read_post_it = null)


# Puts the post-it [param t] of the way from its computer (0) to the Workview camera (1).
func _place_read_post_it(t: float) -> void:
	_read_weight = t
	if not is_instance_valid(_read_post_it):
		return
	var rest := _read_post_it.get_parent_node_3d().global_transform * _read_rest
	var up_close := view_marker(WORKVIEW).global_transform.translated_local(Vector3(0.0, 0.0, -post_it_read_distance))
	_read_post_it.global_transform = rest.interpolate_with(up_close, t)


## The hotspot that a click at [param at], in pixels of the world buffer, would click, or null.
func hotspot_at(at: Vector2) -> Hotspot:
	return _clickable_at(at) as Hotspot


# What physics picking would click at [param at], in pixels of the world buffer: the nearest
# input_ray_pickable CollisionObject3D under it, or null.
func _clickable_at(at: Vector2) -> CollisionObject3D:
	var from := _camera.project_ray_origin(at)
	var query := PhysicsRayQueryParameters3D.create(from, from + _camera.project_ray_normal(at) * _camera.far)
	query.collide_with_areas = true
	var space := get_world_3d().direct_space_state
	var skipped: Array[RID] = []
	for _attempt: int in 16:
		query.exclude = skipped
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return null
		var object := hit.collider as CollisionObject3D
		if object != null and object.input_ray_pickable:
			return object
		skipped.append(hit.rid)
	return null


func _sync() -> void:
	var jumped := Game.jump != _heard_jump
	_heard_jump = Game.jump
	_job_slots.show_jobs(Game.jobs, jumped)
	for hotspot: Hotspot in _view_hotspots:
		hotspot.set_enabled(hotspot.view != Game.view)
	if _read_open and pinned_post_it() != _read_post_it:
		_read(false)  # the player turned away or the computer left focus
	_play_changes(jumped)
	_pipedream.warp = Game.warp
	_the_end.ended = Game.ending() == &"pipes"
	if _bench.dragging and Game.view != _shown_view:
		_let_go_of_plug()  # before lay_cable below, which leaves a held plug where it is
	# Deferred: a computer turns to lie or stand on the same change, and the cable must reach its new socket;
	# the socket is looked up then, as a computer that leaves meanwhile frees its own.
	_lay_cable.call_deferred()
	var workview_moved := _follow_focus()
	if Game.view != _shown_view or (workview_moved and Game.view == WORKVIEW):
		_move_camera(Game.view)
	_body.visible = Game.visitor != null
	_body.show_customer(Game.visitor)
	_body.carrying = Game.visitor_carries()
	_visitor_hotspot.set_enabled(Game.visitor_state == Game.VisitorState.WAITING)
	match Game.visitor_state:
		Game.VisitorState.WALKING_IN:
			if _walk_in_arrival != Game.arrival:
				_walk_in()
		Game.VisitorState.POPPING_UP:
			if _pop_up_arrival != Game.arrival:
				_pop_up()
		Game.VisitorState.NONE, Game.VisitorState.TALKING, Game.VisitorState.WAITING:
			# A restore can end a walk or a pop-up halfway; its tween must not reach Game.
			if _walk_tween != null:
				_walk_tween.kill()
			_body.pose = &""
			_body.rotation = Vector3.ZERO
			_body.position = Vector3.ZERO
			_follow.progress_ratio = 1.0
		Game.VisitorState.WALKING_OUT, Game.VisitorState.OUTSIDE:
			if _walk_out_arrival != Game.arrival:
				_walk_out(Game.visitor_state == Game.VisitorState.OUTSIDE)
	_phone_hotspot.set_enabled(Game.can_call() or (Game.can_open() and Game.next_to_call() != null))
	_sync_phone()
	var calling := Game.phase == Game.Phase.CALLING
	if calling and not _calling:
		_phone_receiver.play()
	_calling = calling


func _move_camera(view_name: StringName) -> void:
	var marker := view_marker(view_name)
	if marker == null:
		return
	var first := _shown_view == &""
	_shown_view = view_name
	if _camera_tween != null:
		_camera_tween.kill()
	if first:
		_camera.global_transform = marker.global_transform
		_camera.view_fov = marker.fov
		return
	var seconds := marker.turn_seconds if marker.turn_seconds > 0.0 else turn_seconds
	_camera_seconds = seconds
	_camera_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_parallel()
	_camera_tween.tween_property(_camera, "global_position", marker.global_position, seconds)
	_camera_tween.tween_property(_camera, "quaternion", marker.global_basis.get_rotation_quaternion(), seconds)
	_camera_tween.tween_property(_camera, "view_fov", marker.fov, seconds)


## Moves the Workview marker to the eye of the computer in focus, standing or lying. True when it
## moved.
func _follow_focus() -> bool:
	var lying := Game.focus != null and Game.focus.lying
	if Game.focus == _workview_job and lying == _workview_lying:
		return false
	_workview_job = Game.focus
	_workview_lying = lying
	if Game.focus == null:
		return false
	var marker := view_marker(WORKVIEW)
	if marker == null:
		return false
	marker.global_transform = _job_slots.workview_transform(Game.focus, marker.global_transform)
	return true


func _walk_in() -> void:
	_walk_in_arrival = Game.arrival
	if _walk_tween != null:
		_walk_tween.kill()
	_body.rotation.y = 0.0
	_body.position = Vector3.ZERO
	_path.curve = _alley_paths[Game.visitor_from]
	_follow.progress_ratio = 0.0
	var door := _door_ratio()
	_walk_tween = create_tween()
	_walk_tween.tween_property(_follow, "progress_ratio", door, walk_seconds * door)
	_walk_tween.tween_callback(_door_bell.play)
	_walk_tween.tween_property(_follow, "progress_ratio", 1.0, walk_seconds * (1.0 - door))
	_walk_tween.finished.connect(Game.customer_arrived)


# The customer of an event rises behind the counter at the PopUpSpot, the view and the body shake,
# and after a moment they step to their place at the counter. The rise waits until the view has
# turned, so the player sees it.
func _pop_up() -> void:
	_pop_up_arrival = Game.arrival
	if _walk_tween != null:
		_walk_tween.kill()
	_follow.progress_ratio = 1.0
	_body.rotation = Vector3.ZERO
	var event := Game.matching_conversation(Game.errand, Conversation.Trigger.EVENT)
	_body.pose = event.pop_up.mood if event != null and event.pop_up != null else &""
	var top := _pop_up_spot.global_position if Game.view != WORKVIEW else _peek_spot()
	_body.global_position = top + Vector3.DOWN * pop_up_depth
	_walk_tween = create_tween()
	if _camera_tween != null and _camera_tween.is_running():
		_walk_tween.tween_interval(maxf(_camera_seconds - _camera_tween.get_total_elapsed_time(), 0.0))
	_walk_tween.tween_property(_body, "global_position", top, pop_up_seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_walk_tween.tween_callback(_shake_view.bind(pop_up_shake_metres, pop_up_shake_seconds))
	# A wobble, not a shift: the body walks whenever it moves across the ground.
	_walk_tween.tween_method(func(left: float) -> void:
		_body.rotation.z = deg_to_rad(pop_up_wobble_degrees) * left * sin(left * 40.0), 1.0, 0.0, pop_up_shake_seconds)
	_walk_tween.tween_interval(pop_up_stay_seconds)
	_walk_tween.tween_callback(_body.set.bind(&"pose", &""))
	_walk_tween.tween_property(_body, "position", Vector3.ZERO, pop_up_step_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_walk_tween.finished.connect(Game.customer_arrived)


# Where the body stands for its face to show at pop_up_peek_at in the Workview, as far back as the
# PopUpSpot; the feet sink through the floor behind the counter.
func _peek_spot() -> Vector3:
	var marker := view_marker(WORKVIEW)
	var half := ViewCamera.design_tangents(marker.fov)
	var across := marker.global_basis.x * half.x * pop_up_peek_at.x + marker.global_basis.y * half.y * pop_up_peek_at.y
	var ray := (-marker.global_basis.z + across).normalized()
	var from := marker.global_position
	var face := from + ray * ((_pop_up_spot.global_position.z - from.z) / ray.z)
	return Vector3(face.x, face.y - head_height, face.z)


## Debug: ends the customer's walk in or out at once, as if it had run its course. False when
## nobody is walking.
func skip_walk() -> bool:
	if _walk_tween == null or not _walk_tween.is_running():
		return false
	_walk_tween.custom_step(1e6)
	return true


# The path runs from the door to the counter, so the visitor turns around and walks it backwards.
# [param outside] starts at the door, past it, as a restore of an OUTSIDE visitor does.
func _walk_out(outside: bool = false) -> void:
	_walk_out_arrival = Game.arrival
	if _walk_tween != null:
		_walk_tween.kill()
	_path.curve = _alley_paths[Game.visitor_to]
	var door := _door_ratio()
	_walk_tween = create_tween()
	if outside:
		_body.rotation.y = PI
		_follow.progress_ratio = door
	else:
		_follow.progress_ratio = 1.0
		_walk_tween.tween_property(_body, "rotation:y", PI, about_face_seconds)
		_walk_tween.tween_property(_follow, "progress_ratio", door, walk_seconds * (1.0 - door))
		_walk_tween.tween_callback(_door_bell.play)
		_walk_tween.tween_callback(Game.customer_out_the_door)
	_walk_tween.tween_property(_follow, "progress_ratio", 0.0, walk_seconds * door)
	_walk_tween.finished.connect(Game.customer_left)


func _set_phone_hovered(on: bool) -> void:
	_phone_hovered = on
	_sync_phone()


func _sync_phone() -> void:
	var callable := not Game.phone_off_hook and Game.can_call()
	_phone_body.material_overlay = null if not callable else (_phone_outline if _phone_hovered else _phone_pulse_outline)
	if callable == (_phone_pulse != null):
		return
	if _phone_pulse != null:
		_phone_pulse.kill()
		_phone_pulse = null
	if callable:
		_phone_pulse = phone_outline.pulse(_phone_pulse_outline, self)


## The progress ratio of the customer path where it passes under the door bell.
func _door_ratio() -> float:
	return _path.curve.get_closest_offset(_path.to_local(_door_bell.global_position)) / _path.curve.get_baked_length()


# [param curve] mirrored across the path's x = 0, which runs through the door.
static func _mirrored(curve: Curve3D) -> Curve3D:
	var mirror := curve.duplicate() as Curve3D
	var flip := Vector3(-1.0, 1.0, 1.0)
	for i: int in curve.point_count:
		mirror.set_point_position(i, curve.get_point_position(i) * flip)
		mirror.set_point_in(i, curve.get_point_in(i) * flip)
		mirror.set_point_out(i, curve.get_point_out(i) * flip)
		mirror.set_point_tilt(i, -curve.get_point_tilt(i))
	return mirror


func _on_hotspot_clicked(hotspot: Hotspot) -> void:
	match hotspot.action:
		Hotspot.Action.GO_TO_VIEW:
			view_requested.emit(hotspot.view)
		Hotspot.Action.CALL_CUSTOMER:
			if Game.can_call():
				phone_requested.emit()
			elif Game.can_open() and Game.next_to_call() != null:
				_open_sign.shake()  # the phone can't call before the shop opens: point at the sign
		Hotspot.Action.TALK_TO_VISITOR:
			Game.talk_to_visitor()
		Hotspot.Action.POWER_WORK_COMPUTER:
			work_power_requested.emit()
		Hotspot.Action.TAKE_PART:
			if not Game.return_part(hotspot.part):
				Game.take_new_part(hotspot.part)


# The sound of [param piece] coming into or leaving the hand: its part's own, else [param usual].
func _handle_sound(piece: Piece, usual: SoundSet) -> SoundSet:
	return piece.part.handle_sound if piece.part.handle_sound != null else usual


# Plays the sound of each hand and cable change since the last sync, whatever made it, unless the
# state [param jumped] there.
func _play_changes(jumped: bool) -> void:
	if Game.hand != _heard_hand and not jumped:
		if _heard_hand == null:
			_handle_sound(Game.hand, part_take_sound).play_at(_hand)
		elif Game.hand == null:
			_handle_sound(_heard_hand, part_put_sound).play_at(_hand)
	_heard_hand = Game.hand
	if Game.connected != _heard_cable and not jumped:
		var old_socket := _job_slots.cable_socket(_heard_cable) if _heard_cable != null and _heard_cable in Game.jobs else null
		if old_socket != null:
			plug_out_sound.play_at(old_socket)
		if Game.connected != null:
			plug_in_sound.play_at(_job_slots.cable_socket(Game.connected))
	_heard_cable = Game.connected
	for job: Job in Game.jobs:
		if job.case_open and job not in _heard_open and not jumped and job.problem != null and job.problem.reveal_stab != null \
				and job.places.values().any(func(each: Piece) -> bool: return each.part in job.problem.stand_ins):
			job.problem.reveal_stab.play_at(_hand)
			_shake_view(stab_shake_metres, stab_shake_seconds)
	_heard_open.assign(Game.jobs.filter(func(job: Job) -> bool: return job.case_open))


# Jolts the view by [param metres], and lets it settle over [param seconds].
func _shake_view(metres: float, seconds: float) -> void:
	if _stab_shake != null:
		_stab_shake.kill()
	_stab_shake = create_tween()
	_stab_shake.tween_method(func(left: float) -> void:
		var shake := metres * left * left
		_camera.h_offset = randf_range(-shake, shake)
		_camera.v_offset = randf_range(-shake, shake), 1.0, 0.0, seconds)


func _on_plug_grabbed() -> void:
	_bench.dragging = true
	_grab_held = true
	Game.connect_cable(null)
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):  # a quick tap is released before physics picking reports the press
		_end_grab(_mouse)


# The release of the press that grabbed the plug, at [param at] in pixels of the world buffer: it
# ends a drag there, or keeps the plug in the hand after a click.
func _end_grab(at: Vector2) -> void:
	_grab_held = false
	if at.distance_to(_press_at) > plug_drag_threshold:
		_drop_plug(_job_at(at))
	else:
		_carry_plug(at)


func _carry_plug(at: Vector2) -> void:
	var from := _camera.project_ray_origin(at)
	var dir := _camera.project_ray_normal(at)
	_bench.drag_plug(from, dir)
	_job_slots.target(_job_slots.job_at(from, dir))


# The job whose computer is under [param at], in pixels of the world buffer, or null.
func _job_at(at: Vector2) -> Job:
	return _job_slots.job_at(_camera.project_ray_origin(at), _camera.project_ray_normal(at))


func _drop_plug(job: Job) -> void:
	_let_go_of_plug()
	Game.connect_cable(job)



func _lay_cable() -> void:
	_bench.lay_cable(_job_slots.cable_socket(Game.connected) if Game.connected != null else null)

func _let_go_of_plug() -> void:
	_bench.dragging = false
	_grab_held = false
	_job_slots.target(null)


# The cable and the Workview follow a computer that slides to another slot.
func _on_computer_moved(job: Job) -> void:
	if job == Game.connected:
		_bench.lay_cable(_job_slots.cable_socket(job))
	if job != Game.focus:
		return
	_workview_job = null
	if _follow_focus() and _shown_view == WORKVIEW and (_camera_tween == null or not _camera_tween.is_running()):
		_camera.global_transform = view_marker(WORKVIEW).global_transform


## Puts [param job] in focus and asks for the Workview, as a click on its computer does. Does nothing
## while [param job] is already in focus in the Workview.
func work_on(job: Job) -> void:
	if Game.view == WORKVIEW and job == Game.focus:
		return
	Game.focus_job(job)
	view_requested.emit(WORKVIEW)
