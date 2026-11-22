class_name JobComputer
extends Node3D
## The computer of one job on the counter. JobSlots places one at each job's slot. It outlines
## itself while the mouse or the cable's plug that the player drags is over it. Its power button
## reports clicks, and its power light shows whether the job is on. In the Workview the screwdriver
## beside it takes the open case's hover outline, and its dashed outline a ghost of it, under the mouse.

## The player clicked the computer.
signal clicked(computer: JobComputer)
## The player clicked the computer's power button.
signal power_clicked(computer: JobComputer)
## The player clicked the screwdriver beside the computer in the Workview, or its dashed outline
## once the computer lies and is closed with its screws.
signal screwdriver_clicked(computer: JobComputer)

## The outline colour while the mouse or the dragged plug is over the computer.
@export var hover_color: Color = Color(0.75, 0.9, 1.0)
## How far the outline stands out from the case and everything on it, in metres.
@export var outline_width: float = 0.006
# Upright to lying on its left side: the tower turns about Z, its top to -X and its open side up.
const LYING := Transform3D(Basis(Vector3.BACK, PI / 2.0), Vector3(0, 0.095, 0)) * Transform3D(Basis(), Vector3(0, -0.21, 0))
# How far above the counter the outline's bottom rests, in metres; clear of z-fighting.
const RESTING_LIFT: float = 0.002

## The outline colour of the power button while the mouse is over it.
@export var button_hover_color: Color = Color(1.0, 0.84, 0.35)
## How long the case takes to tip over onto its side, or back up, in seconds.
@export var tip_seconds: float = 0.5
## The power light's colour while the computer is on, and while it is off.
@export var power_on_color: Color = Color(0.3, 1.0, 0.3)
@export var power_off_color: Color = Color(0.08, 0.16, 0.08)

## The job that this computer shows. Set once, before the computer enters the tree.
var job: Job
## True while the player drags the cable's plug over this computer. JobSlots sets it.
var targeted: bool = false:
	set(value):
		targeted = value
		if is_node_ready():
			_sync_outline()

## True while the job is on (Job.powered); the power light and the fans show it. JobSlots sets it.
var powered: bool = false:
	set(value):
		powered = value
		if is_node_ready():
			_sync_power()

var _hovered: bool = false
var _screwdriver_hovered: bool = false
var _screwdriver_materials: Dictionary[MeshInstance3D, Material] = {}
var _screwdriver_hover_outline: StandardMaterial3D
var _screwdriver_ghost: StandardMaterial3D
## 0 standing, 1 lying; between the two while the case tips.
var _pose: float = 0.0
var _tip: Tween
var _upright: Dictionary[Node3D, Transform3D] = {}

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
@onready var _screwdriver: Node3D = %Screwdriver
@onready var _screwdriver_outline: Sprite3D = %ScrewdriverOutline
@onready var _screwdriver_hotspot: Hotspot = %ScrewdriverHotspot


func _ready() -> void:
	_hotspot.clicked.connect(func(_h: Hotspot) -> void: clicked.emit(self))
	_hotspot.mouse_entered.connect(_set_hovered.bind(true))
	_hotspot.mouse_exited.connect(_set_hovered.bind(false))
	_power_hotspot.clicked.connect(func(_h: Hotspot) -> void: power_clicked.emit(self))
	_power_hotspot.highlight_on_hover(_tower.get_node(^"Power"), button_hover_color)
	_screwdriver_hotspot.clicked.connect(func(_h: Hotspot) -> void: screwdriver_clicked.emit(self))
	_screwdriver_hotspot.mouse_entered.connect(_set_screwdriver_hovered.bind(true))
	_screwdriver_hotspot.mouse_exited.connect(_set_screwdriver_hovered.bind(false))
	for mesh: MeshInstance3D in _screwdriver.find_children("*", "MeshInstance3D"):
		_screwdriver_materials[mesh] = mesh.material_override
	_screwdriver_hover_outline = Hotspot.outline_material(_open_case.hover_color, _open_case.outline_width)
	_screwdriver_ghost = Hotspot.ghost_material(_open_case.hover_color)
	_tower.dress(job.customer.computer)
	_open_case.dress(job.customer.computer)
	_post_it.job = job
	_open_case.job = job
	for node: Node3D in [_tower, _power_light, _power_hotspot, _cable_socket, _hotspot, _post_it_anchor]:
		_upright[node] = node.transform
	_pose = 1.0 if job.lying else 0.0
	Game.changed.connect(_sync_case)
	(_outline.material_override as StandardMaterial3D).albedo_color = hover_color
	_sync_case()
	_sync_power()


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
## metres, or -1.0 when the ray misses it (see [method Hotspot.ray_distance]). It measures the
## computer in focus in the Workview too, where its hotspot takes no clicks.
func ray_distance(from: Vector3, dir: Vector3) -> float:
	return _hotspot.box_ray_distance(from, dir)


## Stops taking clicks, before the computer leaves the counter.
func disable() -> void:
	_hotspot.set_enabled(false)
	_power_hotspot.set_enabled(false)


func _set_hovered(on: bool) -> void:
	_hovered = on
	_sync_outline()


func _set_screwdriver_hovered(on: bool) -> void:
	_screwdriver_hovered = on
	_sync_screwdriver()


func _working() -> bool:
	return Game.focus == job and Game.view == &"Workview"


# Its hotspots, outline, power light, VGA socket and post-it turn with the case (Job.lying).
func _sync_case() -> void:
	var working := _working()
	var lying := job.lying
	_open_case.active = lying and working
	_post_it.text_3d = not working
	var target := 1.0 if lying else 0.0
	if _tip != null and _tip.is_running():
		_tip.kill()
	if target != _pose and is_inside_tree():
		_tip = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN if lying else Tween.EASE_OUT)
		_tip.tween_method(_set_pose, _pose, target, tip_seconds * absf(target - _pose))
	else:
		_set_pose(target)
	_sync_screwdriver()
	_hotspot.set_enabled(not working)  # in the Workview the screwdriver, the screws and the panel take the clicks
	_front.input_ray_pickable = working and not lying  # swallows clicks on the front, so they don't lay it down
	_sync_outline()


# Tips the case between standing (0) and lying on its side (1). The tower turns; the open case,
# which shows the inside, takes over once it lies.
func _set_pose(t: float) -> void:
	_pose = t
	var pose := Transform3D.IDENTITY.interpolate_with(LYING, t)
	for node: Node3D in _upright:
		node.transform = pose * _upright[node]
	_tower.visible = t < 1.0
	_open_case.visible = t >= 1.0
	_fit_outline.call_deferred()  # after the open case has drawn this change


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


# Standing, the screwdriver rests beside the computer; lying, its dashed outline marks the spot, and a click there stands it up.
func _sync_screwdriver() -> void:
	var working := _working()
	var lying := job.lying
	_screwdriver_hotspot.set_enabled(working and (not lying or Game.can_stand_up(job)))
	var hovered := _screwdriver_hovered and _screwdriver_hotspot.input_ray_pickable
	_screwdriver.visible = working and (not lying or hovered)
	_screwdriver_outline.visible = working and lying
	for mesh: MeshInstance3D in _screwdriver_materials:
		mesh.material_override = _screwdriver_ghost if lying else _screwdriver_materials[mesh]
		mesh.material_overlay = _screwdriver_hover_outline if hovered and not lying else null


func _sync_outline() -> void:
	_outline.visible = (_hovered or targeted) and not _open_case.active


func _sync_power() -> void:
	(_power_light.material_override as StandardMaterial3D).albedo_color = power_on_color if powered else power_off_color
	_tower.running = powered
