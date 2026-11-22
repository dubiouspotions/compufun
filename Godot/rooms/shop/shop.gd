class_name Shop
extends Node3D
## The shop room: the view markers, the hotspots and the customer path. It shows the Game state.

## A hotspot asks to go to a view.
signal view_requested(view: StringName)
## The player clicked the Open sign while [method Game.can_close] is true.
signal close_requested
## The end has played in the room: time for the bluescreen.
signal crashed
## The player picked up the phone, to call a customer. While the shop is closed and a computer is
## done, a click on the phone shakes the Open sign instead.
signal phone_requested
## The player pressed the Degauss button of the bench screen.
signal degauss_requested
## The player pressed the power button of the bench screen.
signal monitor_power_requested
## The mouse came onto the back strip ([param on] true) or left it (see [member back_strip_height]).
signal back_strip_hovered(on: bool)

## The close-up of the computer in focus.
const WORKVIEW: StringName = &"Workview"

## The seconds that the camera takes to move to another view.
@export var turn_seconds: float = 0.35
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
## How far in front of the Workview camera the post-it comes when the player clicks it, in metres.
@export var post_it_read_distance: float = 0.2
## The seconds that the post-it takes to come up close, and to go back onto the computer.
@export var post_it_read_seconds: float = 0.3

@onready var _camera: Camera3D = %Camera
@onready var _views: Node3D = %Views
@onready var _follow: PathFollow3D = %CustomerFollow
## How high the customer's head is above their feet, in metres, for the call-out's arrow.
@export var head_height: float = 1.6

@onready var _body: CustomerBody = %CustomerBody
@onready var _job_slots: JobSlots = %JobSlots
@onready var _bench: Bench = %Bench
@onready var _pipedream: Pipedream = %Pipedream
@onready var _work_monitor: CrtMonitor = %WorkMonitor
@onready var _work_tower: PcTower = $Room/WorkTower
@onready var _open_sign: OpenSign = %OpenSign
@onready var _door_bell: AudioStreamPlayer3D = %DoorBell
@onready var _phone_receiver: AudioStreamPlayer3D = %PhoneReceiver
@onready var _the_end: TheEnd = %TheEnd
@onready var _hand: Hand = %Hand

## Plays when a part comes into the player's hand, and when it leaves it (put in, on the mat, away).
@export var part_take_sound: SoundSet = preload("res://sounds/part_take.tres")
@export var part_put_sound: SoundSet = preload("res://sounds/part_put.tres")
## Plays at a computer's socket when the keyboard cable goes in, and when it comes out.
@export var plug_in_sound: SoundSet = preload("res://sounds/cable_plug_in.tres")
@export var plug_out_sound: SoundSet = preload("res://sounds/cable_plug_out.tres")

## Whether the work computer runs; its fans hum while it does.
var work_computer_running: bool = false:
	set(value):
		work_computer_running = value
		_work_tower.running = value

var _shown_view: StringName = &""
## What the hand held and where the cable was at the last sync, to hear what changed since.
var _heard_hand: Variant = null
var _heard_cable: Job
var _heard_jump: int = -1  # the Game.jump at the last sync: no change sounds over a jump
var _workview_job: Job
var _workview_lying: bool = false
var _walk_in_arrival: int = -1
var _walk_out_arrival: int = -1
var _walk_tween: Tween
var _calling: bool = false
var _camera_tween: Tween
var _mouse := Vector2(-1.0, -1.0)  # in pixels of the world buffer
var _press_at := Vector2(-1.0, -1.0)  # where the left button last went down, in pixels of the world buffer
var _grab_held: bool = false  # from the press that grabbed the plug until its release
var _on_back_strip: bool = false
var _over_post_it: bool = false
var _read_post_it: PostIt3D  # the post-it up close or on its way there or back, or null
var _read_rest: Transform3D  # its transform on the computer
var _read_weight: float = 0.0  # 0 on the computer, 1 up close
var _read_open: bool = false
var _read_tween: Tween
var _view_hotspots: Array[Hotspot] = []  # GO_TO_VIEW hotspots, off in their own view so the back strip and the cursor see past them


func _ready() -> void:
	for node: Node in find_children("*", "Area3D"):
		var hotspot := node as Hotspot
		if hotspot != null:
			hotspot.clicked.connect(_on_hotspot_clicked)
			if hotspot.action == Hotspot.Action.GO_TO_VIEW:
				_view_hotspots.append(hotspot)
	_job_slots.job_clicked.connect(_on_job_clicked)
	_job_slots.power_clicked.connect(func(job: Job) -> void: Game.set_powered(job, not job.powered))
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
	_open_sign.open_requested.connect(Game.open_shop)
	_open_sign.close_requested.connect(close_requested.emit)
	_bench.power_pressed.connect(monitor_power_requested.emit)
	Game.changed.connect(_sync)
	_sync()


## The view marker with this name, or null (with an error) when the room has none.
## Shows a part in the hand, then every view, to the camera for one frame each, so that the renderer
## compiles each shader now and not on the player's first turn or take (a first turn stalled for 100
## to 200 ms, a first take for 90 ms). The camera ends where it began. The loading screen awaits it
## while it still covers the game.
func warm_up() -> void:
	var home := _camera.global_transform
	var home_fov := _camera.fov
	await _hand.warm_up(Part.every()[0])
	for node: Node in _views.get_children():
		var marker := node as ViewMarker
		if marker == null:
			continue
		_camera.global_transform = marker.global_transform
		_camera.fov = marker.fov
		await RenderingServer.frame_post_draw
	_camera.global_transform = home
	_camera.fov = home_fov


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
	var size := _camera.get_viewport().get_visible_rect().size
	var half_width := atan(tan(deg_to_rad(_camera.fov) * 0.5) * size.x / size.y)
	return yaw / (2.0 * half_width)


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
	var mouse := event as InputEventMouse
	if mouse != null:
		_mouse = mouse.position
	var button := event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		_press_at = button.position


func _process(_delta: float) -> void:
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
# a drag, or the next click, plugs it into the computer under the mouse, or lays it down.
func _unhandled_input(event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	if press != null and press.pressed and press.button_index == MOUSE_BUTTON_LEFT and _post_it_at(press.position):
		get_viewport().set_input_as_handled()
		_read(true)
		return
	if press != null and press.pressed and press.button_index == MOUSE_BUTTON_LEFT and _back_strip_at(press.position):
		get_viewport().set_input_as_handled()
		view_requested.emit(view_marker(Game.view).back)
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
	_the_end.ended = Game.phase == Game.Phase.ENDED
	if _bench.dragging and Game.view != _shown_view:
		_let_go_of_plug()  # before lay_cable below, which leaves a held plug where it is
	# Deferred: a computer turns to lie or stand on the same change, and the cable must reach its new socket.
	_bench.lay_cable.call_deferred(_job_slots.cable_socket(Game.connected) if Game.connected != null else null)
	var workview_moved := _follow_focus()
	if Game.view != _shown_view or (workview_moved and Game.view == WORKVIEW):
		_move_camera(Game.view)
	_body.visible = Game.visitor != null
	_body.show_customer(Game.visitor)
	var leaving := Game.visitor_state == Game.VisitorState.WALKING_OUT
	# In with the computer on a drop-off, out with it on a pickup.
	_body.carrying = (Game.visit == Game.Visit.DROP_OFF) != leaving
	match Game.visitor_state:
		Game.VisitorState.WALKING_IN:
			if _walk_in_arrival != Game.arrival:
				_walk_in()
		Game.VisitorState.NONE, Game.VisitorState.TALKING:
			# A restore can end a walk halfway; its tween must not reach Game.
			if _walk_tween != null:
				_walk_tween.kill()
			_body.rotation.y = 0.0
			_follow.progress_ratio = 1.0
		Game.VisitorState.WALKING_OUT:
			if _walk_out_arrival != Game.arrival:
				_walk_out()
	var calling := Game.phase == Game.Phase.CALLING
	if calling and not _calling:
		_phone_receiver.play()
	_calling = calling


func _move_camera(view_name: StringName) -> void:
	var marker := view_marker(view_name)
	if marker == null:
		return
	var first := _shown_view == &""
	var from: ViewMarker = null if first else view_marker(_shown_view)
	_shown_view = view_name
	if _camera_tween != null:
		_camera_tween.kill()
	if first:
		_camera.global_transform = marker.global_transform
		_camera.fov = marker.fov
		return
	var seconds := marker.turn_seconds if marker.turn_seconds > 0.0 else turn_seconds
	var doorway := marker.doorway
	if doorway == null and from != null:
		doorway = from.doorway
	_camera_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_parallel()
	if doorway != null:
		_camera_tween.tween_method(_through_doorway(doorway, marker), 0.0, 1.0, seconds)
	else:
		_camera_tween.tween_property(_camera, "global_position", marker.global_position, seconds)
		_camera_tween.tween_property(_camera, "quaternion", marker.global_basis.get_rotation_quaternion(), seconds)
	_camera_tween.tween_property(_camera, "fov", marker.fov, seconds)


# The camera's move from where it is now to [param marker] through [param doorway], as a function of
# the progress from 0 to 1: straight through the doorway along its Z axis, turned as the doorway is
# there, so it never cuts through the wall beside it.
func _through_doorway(doorway: Node3D, marker: ViewMarker) -> Callable:
	var start := _camera.global_position
	var door := doorway.global_position
	var end := marker.global_position
	var axis := doorway.global_basis.z.normalized()
	var handle := axis * signf((start - door).dot(axis)) * minf(start.distance_to(door), door.distance_to(end)) * 0.5
	var path := Curve3D.new()
	path.add_point(start)
	path.add_point(door, handle, -handle)
	path.add_point(end)
	var length := path.get_baked_length()
	var door_at := path.get_closest_offset(door) / length
	var turned_from := _camera.quaternion
	var turned_at_door := doorway.global_basis.get_rotation_quaternion()
	var turned_to := marker.global_basis.get_rotation_quaternion()
	return func(progress: float) -> void:
		_camera.global_position = path.sample_baked(progress * length)
		if progress < door_at:
			_camera.quaternion = turned_from.slerp(turned_at_door, smoothstep(0.0, door_at, progress))
		else:
			_camera.quaternion = turned_at_door.slerp(turned_to, smoothstep(door_at, 1.0, progress))


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
	_follow.progress_ratio = 0.0
	var door := _door_ratio()
	_walk_tween = create_tween()
	_walk_tween.tween_property(_follow, "progress_ratio", door, walk_seconds * door)
	_walk_tween.tween_callback(_door_bell.play)
	_walk_tween.tween_property(_follow, "progress_ratio", 1.0, walk_seconds * (1.0 - door))
	_walk_tween.finished.connect(Game.customer_arrived)


## Debug: ends the customer's walk in or out at once, as if it had run its course. False when
## nobody is walking.
func skip_walk() -> bool:
	if _walk_tween == null or not _walk_tween.is_running():
		return false
	_walk_tween.custom_step(1e6)
	return true


# The path runs from the door to the counter, so the visitor turns around and walks it backwards.
func _walk_out() -> void:
	_walk_out_arrival = Game.arrival
	if _walk_tween != null:
		_walk_tween.kill()
	_follow.progress_ratio = 1.0
	_walk_tween = create_tween()
	_walk_tween.tween_property(_body, "rotation:y", PI, about_face_seconds)
	var door := _door_ratio()
	_walk_tween.tween_property(_follow, "progress_ratio", door, walk_seconds * (1.0 - door))
	_walk_tween.tween_callback(_door_bell.play)
	_walk_tween.tween_property(_follow, "progress_ratio", 0.0, walk_seconds * door)
	_walk_tween.finished.connect(Game.customer_left)


## The progress ratio of the customer path where it passes under the door bell.
func _door_ratio() -> float:
	var path := _follow.get_parent() as Path3D
	return path.curve.get_closest_offset(path.to_local(_door_bell.global_position)) / path.curve.get_baked_length()


func _on_hotspot_clicked(hotspot: Hotspot) -> void:
	match hotspot.action:
		Hotspot.Action.GO_TO_VIEW:
			view_requested.emit(hotspot.view)
		Hotspot.Action.CALL_CUSTOMER:
			if Game.can_open() and Game.next_to_call() != null:
				_open_sign.shake()  # the phone can't call before the shop opens: point at the sign
			else:
				phone_requested.emit()
		Hotspot.Action.TAKE_PART:
			if Game.hand == null:
				Game.take_new_part(hotspot.part)
			else:
				Game.return_part(hotspot.part)


# Plays the sound of each hand and cable change since the last sync, whatever made it, unless the
# state [param jumped] there.
func _play_changes(jumped: bool) -> void:
	if Game.hand != _heard_hand and not jumped:
		if _heard_hand == null:
			part_take_sound.play_at(_hand)
		elif Game.hand == null:
			part_put_sound.play_at(_hand)
	_heard_hand = Game.hand
	if Game.connected != _heard_cable and not jumped:
		var old_socket := _job_slots.cable_socket(_heard_cable) if _heard_cable != null and _heard_cable in Game.jobs else null
		if old_socket != null:
			plug_out_sound.play_at(old_socket)
		if Game.connected != null:
			plug_in_sound.play_at(_job_slots.cable_socket(Game.connected))
	_heard_cable = Game.connected


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


func _let_go_of_plug() -> void:
	_bench.dragging = false
	_grab_held = false
	_job_slots.target(null)


func _on_job_clicked(job: Job) -> void:
	if Game.view == WORKVIEW and job == Game.focus:
		return
	Game.focus_job(job)
	view_requested.emit(WORKVIEW)
