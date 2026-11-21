class_name JobComputer
extends Node3D
## The computer of one job on the counter. JobSlots places one at each job's slot. It outlines
## itself while the mouse is over it, while its job is in focus, and while the cable's plug is dragged
## over it. Its power button reports clicks, and its power light shows whether the job is on.

## The player clicked the computer.
signal clicked(computer: JobComputer)
## The player clicked the computer's power button.
signal power_clicked(computer: JobComputer)

## The outline colour while the job is in focus.
@export var focus_color: Color = Color(1.0, 0.82, 0.2)
## The outline colour while the mouse or the dragged plug is over the computer.
@export var hover_color: Color = Color(0.75, 0.9, 1.0)
## The power light's colour while the computer is on, and while it is off.
@export var power_on_color: Color = Color(0.3, 1.0, 0.3)
@export var power_off_color: Color = Color(0.08, 0.16, 0.08)

## The job that this computer shows. Set once, before the computer enters the tree.
var job: Job
## True while the job is in [member Game.focus]. JobSlots sets it.
var focused: bool = false:
	set(value):
		focused = value
		if is_node_ready():
			_sync_outline()

## True while the player drags the cable's plug over this computer. JobSlots sets it.
var targeted: bool = false:
	set(value):
		targeted = value
		if is_node_ready():
			_sync_outline()

## True while the job is on (Job.powered); the power light shows it. JobSlots sets it.
var powered: bool = false:
	set(value):
		powered = value
		if is_node_ready():
			_sync_power_light()

var _hovered: bool = false

@onready var _tower: PcTower = $Tower
@onready var _hotspot: Hotspot = %Hotspot
@onready var _outline: MeshInstance3D = %Outline
@onready var _workview_eye: Marker3D = %WorkviewEye
@onready var _cable_socket: Marker3D = %CableSocket
@onready var _post_it: PostIt3D = %PostIt
@onready var _power_hotspot: Hotspot = %PowerHotspot
@onready var _power_light: MeshInstance3D = %PowerLight
@onready var _tower: Node3D = $Tower
@onready var _post_it_anchor: Node3D = $PostItAnchor
@onready var _open_case: OpenCase = %OpenCase


func _ready() -> void:
	_hotspot.clicked.connect(func(_h: Hotspot) -> void: clicked.emit(self))
	_hotspot.mouse_entered.connect(_set_hovered.bind(true))
	_hotspot.mouse_exited.connect(_set_hovered.bind(false))
	_power_hotspot.clicked.connect(func(_h: Hotspot) -> void: power_clicked.emit(self))
	_tower.dress(job.customer.computer)
	_post_it.job = job
	_open_case.job = job
	Game.changed.connect(_sync_case)
	_sync_case()
	_sync_outline()
	_sync_power_light()


## Where the Workview camera looks at this computer from, in world space.
func workview_transform() -> Transform3D:
	return _open_case.eye_transform() if job.case_open else _workview_eye.global_transform


## The VGA socket that the bench cable plugs into; its +Z points out of the socket.
func cable_socket() -> Node3D:
	return _cable_socket


## How far along the mouse ray from [param from] along [param dir] (world space) the computer is, in
## metres, or -1.0 when the ray misses it (see [method Hotspot.ray_distance]).
func ray_distance(from: Vector3, dir: Vector3) -> float:
	return _hotspot.ray_distance(from, dir)


## Stops taking clicks, before the computer leaves the counter.
func disable() -> void:
	_hotspot.set_enabled(false)
	_power_hotspot.set_enabled(false)


func _set_hovered(on: bool) -> void:
	_hovered = on
	_sync_outline()


# An open computer lies on its side; the player works in it only in the Workview, with it in focus.
func _sync_case() -> void:
	_tower.visible = not job.case_open
	_post_it_anchor.visible = not job.case_open
	_open_case.visible = job.case_open
	_open_case.active = job.case_open and Game.focus == job and Game.view == &"Workview"
	_hotspot.set_enabled(not _open_case.active)
	_sync_outline()


func _sync_outline() -> void:
	_outline.visible = (focused or _hovered or targeted) and not job.case_open
	(_outline.material_override as StandardMaterial3D).albedo_color = focus_color if focused and not targeted else hover_color


func _sync_power_light() -> void:
	(_power_light.material_override as StandardMaterial3D).albedo_color = power_on_color if powered else power_off_color
