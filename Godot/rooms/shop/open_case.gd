class_name OpenCase
extends Node3D
## A job's computer lying on its side in the Workview (wiki: Hardware Repair): the side panel and its
## screws, or the open case with its pieces, their screws and the mat. It draws the job from Game on
## every change, acts through Game, and shows a screwdriver at each screw that turns. Everything that
## the player can use now has an outline; the screwdriver hovers over a screw under the mouse.

const HOTSPOT: PackedScene = preload("res://rooms/hotspot.tscn")
const SCREW_MATERIAL: Material = preload("res://materials/metal.tres")

## The seconds that the screwdriver turns one screw.
@export var screw_seconds: float = 0.45
## The outline of what the player can use now, and of the one under the mouse. The colours of the
## computers' own outlines (JobComputer).
@export var usable_color: Color = Color(1.0, 0.82, 0.2)
@export var hover_color: Color = Color(0.75, 0.9, 1.0)
## How high the screwdriver hovers over a screw under the mouse, and how far it bobs, in metres.
@export var hover_height: float = 0.03
@export var bob: float = 0.006
## The seconds that the screwdriver takes to fade in or out.
@export var fade_seconds: float = 0.15

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
var _bobbing: Tween
var _fading: Tween
var _outlines: Dictionary[Hotspot, MeshInstance3D] = {}
var _usable: StandardMaterial3D
var _hovering: StandardMaterial3D
var _hovered: Hotspot
var _hovered_screw: String = ""
var _driver_materials: Array[StandardMaterial3D] = []

@onready var _places: Node3D = %Places
@onready var _spots: Node3D = %Spots
@onready var _mat_surface: Hotspot = %MatSurface
@onready var _eye: Marker3D = %Eye
@onready var _panel: Node3D = %Panel
@onready var _panel_hotspot: Hotspot = %PanelHotspot
@onready var _panel_screws: Node3D = %PanelScrews
@onready var _driver: Node3D = %Screwdriver
@onready var _outside: Array[MeshInstance3D] = [%Panel as MeshInstance3D, $Shell/Bezel as MeshInstance3D]
@onready var _sticker_faces: Dictionary[Sticker.Face, Node3D] = {Sticker.Face.FRONT: %StickerFront, Sticker.Face.RIGHT: %StickerRight}


func _ready() -> void:
	_usable = _outline_material(usable_color)
	_hovering = _outline_material(hover_color)
	for mesh: MeshInstance3D in _driver.find_children("*", "MeshInstance3D"):
		var own := (mesh.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
		mesh.material_override = own
		_driver_materials.append(own)
	for part: Part in Part.every():
		var place := _place(part)
		if place != null:
			var hotspot := place.get_node("Hotspot") as Hotspot
			hotspot.clicked.connect(_on_place_clicked.bind(part).unbind(1))
			_watch(hotspot)
	for i: int in _spots.get_child_count():
		var spot := _spots.get_child(i).get_node("Hotspot") as Hotspot
		spot.clicked.connect(_on_spot_clicked.bind(i).unbind(1))
		_watch(spot)
	_mat_surface.clicked.connect(func(_h: Hotspot) -> void: Game.put_on_mat(job))
	_watch(_mat_surface)
	_panel_hotspot.clicked.connect(func(_h: Hotspot) -> void: Game.open_case(job, true))
	_watch(_panel_hotspot)
	if _panel_screws.get_child_count() != Job.PANEL_SCREWS:
		push_error("OpenCase: %d panel screw markers, but Job.PANEL_SCREWS is %d" % [_panel_screws.get_child_count(), Job.PANEL_SCREWS])
	for i: int in _panel_screws.get_child_count():
		_add_screw(_panel_screws.get_child(i), Vector3.ZERO, null, i)
	Game.changed.connect(_sync)
	_sync()


## Gives the outside of the case (the side panel and the front) the case material and the stickers
## of [param computer], as PcTower.dress does for the upright tower; null keeps plain beige plastic.
## The left side lies on the mat, so its stickers don't show.
func dress(computer: Computer) -> void:
	var case_material: Material = computer.case_material if computer != null else null
	if case_material != null:
		for part: MeshInstance3D in _outside:
			part.material_override = case_material
	Sticker.stick(computer.stickers if computer != null else ([] as Array[Sticker]), _sticker_faces)


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
	_sync_outlines()


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
	var key := "%s:%d" % [part.id() if part != null else &"panel", index]
	hotspot.clicked.connect(func(_h: Hotspot) -> void: _turn(part, index, head.global_position))
	_screws[key] = [head, hotspot]
	_watch(hotspot, key)


func _turn(part: Part, index: int, at: Vector3) -> void:
	var was_in: bool = job.panel_screws[index] if part == null else job.screws[part][index]
	if Game.turn_screw(job, part, index):
		_screw(at, was_in)


# --- Outlines and hover --------------------------------------------------------------------------

# An inverted hull, as on JobComputer: a slightly bigger box with its front faces culled.
func _outline_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_FRONT
	material.albedo_color = color
	return material


# Gives [param hotspot] an outline and follows the mouse over it; [param screw_key] names a screw.
func _watch(hotspot: Hotspot, screw_key: String = "") -> void:
	var box := BoxMesh.new()
	box.size = hotspot.size + Vector3.ONE * 0.006
	var outline := MeshInstance3D.new()
	outline.mesh = box
	outline.visible = false
	hotspot.add_child(outline)
	_outlines[hotspot] = outline
	hotspot.mouse_entered.connect(_on_hover.bind(hotspot, screw_key, true))
	hotspot.mouse_exited.connect(_on_hover.bind(hotspot, screw_key, false))
	hotspot.tree_exiting.connect(func() -> void:
		_outlines.erase(hotspot)
		if _hovered == hotspot:
			_hovered = null)


func _sync_outlines() -> void:
	if _hovered != null and not _hovered.input_ray_pickable:
		_on_hover(_hovered, _hovered_screw, false)
	for hotspot: Hotspot in _outlines:
		var outline := _outlines[hotspot]
		outline.visible = hotspot.input_ray_pickable
		outline.material_override = _hovering if hotspot == _hovered else _usable


func _on_hover(hotspot: Hotspot, screw_key: String, entered: bool) -> void:
	if entered:
		_hovered = hotspot
	elif _hovered == hotspot:
		_hovered = null
	_sync_outlines()
	if screw_key == "":
		return
	if entered:
		_hovered_screw = screw_key
		if _turning == null:
			_hover_over(screw_key)
	elif _hovered_screw == screw_key:
		_hovered_screw = ""
		if _turning == null:
			_fade(false)


# --- The screwdriver -----------------------------------------------------------------------------

# The screwdriver fades in over the screw and bobs until the player clicks.
func _hover_over(screw_key: String) -> void:
	var head: Node3D = _screws[screw_key][0]
	var top := head.global_position + Vector3(0, hover_height, 0)
	_driver.global_position = top
	_driver.rotation = Vector3.ZERO
	_fade(true)
	if _bobbing != null:
		_bobbing.kill()
	_bobbing = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	_bobbing.tween_property(_driver, "global_position", top + Vector3(0, bob, 0), 0.3)
	_bobbing.tween_property(_driver, "global_position", top - Vector3(0, bob, 0), 0.3)


# The screwdriver comes down and turns twice, lifting the screw out or bringing it down. Only a look:
# Game has turned the screw already. Then it hovers again, or fades out.
func _screw(at: Vector3, unscrewing: bool) -> void:
	if _bobbing != null:
		_bobbing.kill()
	if _turning != null:
		_turning.kill()
	var lift := Vector3(0, 0.02, 0)
	if not _driver.visible:
		_driver.global_position = at + Vector3(0, hover_height, 0)
	_fade(true)
	_turning = create_tween()
	_turning.tween_property(_driver, "global_position", at if unscrewing else at + lift, 0.08)
	_turning.tween_property(_driver, "rotation:y", TAU * (2.0 if unscrewing else -2.0), screw_seconds)
	_turning.parallel().tween_property(_driver, "global_position", at + lift if unscrewing else at, screw_seconds)
	_turning.tween_callback(func() -> void:
		_turning = null
		if _hovered_screw != "" and _screws.has(_hovered_screw) and (_screws[_hovered_screw][1] as Hotspot).input_ray_pickable:
			_hover_over(_hovered_screw)
		else:
			_fade(false))


# Fades the screwdriver in (true) or out (false); faded out, it is gone.
func _fade(show: bool) -> void:
	if _fading != null:
		_fading.kill()
	if show and not _driver.visible:
		_set_driver_alpha(0.0)
		_driver.visible = true
	_fading = create_tween()
	_fading.tween_method(_set_driver_alpha, _driver_materials[0].albedo_color.a, 1.0 if show else 0.0, fade_seconds)
	if not show:
		_fading.tween_callback(func() -> void:
			_driver.visible = false
			if _bobbing != null:
				_bobbing.kill())


func _set_driver_alpha(alpha: float) -> void:
	for material: StandardMaterial3D in _driver_materials:
		material.albedo_color.a = alpha


func _on_place_clicked(part: Part) -> void:
	if Game.can_take(job, part):
		Game.take_part(job, part)
	else:
		Game.put_part(job)


func _on_spot_clicked(index: int) -> void:
	Game.take_from_mat(job, index)
