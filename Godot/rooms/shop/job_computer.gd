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
## How far the outline stands out from the case and everything on it, in metres.
@export var outline_width: float = 0.006
# Upright to lying on its left side: the tower turns about Z, its top to -X and its open side up.
const LYING := Transform3D(Basis(Vector3.BACK, PI / 2.0), Vector3(0, 0.095, 0)) * Transform3D(Basis(), Vector3(0, -0.21, 0))
# How far above the counter the outline's bottom rests, in metres; clear of z-fighting.
const RESTING_LIFT: float = 0.002

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
var _upright: Dictionary[Node3D, Transform3D] = {}
var _upright_post_it: Vector3

@onready var _tower: PcTower = $Tower
@onready var _hotspot: Hotspot = %Hotspot
@onready var _workview_eye: Marker3D = %WorkviewEye
@onready var _outline: MeshInstance3D = %Outline
@onready var _cable_socket: Marker3D = %CableSocket
@onready var _post_it: PostIt3D = %PostIt
@onready var _power_hotspot: Hotspot = %PowerHotspot
@onready var _power_light: MeshInstance3D = %PowerLight
@onready var _post_it_anchor: Node3D = $PostItAnchor
@onready var _open_case: OpenCase = %OpenCase
@onready var _front: Area3D = %Front
# Off the lying case: the panel once it leans against the back, and the mat with its pieces.
@onready var _case_panel: Node3D = $OpenCase/Panel
@onready var _case_mat: Node3D = $OpenCase/Mat


func _ready() -> void:
	_hotspot.clicked.connect(func(_h: Hotspot) -> void: clicked.emit(self))
	_hotspot.mouse_entered.connect(_set_hovered.bind(true))
	_hotspot.mouse_exited.connect(_set_hovered.bind(false))
	_power_hotspot.clicked.connect(func(_h: Hotspot) -> void: power_clicked.emit(self))
	_tower.dress(job.customer.computer)
	_open_case.dress(job.customer.computer)
	_post_it.job = job
	_open_case.job = job
	for node: Node3D in [_power_light, _power_hotspot, _cable_socket, _hotspot]:
		_upright[node] = node.transform
	_upright_post_it = _post_it_anchor.position
	Game.changed.connect(_sync_case)
	_sync_case()
	_sync_outline()
	_sync_power_light()


## Where the Workview camera looks at this computer from, in world space: at the front of the
## standing computer, or down into the lying one.
func workview_transform() -> Transform3D:
	return _open_case.eye_transform() if job.lying else _workview_eye.global_transform


## The post-it that the player reads in the Workview: the one on the front while the computer is in
## focus in the Workview, else null.
func pinned_post_it() -> PostIt3D:
	return _post_it if _working() else null


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


func _working() -> bool:
	return Game.focus == job and Game.view == &"Workview"


# Its hotspots, outline, power light, VGA socket and post-it turn with the case (Job.lying).
func _sync_case() -> void:
	var working := _working()
	var lying := job.lying
	_tower.visible = not lying
	_open_case.visible = lying
	_open_case.active = lying and working
	_post_it.text_3d = not working
	var pose := LYING if lying else Transform3D.IDENTITY
	for node: Node3D in _upright:
		node.transform = pose * _upright[node]
	# Only the position turns: the square paper covers the same spot either way, and its check stays where PostItLabel expects it.
	_post_it_anchor.position = pose * _upright_post_it
	_fit_outline.call_deferred()  # after the open case has drawn this change
	_hotspot.set_enabled(not (lying and working))
	_front.input_ray_pickable = working and not lying  # swallows clicks on the front, so they don't lay it down
	_sync_outline()


# A box around the case and everything on it, standing or lying. Its bottom rests just above the
# counter, which would otherwise hide the outline along the foot.
func _fit_outline() -> void:
	if not is_inside_tree():
		return
	var bounds := _visible_bounds()
	var box := bounds.grow(outline_width)
	var bottom := bounds.position.y + RESTING_LIFT
	box.size.y = box.end.y - bottom
	box.position.y = bottom
	(_outline.mesh as BoxMesh).size = box.size
	_outline.transform = Transform3D(Basis(), box.get_center())


func _visible_bounds() -> AABB:
	var loose: Array[Node3D] = [_outline, _case_mat]
	if job.case_open:
		loose.append(_case_panel)
	var bounds := AABB()
	var first := true
	for node: Node in find_children("*", "VisualInstance3D", true, false):
		var visual := node as VisualInstance3D
		if not visual.is_visible_in_tree() or loose.any(func(n: Node3D) -> bool: return n == visual or n.is_ancestor_of(visual)):
			continue
		var box := (global_transform.affine_inverse() * visual.global_transform) * visual.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds


func _sync_outline() -> void:
	_outline.visible = (focused or _hovered or targeted) and not _open_case.active
	(_outline.material_override as StandardMaterial3D).albedo_color = focus_color if focused and not targeted else hover_color


func _sync_power_light() -> void:
	(_power_light.material_override as StandardMaterial3D).albedo_color = power_on_color if powered else power_off_color
