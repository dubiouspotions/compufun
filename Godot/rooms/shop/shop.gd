class_name Shop
extends Node3D
## The shop room: the view markers, the hotspots and the customer path. It shows the Game state.

## A hotspot asks to go to a view.
signal view_requested(view: StringName)

## The seconds that the camera takes to move to another view.
@export var turn_seconds: float = 0.35
## The seconds that a customer takes from the street to the counter.
@export var walk_seconds: float = 4.0

@onready var _camera: Camera3D = %Camera
@onready var _views: Node3D = %Views
@onready var _follow: PathFollow3D = %CustomerFollow
@onready var _body: CustomerBody = %CustomerBody
@onready var _counter_computer: Hotspot = %CounterComputer
@onready var _bench_monitor: CrtMonitor = %BenchMonitor

var _shown_view: StringName = &""
var _walk_index: int = -1
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


## Shows [param texture] (the screen buffer) on the CRT on the counter.
func set_desktop_texture(texture: Texture2D) -> void:
	_bench_monitor.set_screen_texture(texture)


func _sync() -> void:
	if Game.view != _shown_view:
		_move_camera(Game.view)
	_counter_computer.set_enabled(Game.phase == Game.Phase.REPAIR or Game.phase == Game.Phase.CALLING)
	_body.visible = Game.phase == Game.Phase.WALKING_IN or Game.phase == Game.Phase.TALKING
	_body.show_customer(Game.customer)
	if Game.phase == Game.Phase.WALKING_IN and _walk_index != Game.customer_index:
		_walk_in()


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
	_walk_index = Game.customer_index
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
