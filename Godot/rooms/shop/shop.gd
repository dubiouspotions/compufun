class_name Shop
extends Node3D
## The shop room: the view markers, the hotspots and the customer path. It shows the Game state.

## A hotspot asks to go to a view.
signal view_requested(view: StringName)

## The seconds that the camera takes to move to another view.
@export var turn_seconds: float = 0.35
## The seconds that a customer takes from the alley to the counter.
@export var walk_seconds: float = 7.0

@onready var _camera: Camera3D = %Camera
@onready var _views: Node3D = %Views
@onready var _follow: PathFollow3D = %CustomerFollow
@onready var _body: CustomerBody = %CustomerBody
@onready var _counter_computer: Hotspot = %CounterComputer
@onready var _bench_monitor: CrtMonitor = %BenchMonitor
@onready var _open_sign: OpenSign = %OpenSign
@onready var _door_bell: AudioStreamPlayer3D = %DoorBell
@onready var _phone_receiver: AudioStreamPlayer3D = %PhoneReceiver

var _shown_view: StringName = &""
var _walking: bool = false
var _calling: bool = false
var _camera_tween: Tween


func _ready() -> void:
	for node: Node in find_children("*", "Area3D"):
		var hotspot := node as Hotspot
		if hotspot != null:
			hotspot.clicked.connect(_on_hotspot_clicked)
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


## The screen of the CRT on the counter as the camera sees it now, in pixels of the world buffer.
func bench_screen_rect() -> Rect2:
	var corners := _bench_monitor.screen_corners()
	var rect := Rect2(_camera.unproject_position(corners[0]), Vector2.ZERO)
	for corner: Vector3 in corners:
		rect = rect.expand(_camera.unproject_position(corner))
	return rect


## Shows [param texture] (the screen buffer) on the CRT on the counter.
func set_desktop_texture(texture: Texture2D) -> void:
	_bench_monitor.set_screen_texture(texture)


func _sync() -> void:
	if Game.view != _shown_view:
		_move_camera(Game.view)
	_counter_computer.set_enabled(Game.focus != null)
	_body.visible = Game.visitor != null
	_body.show_customer(Game.visitor)
	_body.carrying = Game.visit == Game.Visit.DROP_OFF
	var walking := Game.visitor_state == Game.VisitorState.WALKING_IN
	if walking and not _walking:
		_walk_in()
	_walking = walking
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


func _walk_in() -> void:
	_door_bell.play()
	_follow.progress_ratio = 0.0
	var tween := create_tween()
	tween.tween_property(_follow, "progress_ratio", 1.0, walk_seconds)
	tween.finished.connect(Game.customer_arrived)


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
