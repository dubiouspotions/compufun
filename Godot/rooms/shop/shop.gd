class_name Shop
extends Node3D
## The shop room: the view markers, the hotspots and the customer path. It shows the Game state.

## A hotspot asks to go to a view.
signal view_requested(view: StringName)

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
@onready var _open_sign: OpenSign = %OpenSign
@onready var _door_bell: AudioStreamPlayer3D = %DoorBell
@onready var _phone_receiver: AudioStreamPlayer3D = %PhoneReceiver

var _shown_view: StringName = &""
var _workview_job: Job
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
	Game.changed.connect(_sync)
	_sync()


## The view marker with this name, or null (with an error) when the room has none.
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


## The bench screen as the camera sees it now, in pixels of the world buffer.
func bench_screen_rect() -> Rect2:
	var corners := _bench.screen_corners()
	var rect := Rect2(_camera.unproject_position(corners[0]), Vector2.ZERO)
	for corner: Vector3 in corners:
		rect = rect.expand(_camera.unproject_position(corner))
	return rect


## Shows [param texture] (the screen buffer) on the bench screen.
func set_desktop_texture(texture: Texture2D) -> void:
	_bench.set_screen_texture(texture)


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
	_job_slots.show_jobs(Game.jobs, null if Game.view == WORKVIEW else Game.focus)  # the Workview centres it already
	_bench.lay_cable(_job_slots.cable_socket(Game.connected) if Game.connected != null else null)
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
		Game.VisitorState.TALKING:
			# A restore can skip the walk; the visitor still stands at the counter.
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
	_camera_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_parallel()
	_camera_tween.tween_property(_camera, "global_position", marker.global_position, turn_seconds)
	_camera_tween.tween_property(_camera, "quaternion", marker.global_basis.get_rotation_quaternion(), turn_seconds)
	_camera_tween.tween_property(_camera, "fov", marker.fov, turn_seconds)


## Moves the Workview marker to the computer in focus. True when it moved.
func _follow_focus() -> bool:
	if Game.focus == _workview_job:
		return false
	_workview_job = Game.focus
	if Game.focus == null:
		return false
	var marker := view_marker(WORKVIEW)
	if marker == null:
		return false
	marker.global_transform = _job_slots.workview_transform(Game.focus, marker.global_transform)
	return true


func _walk_in() -> void:
	_walk_in_arrival = Game.arrival
	_door_bell.play()
	if _walk_tween != null:
		_walk_tween.kill()
	_body.rotation.y = 0.0
	_follow.progress_ratio = 0.0
	_walk_tween = create_tween()
	_walk_tween.tween_property(_follow, "progress_ratio", 1.0, walk_seconds)
	_walk_tween.finished.connect(Game.customer_arrived)


# The path runs from the door to the counter, so the visitor turns around and walks it backwards.
func _walk_out() -> void:
	_walk_out_arrival = Game.arrival
	if _walk_tween != null:
		_walk_tween.kill()
	_follow.progress_ratio = 1.0
	_walk_tween = create_tween()
	_walk_tween.tween_property(_body, "rotation:y", PI, about_face_seconds)
	_walk_tween.tween_property(_follow, "progress_ratio", 0.0, walk_seconds)
	_walk_tween.finished.connect(Game.customer_left)


func _on_hotspot_clicked(hotspot: Hotspot) -> void:
	match hotspot.action:
		Hotspot.Action.GO_TO_VIEW:
			view_requested.emit(hotspot.view)
		Hotspot.Action.CALL_CUSTOMER:
			Game.call_customer()
		Hotspot.Action.CLOSE_SHOP:
			if Game.can_close():
				Game.close_shop()
			else:
				_open_sign.wobble()


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
	Game.focus_job(job)
	view_requested.emit(WORKVIEW)
