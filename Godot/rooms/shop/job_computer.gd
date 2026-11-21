class_name JobComputer
extends Node3D
## The computer of one job on the counter. JobSlots places one at each job's slot. It outlines
## itself while the mouse is over it and while its job is in focus.

## The player clicked the computer.
signal clicked(computer: JobComputer)

## The outline colour while the job is in focus.
@export var focus_color: Color = Color(1.0, 0.82, 0.2)
## The outline colour while the mouse is over the computer and its job is not in focus.
@export var hover_color: Color = Color(0.75, 0.9, 1.0)

## The job that this computer shows. Set once, before the computer enters the tree.
var job: Job
## True while the job is in [member Game.focus]. JobSlots sets it.
var focused: bool = false:
	set(value):
		focused = value
		if is_node_ready():
			_sync_outline()

var _hovered: bool = false

@onready var _hotspot: Hotspot = %Hotspot
@onready var _outline: MeshInstance3D = %Outline
@onready var _workview_eye: Marker3D = %WorkviewEye
@onready var _cable_socket: Marker3D = %CableSocket
@onready var _post_it: PostIt3D = %PostIt


func _ready() -> void:
	_hotspot.clicked.connect(func(_h: Hotspot) -> void: clicked.emit(self))
	_hotspot.mouse_entered.connect(_set_hovered.bind(true))
	_hotspot.mouse_exited.connect(_set_hovered.bind(false))
	_post_it.job = job
	_sync_outline()


## Where the Workview camera looks at this computer from, in world space.
func workview_transform() -> Transform3D:
	return _workview_eye.global_transform


## The VGA socket that the bench cable plugs into; its +Z points out of the socket.
func cable_socket() -> Node3D:
	return _cable_socket


## Stops taking clicks, before the computer leaves the counter.
func disable() -> void:
	_hotspot.set_enabled(false)


func _set_hovered(on: bool) -> void:
	_hovered = on
	_sync_outline()


func _sync_outline() -> void:
	_outline.visible = focused or _hovered
	(_outline.material_override as StandardMaterial3D).albedo_color = focus_color if focused else hover_color
