class_name OpenCase
extends Node3D
## A job's computer lying on its side in the Workview (wiki: Hardware Repair): the side panel and its
## screws, or the open case with its pieces, their screws and the mat. It draws the job from Game on
## every change, acts through Game, and shows a screwdriver at each screw that turns.

const HOTSPOT: PackedScene = preload("res://rooms/hotspot.tscn")
const SCREW_MATERIAL: Material = preload("res://materials/metal.tres")

## The seconds that the screwdriver turns one screw.
@export var screw_seconds: float = 0.45

## The job whose computer this is. Set once, before the case enters the tree.
var job: Job
## True while the player works on this computer: in focus, in the Workview. JobComputer sets it.
## Only an active case takes clicks.
var active: bool = false:
	set(value):
		active = value
		if is_node_ready():
			_sync()

var _shown: Dictionary[StringName, Node3D] = {}
var _mat_shown: Array[Node3D] = []
# "<part id>:<index>" (the panel's id is "panel") to [screw head, hotspot].
var _screws: Dictionary[String, Array] = {}
var _turning: Tween

@onready var _places: Node3D = %Places
@onready var _spots: Node3D = %Spots
@onready var _mat_surface: Hotspot = %MatSurface
@onready var _eye: Marker3D = %Eye
@onready var _panel: Node3D = %Panel
@onready var _panel_hotspot: Hotspot = %PanelHotspot
@onready var _panel_screws: Node3D = %PanelScrews
@onready var _driver: Node3D = %Screwdriver


func _ready() -> void:
	for part: Part in Part.every():
		var place := _place(part)
		if place != null:
			(place.get_node("Hotspot") as Hotspot).clicked.connect(_on_place_clicked.bind(part).unbind(1))
	for i: int in _spots.get_child_count():
		(_spots.get_child(i).get_node("Hotspot") as Hotspot).clicked.connect(_on_spot_clicked.bind(i).unbind(1))
	_mat_surface.clicked.connect(func(_h: Hotspot) -> void: Game.put_on_mat(job))
	_panel_hotspot.clicked.connect(func(_h: Hotspot) -> void: Game.open_case(job, true))
	if _panel_screws.get_child_count() != Job.PANEL_SCREWS:
		push_error("OpenCase: %d panel screw markers, but Job.PANEL_SCREWS is %d" % [_panel_screws.get_child_count(), Job.PANEL_SCREWS])
	for i: int in _panel_screws.get_child_count():
		_add_screw(_panel_screws.get_child(i), Vector3.ZERO, null, i)
	Game.changed.connect(_sync)
	_sync()


## Where the Workview camera looks from at this lying computer, in world space: high enough for the
## case and the mat to both show.
func eye_transform() -> Transform3D:
	return _eye.global_transform


func _place(part: Part) -> Node3D:
	var place := _places.get_node_or_null(String(part.id())) as Node3D
	if place == null:
		push_error("OpenCase: no place named %s under %s" % [part.id(), _places.get_path()])
	return place


# Converges the panel, the models, the screws and the hotspots on the job and the hand.
func _sync() -> void:
	if job == null:
		return
	var closed := not job.case_open
	_panel.visible = closed
	_panel_hotspot.set_enabled(active and closed and not job.powered and not job.panel_screws.has(true))
	for i: int in job.panel_screws.size():
		_sync_screw("panel:%d" % i, closed and job.panel_screws[i], Game.can_turn(job, null, i))
	for part: Part in Part.every():
		var place := _place(part)
		if place == null:
			continue
		var piece := job.piece(part)
		var shown: Node3D = _shown.get(part.id())
		if (piece != null) != (shown != null):
			if shown != null:
				shown.queue_free()
				_shown.erase(part.id())
				for i: int in part.screw_points.size():
					_screws.erase("%s:%d" % [part.id(), i])
			else:
				_shown[part.id()] = _show_part(part, place)
		for i: int in part.screw_points.size():
			_sync_screw("%s:%d" % [part.id(), i], piece != null and job.screws[part][i], Game.can_turn(job, part, i))
		(place.get_node("Hotspot") as Hotspot).set_enabled(active and (Game.can_take(job, part) or Game.can_put(job, part)))
	for shown: Node3D in _mat_shown:
		shown.queue_free()
	_mat_shown.clear()
	for i: int in job.mat.size():
		var spot := _spots.get_child(mini(i, _spots.get_child_count() - 1)) as Node3D
		_mat_shown.append(_show_model(job.mat[i].part, spot))
	for i: int in _spots.get_child_count():
		(_spots.get_child(i).get_node("Hotspot") as Hotspot).set_enabled(active and Game.hand == null and i < job.mat.size())
	_mat_surface.set_enabled(active and Game.hand != null)


func _sync_screw(key: String, screwed_in: bool, can_turn: bool) -> void:
	var screw: Array = _screws.get(key, [])
	if screw.is_empty():
		return
	(screw[0] as Node3D).visible = screwed_in
	(screw[1] as Hotspot).set_enabled(active and can_turn)


# The model of a piece in its place, with a screw head and a hotspot at each of the part's screws.
func _show_part(part: Part, place: Node3D) -> Node3D:
	var model := _show_model(part, place)
	if model != null:
		for i: int in part.screw_points.size():
			_add_screw(model, part.screw_points[i], part, i)
	return model


func _show_model(part: Part, where: Node3D) -> Node3D:
	if part.model == null:
		push_error("OpenCase: %s has no model" % part.resource_path)
		return null
	var model := part.model.instantiate() as Node3D
	where.add_child(model)
	return model


func _add_screw(parent: Node3D, at: Vector3, part: Part, index: int) -> void:
	var head := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.008
	mesh.bottom_radius = 0.008
	mesh.height = 0.005
	mesh.radial_segments = 6
	mesh.rings = 1
	head.mesh = mesh
	head.material_override = SCREW_MATERIAL
	head.position = at + Vector3(0, 0.002, 0)
	parent.add_child(head)
	var hotspot := HOTSPOT.instantiate() as Hotspot
	hotspot.size = Vector3(0.04, 0.02, 0.04)
	hotspot.position = at + Vector3(0, 0.006, 0)
	parent.add_child(hotspot)
	hotspot.clicked.connect(func(_h: Hotspot) -> void: _turn(part, index, head.global_position))
	_screws["%s:%d" % [part.id() if part != null else &"panel", index]] = [head, hotspot]


func _turn(part: Part, index: int, at: Vector3) -> void:
	var was_in: bool = job.panel_screws[index] if part == null else job.screws[part][index]
	if Game.turn_screw(job, part, index):
		_show_screwdriver(at, was_in)


# The screwdriver turns twice at the screw, lifting it out or bringing it down. Only a look: Game has
# turned the screw already.
func _show_screwdriver(at: Vector3, unscrewing: bool) -> void:
	if _turning != null:
		_turning.kill()
	var lift := Vector3(0, 0.02, 0)
	_driver.global_position = at if unscrewing else at + lift
	_driver.rotation = Vector3.ZERO
	_driver.visible = true
	_turning = create_tween().set_parallel()
	_turning.tween_property(_driver, "rotation:y", TAU * (2.0 if unscrewing else -2.0), screw_seconds)
	_turning.tween_property(_driver, "global_position", at + lift if unscrewing else at, screw_seconds)
	_turning.chain().tween_callback(_driver.hide)


func _on_place_clicked(part: Part) -> void:
	if Game.can_take(job, part):
		Game.take_part(job, part)
	else:
		Game.put_part(job)


func _on_spot_clicked(index: int) -> void:
	Game.take_from_mat(job, index)
