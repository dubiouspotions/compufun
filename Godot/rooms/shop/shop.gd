class_name Shop
extends Node3D
## The shop room: the view markers, the hotspots and the customer path. It shows the Game state.

## A hotspot asks to go to a view.
signal view_requested(view: StringName)
## The player clicked the Open sign while [method Game.can_close] is true.
signal close_requested
## The end has played in the room: time for the bluescreen.
signal crashed
## The player picked up the phone, to call a customer.
signal phone_requested
## The player pressed the Degauss button of the bench screen.
signal degauss_requested
## The player pressed the power button of the bench screen.
signal monitor_power_requested

## The close-up of the computer in focus.
const WORKVIEW: StringName = &"Workview"

## The seconds that the camera takes to move to another view.
@export var turn_seconds: float = 0.35
## The seconds that a customer takes from the alley to the counter, and back.
@export var walk_seconds: float = 7.0
## The seconds that a customer takes to turn around at the counter before walking out.
@export var about_face_seconds: float = 0.4

@onready var _camera: Camera3D = %Camera
@onready var _views: Node3D = %Views
@onready var _follow: PathFollow3D = %CustomerFollow
@onready var _body: CustomerBody = %CustomerBody
@onready var _job_slots: JobSlots = %JobSlots
@onready var _bench: Bench = %Bench
@onready var _pipedream: Pipedream = %Pipedream
@onready var _work_monitor: CrtMonitor = %WorkMonitor
@onready var _open_sign: OpenSign = %OpenSign
@onready var _door_bell: AudioStreamPlayer3D = %DoorBell
@onready var _phone_receiver: AudioStreamPlayer3D = %PhoneReceiver
@onready var _the_end: TheEnd = %TheEnd
@onready var _hand: Hand = %Hand
@onready var _trash_can: TrashCan = %TrashCan

## Plays when a part comes into the player's hand, and when it leaves it (put in, on the mat, away).
@export var part_take_sound: SoundSet = preload("res://sounds/part_take.tres")
@export var part_put_sound: SoundSet = preload("res://sounds/part_put.tres")
## Plays at a computer's socket when the keyboard cable goes in, and when it comes out.
@export var plug_in_sound: SoundSet = preload("res://sounds/cable_plug_in.tres")
@export var plug_out_sound: SoundSet = preload("res://sounds/cable_plug_out.tres")

var _shown_view: StringName = &""
## What the hand held and where the cable was at the last sync, to hear what changed since.
var _heard_hand: Variant = null
var _heard_cable: Job
var _workview_job: Job
var _workview_lying: bool = false
var _walk_in_arrival: int = -1
var _walk_out_arrival: int = -1
var _walk_tween: Tween
var _calling: bool = false
var _camera_tween: Tween


func _ready() -> void:
	for node: Node in find_children("*", "Area3D"):
		var hotspot := node as Hotspot
		if hotspot != null:
			hotspot.clicked.connect(_on_hotspot_clicked)
	_job_slots.job_clicked.connect(_on_job_clicked)
	_job_slots.power_clicked.connect(func(job: Job) -> void: Game.set_powered(job, not job.powered))
	_bench.view_requested.connect(view_requested.emit)
	_bench.plug_grabbed.connect(_on_plug_grabbed)
	_the_end.view_requested.connect(view_requested.emit)
	_the_end.crashed.connect(crashed.emit)
	_bench.degauss_pressed.connect(degauss_requested.emit)
	_trash_can.trash_requested.connect(Game.trash_part)
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


## The paper of [param post_it] as the camera sees it now: the rect around its corners, in pixels
## of the world buffer. Empty while a corner is behind the camera, as during a turn.
func post_it_rect(post_it: PostIt3D) -> Rect2:
	var corners := post_it.paper_corners()
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


# The dragged plug follows the mouse; the release plugs it into the computer under the mouse, or lays it down.
func _unhandled_input(event: InputEvent) -> void:
	var mouse := event as InputEventMouse
	if not _bench.dragging or mouse == null:
		return
	var from := _camera.project_ray_origin(mouse.position)
	var dir := _camera.project_ray_normal(mouse.position)
	var job := _job_slots.job_at(from, dir)
	var button := mouse as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT and not button.pressed:
		_drop_plug(job)
		return
	_bench.drag_plug(from, dir)
	_job_slots.target(job)


func _sync() -> void:
	_job_slots.show_jobs(Game.jobs)
	_play_changes()
	_pipedream.warp = Game.warp
	_the_end.ended = Game.phase == Game.Phase.ENDED
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
	_shown_view = view_name
	if _camera_tween != null:
		_camera_tween.kill()
	if first:
		_camera.global_transform = marker.global_transform
		_camera.fov = marker.fov
		return
	var seconds := marker.turn_seconds if marker.turn_seconds > 0.0 else turn_seconds
	_camera_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_parallel()
	_camera_tween.tween_property(_camera, "global_position", marker.global_position, seconds)
	_camera_tween.tween_property(_camera, "quaternion", marker.global_basis.get_rotation_quaternion(), seconds)
	_camera_tween.tween_property(_camera, "fov", marker.fov, seconds)


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
			phone_requested.emit()
		Hotspot.Action.CLOSE_SHOP:
			if Game.can_close():
				close_requested.emit()
			else:
				_open_sign.wobble()
		Hotspot.Action.TAKE_PART:
			Game.take_new_part(hotspot.part)


# Plays the sound of each hand and cable change since the last sync, whatever made it.
func _play_changes() -> void:
	if Game.hand != _heard_hand:
		if _heard_hand == null:
			part_take_sound.play_at(self)
		elif Game.hand == null:
			part_put_sound.play_at(self)
		_heard_hand = Game.hand
	if Game.connected != _heard_cable:
		var old_socket := _job_slots.cable_socket(_heard_cable) if _heard_cable != null and _heard_cable in Game.jobs else null
		if old_socket != null:
			plug_out_sound.play_at(old_socket)
		if Game.connected != null:
			plug_in_sound.play_at(_job_slots.cable_socket(Game.connected))
		_heard_cable = Game.connected


func _on_plug_grabbed() -> void:
	_bench.dragging = true
	Game.connect_cable(null)
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):  # a quick tap is released before physics picking reports the press
		_drop_plug(null)


func _drop_plug(job: Job) -> void:
	_bench.dragging = false
	_job_slots.target(null)
	Game.connect_cable(job)


func _on_job_clicked(job: Job) -> void:
	if Game.view == WORKVIEW and job == Game.focus:
		Game.lay_down(job)
		return
	Game.focus_job(job)
	view_requested.emit(WORKVIEW)
