class_name OpenCase
extends Node3D
## A job's computer lying on its side (wiki: Hardware Repair): the side panel on with its two screws,
## or the open case with its pieces and the mat and the panel leaning against its back (PanelOff),
## where a click puts it back on. It draws the job from Game on every change and acts through Game.
## What the player can use now has a thin pulsing outline, and a screw or an empty screw hole that
## can turn a beating ring; where the piece in the hand or a screw can go shows a see-through ghost of
## it; the screwdriver hovers over a screw. An empty screw hole in the closed panel shows dark.
## What lies in the way (Job.blocker), such as a hamster, lies on top of the part that it sits on; a
## misplaced piece (Job.misplaced) lies askew on its wrong place, on top of the part that place sits on.

const HOTSPOT: PackedScene = preload("res://rooms/hotspot.tscn")
const SCREW_MATERIAL: Material = preload("res://materials/metal.tres")
const PULSE_RING: Shader = preload("res://shaders/pulse_ring.gdshader")

## The seconds that the screwdriver turns one screw.
@export var screw_seconds: float = 0.45
## The outline and ghost colour of what the player can use now, and of the one under the mouse.
@export var usable_color: Color = Color(1.0, 0.84, 0.35)
@export var hover_color: Color = Color(0.8, 0.95, 1.0)
## How far the outline stands out from a mesh, in metres.
@export var outline_width: float = 0.0035
## The seconds of one beat of the ring around each screw that the player can turn, and the ring's
## outer diameter in metres.
@export var screw_pulse_seconds: float = 1.6
@export var screw_ring_size: float = 0.08
## The colour of an empty screw hole.
@export var hole_color: Color = Color(0.05, 0.04, 0.03)
## How high the screwdriver hovers over a screw under the mouse, and how far it bobs, in metres.
@export var hover_height: float = 0.03
@export var bob: float = 0.006
## The seconds that the screwdriver takes to fade in or out.
@export var fade_seconds: float = 0.15
## How a misplaced piece lies on its wrong place: tilted about its width and turned, in degrees. The
## pieces on every other place lean the other way.
@export var misplaced_tilt: float = 8.0
@export var misplaced_turn: float = 20.0

## The job whose computer this is. Set once, before or after the case enters the tree.
var job: Job:
	set(value):
		job = value
		if is_node_ready():
			_sync()
## True while the player works in this computer: laid down in the Workview. JobComputer sets it.
## Only an active case takes clicks and shows highlights.
var active: bool = false:
	set(value):
		active = value
		if is_node_ready():
			_sync()

var _shown: Dictionary[StringName, Node3D] = {}
var _mat_shown: Array[Node3D] = []
# Panel screw index to [screw head, hotspot, pulse ring, empty hole].
var _screws: Array[Array] = []
var _screw_ring: ShaderMaterial
var _outline: StandardMaterial3D
var _outline_hover: StandardMaterial3D
var _ghost: StandardMaterial3D
var _ghost_hover: StandardMaterial3D
var _outlined: Array[MeshInstance3D] = []
var _ghosts: Array[Node3D] = []
var _hovered: Hotspot
var _hovered_screw: int = -1
var _turning: Tween
var _bobbing: Tween
var _fading: Tween
var _driver_materials: Array[StandardMaterial3D] = []
# The pieces that lie on a place that isn't theirs (Job.blocker, Job.misplaced), to [model, hotspot].
var _lying: Dictionary[Piece, Array] = {}

@onready var _places: Node3D = %Places
@onready var _spots: Node3D = %Spots
# Left and right of the screwdriver's outline, so that no part lies on it.
@onready var _mat_surfaces: Array[Node] = %MatSurfaces.get_children()
@onready var _eye: Marker3D = %Eye
@onready var _panel: MeshInstance3D = %Panel
@onready var _panel_hotspot: Hotspot = %PanelHotspot
@onready var _panel_on: Transform3D = _panel.transform
@onready var _panel_off: Transform3D = (%PanelOff as Node3D).transform
@onready var _panel_screws: Node3D = %PanelScrews
@onready var _driver: Node3D = %Screwdriver
@onready var _outside: Array[MeshInstance3D] = [%Panel as MeshInstance3D, $Shell/Bezel as MeshInstance3D]
@onready var _sticker_faces: Dictionary[Sticker.Face, Node3D] = {Sticker.Face.FRONT: %StickerFront, Sticker.Face.RIGHT: %StickerRight}


func _ready() -> void:
	_outline = Hotspot.outline_material(usable_color, outline_width)
	_outline_hover = Hotspot.outline_material(hover_color, outline_width)
	_ghost = Hotspot.ghost_material(usable_color)
	_ghost_hover = Hotspot.ghost_material(hover_color)
	_screw_ring = ShaderMaterial.new()
	_screw_ring.shader = PULSE_RING
	_screw_ring.set_shader_parameter(&"color", usable_color)
	_screw_ring.set_shader_parameter(&"period", screw_pulse_seconds)
	var pulse := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	pulse.tween_method(_pulse, 0.0, 1.0, 0.7)
	pulse.tween_method(_pulse, 1.0, 0.0, 0.7)
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
	for surface: Hotspot in _mat_surfaces:
		surface.clicked.connect(func(_h: Hotspot) -> void: Game.put_on_mat(job))
		_watch(surface)
	_panel_hotspot.clicked.connect(func(_h: Hotspot) -> void: Game.open_case(job, not job.case_open))
	_watch(_panel_hotspot)
	if _panel_screws.get_child_count() != Job.PANEL_SCREWS:
		push_error("OpenCase: %d panel screw markers, but Job.PANEL_SCREWS is %d" % [_panel_screws.get_child_count(), Job.PANEL_SCREWS])
	for i: int in _panel_screws.get_child_count():
		_add_screw(_panel_screws.get_child(i) as Node3D, i)
	Game.changed.connect(_sync)
	_sync()


## Gives the outside of the case (the side panel and the front) the case material, the case front
## and the stickers of [param computer], as PcTower.dress does for the upright tower; null keeps plain
## beige plastic and the classic front. The left side lies on the mat, so its stickers don't show.
func dress(computer: Computer) -> void:
	var case_material: Material = computer.case_material if computer != null else null
	if case_material != null:
		for part: MeshInstance3D in _outside:
			part.material_override = case_material
	Computer.mount_front(computer, %Front)
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
	_panel.transform = _panel_on if closed else _panel_off
	_panel_hotspot.set_enabled(active and (not closed or (not job.powered and not job.panel_screws.has(true))))
	for i: int in _screws.size():
		(_screws[i][0] as Node3D).visible = closed and job.panel_screws[i]
		(_screws[i][3] as Node3D).visible = closed and not job.panel_screws[i]
		(_screws[i][1] as Hotspot).set_enabled(active and Game.can_turn(job, i))
	for part: Part in Part.every():
		var place := _place(part)
		if place == null:
			continue
		var piece := job.piece(part)
		var shown: Node3D = _shown.get(part.id())
		if shown != null and (piece == null or shown.get_meta(&"piece") != piece):
			shown.queue_free()
			_shown.erase(part.id())
			shown = null
		if piece != null and shown == null:
			_shown[part.id()] = _show_model(piece, place)
		(place.get_node("Hotspot") as Hotspot).set_enabled(active and (Game.can_take(job, part) or Game.can_put(job, part)))
	_sync_lying()
	for shown: Node3D in _mat_shown:
		shown.queue_free()
	_mat_shown.clear()
	for i: int in job.mat.size():
		_mat_shown.append(_show_model(job.mat[i], _spot(i)))
	for i: int in _spots.get_child_count():
		(_spots.get_child(i).get_node("Hotspot") as Hotspot).set_enabled(active and Game.hand == null and i < job.mat.size())
	for surface: Hotspot in _mat_surfaces:
		surface.set_enabled(active and Game.hand != null)
	if _hovered != null and not _hovered.input_ray_pickable:
		_on_hover(_hovered, -1, false)
	_sync_highlights()


# Shows each piece that lies on a place that isn't its own, with a hotspot that lifts it.
func _sync_lying() -> void:
	var wanted: Dictionary[Piece, Part] = {}
	if job.blocker != null:
		wanted[job.blocker] = job.blocker.part.sits_on
	for place: Part in job.misplaced:
		wanted[job.misplaced[place]] = place
	for piece: Piece in _lying.keys():
		if not wanted.has(piece):
			(_lying[piece][0] as Node3D).queue_free()
			_lying.erase(piece)
	for piece: Piece in wanted:
		if not _lying.has(piece):
			var laid := _lay(piece, wanted[piece])
			if laid.is_empty():
				continue
			_lying[piece] = laid
		(_lying[piece][1] as Hotspot).set_enabled(active and _can_lift(piece, wanted[piece]))


# The model of [param piece] lying on [param place], and its hotspot; [] when it can't show.
func _lay(piece: Piece, place: Part) -> Array:
	var marker := _place(place)
	if marker == null:
		return []
	var model := piece.make_model()
	if model == null:
		return []
	model.set_meta(&"piece", piece)
	if piece == job.blocker:
		var under: Node3D = _shown.get(place.id())
		model.position.y = Part.bounds(under).end.y if under != null else 0.0
		marker.add_child(model)
	else:
		# Flat in the case, not in the marker's frame: the RAM slots' markers stand the RAM up.
		var under: Node3D = _shown.get(place.sits_on.id()) if place.sits_on != null else null
		var lean := 1.0 if Part.IDS.find(place.id()) % 2 == 0 else -1.0
		model.position = marker.position
		if under != null:
			model.position.y = _places.to_local(under.to_global(Vector3(0, Part.bounds(under).end.y, 0))).y
		model.rotation_degrees = Vector3(misplaced_tilt * lean, misplaced_turn * lean, 0.0)
		_places.add_child(model)
	var box := Part.bounds(model)
	var hotspot := HOTSPOT.instantiate() as Hotspot
	hotspot.size = box.size + Vector3.ONE * 0.01
	hotspot.position = box.get_center()
	model.add_child(hotspot)
	hotspot.clicked.connect(func(_h: Hotspot) -> void: _lift(piece, place))
	_watch(hotspot)
	return [model, hotspot]


func _can_lift(piece: Piece, place: Part) -> bool:
	return Game.can_take_blocker(job) if piece == job.blocker else Game.can_take_misplaced(job, place)


func _lift(piece: Piece, place: Part) -> void:
	if piece == job.blocker:
		Game.take_blocker(job)
	else:
		Game.take_misplaced(job, place)


func _spot(index: int) -> Node3D:
	return _spots.get_child(mini(index, _spots.get_child_count() - 1)) as Node3D


func _show_model(piece: Piece, where: Node3D) -> Node3D:
	var model := piece.make_model()
	if model == null:
		return null
	model.set_meta(&"piece", piece)
	where.add_child(model)
	return model


func _add_screw(marker: Node3D, index: int) -> void:
	var head := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.008
	mesh.bottom_radius = 0.008
	mesh.height = 0.005
	mesh.radial_segments = 6
	mesh.rings = 1
	head.mesh = mesh
	head.material_override = SCREW_MATERIAL
	head.position = Vector3(0, 0.002, 0)
	marker.add_child(head)
	var hotspot := HOTSPOT.instantiate() as Hotspot
	hotspot.size = Vector3(0.04, 0.02, 0.04)
	hotspot.position = Vector3(0, 0.006, 0)
	marker.add_child(hotspot)
	hotspot.clicked.connect(func(_h: Hotspot) -> void: _turn(index, head.global_position))
	var ring := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * screw_ring_size
	ring.mesh = quad
	ring.material_override = _screw_ring
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = head.position
	ring.visible = false
	marker.add_child(ring)
	var hole := MeshInstance3D.new()
	hole.name = "Hole"
	var disc := CylinderMesh.new()
	disc.top_radius = 0.0055
	disc.bottom_radius = 0.0055
	disc.height = 0.004
	disc.radial_segments = 8
	disc.rings = 1
	hole.mesh = disc
	var dark := StandardMaterial3D.new()
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark.albedo_color = hole_color
	hole.material_override = dark
	hole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hole.visible = false
	marker.add_child(hole)
	_screws.append([head, hotspot, ring, hole])
	_watch(hotspot, index)


func _turn(index: int, at: Vector3) -> void:
	var was_in: bool = job.panel_screws[index]
	if Game.turn_screw(job, index):
		_screw(at, was_in)


# --- Highlights ----------------------------------------------------------------------------------

func _pulse(t: float) -> void:
	_outline.albedo_color = usable_color.lerp(Color.WHITE, 0.35 * t)
	_ghost.albedo_color.a = 0.25 + 0.2 * t


# Outlines what can be taken, turned or lifted; shows a ghost where the hand's piece can go.
func _sync_highlights() -> void:
	for mesh: MeshInstance3D in _outlined:
		if is_instance_valid(mesh):
			mesh.material_overlay = null
	_outlined.clear()
	for ghost: Node3D in _ghosts:
		ghost.queue_free()
	_ghosts.clear()
	for screw: Array in _screws:
		(screw[2] as Node3D).visible = false
	if not active:
		return
	for part: Part in Part.every():
		var place := _place(part)
		var hotspot := place.get_node("Hotspot") as Hotspot if place != null else null
		if hotspot == null or not hotspot.input_ray_pickable:
			continue
		if job.piece(part) != null:
			_highlight(_shown.get(part.id()), hotspot)
		elif Game.hand != null:
			_add_ghost(Game.hand.part.model, place, hotspot)
	for laid: Array in _lying.values():
		if (laid[1] as Hotspot).input_ray_pickable:
			_highlight(laid[0], laid[1])
	for i: int in _mat_shown.size():
		var spot_hotspot := _spot(i).get_node("Hotspot") as Hotspot
		if spot_hotspot.input_ray_pickable:
			_highlight(_mat_shown[i], spot_hotspot)
	if _hovered in _mat_surfaces and Game.hand != null:  # the mat is wide: a ghost only where the player points
		_add_ghost(Game.hand.part.model, _spot(job.mat.size()), _hovered)
	if _panel_hotspot.input_ray_pickable:
		_highlight(_panel, _panel_hotspot)
	for i: int in _screws.size():
		var head := _screws[i][0] as MeshInstance3D
		var hotspot := _screws[i][1] as Hotspot
		if not hotspot.input_ray_pickable:
			continue
		(_screws[i][2] as Node3D).visible = hotspot != _hovered
		if head.visible:
			_highlight(head, hotspot)
		else:
			var ghost := MeshInstance3D.new()
			ghost.mesh = head.mesh
			ghost.position = head.position
			ghost.material_override = _ghost_hover if hotspot == _hovered else _ghost
			head.get_parent().add_child(ghost)
			_ghosts.append(ghost)


func _highlight(node: Node3D, hotspot: Hotspot) -> void:
	if node == null:
		return
	var meshes: Array[Node] = node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		meshes.append(node)
	for mesh: MeshInstance3D in meshes:
		mesh.material_overlay = _outline_hover if hotspot == _hovered else _outline
		_outlined.append(mesh)


func _add_ghost(model: PackedScene, where: Node3D, hotspot: Hotspot) -> void:
	if model == null or where == null:
		return
	var ghost := model.instantiate() as Node3D
	for mesh: MeshInstance3D in ghost.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = _ghost_hover if hotspot == _hovered else _ghost
	where.add_child(ghost)
	_ghosts.append(ghost)


# Follows the mouse over [param hotspot]; [param screw] is its panel screw index, or -1.
func _watch(hotspot: Hotspot, screw: int = -1) -> void:
	hotspot.mouse_entered.connect(_on_hover.bind(hotspot, screw, true))
	hotspot.mouse_exited.connect(_on_hover.bind(hotspot, screw, false))


func _on_hover(hotspot: Hotspot, screw: int, entered: bool) -> void:
	if entered:
		_hovered = hotspot
	elif _hovered == hotspot:
		_hovered = null
	_sync_highlights()
	if screw < 0:
		return
	if entered:
		_hovered_screw = screw
		if _turning == null:
			_hover_over(screw)
	elif _hovered_screw == screw:
		_hovered_screw = -1
		if _turning == null:
			_fade(false)


# --- The screwdriver -----------------------------------------------------------------------------

# The screwdriver fades in over the screw and bobs until the player clicks.
func _hover_over(screw: int) -> void:
	var head: Node3D = _screws[screw][0]
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
		if _hovered_screw >= 0 and (_screws[_hovered_screw][1] as Hotspot).input_ray_pickable:
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
		Game.put_part(job, part)


func _on_spot_clicked(index: int) -> void:
	Game.take_from_mat(job, index)
