extends CorruptionSign
## The sheets in the group solitaire_posters (the Open sign, once it has turned over, then the logos on
## the left wall and over the door and the poster on the right wall) leave their places like the cards
## of the Solitaire win, one after the other in [member order]: each shakes in its place, turns to
## face the counter, drops to the floor between the counter and the door, bounces lower and lower
## towards the other side of the shop, and leaves a still copy of itself at every step, lit like the
## room. As in the Solitaire win, each copy draws over every copy
## before it, nearer or not; the room still hides them. Once they are down, the sheets in
## [member fade_order] (the signs on the counter front) follow while the night fades out. Stage 1 plays
## it, and the night waits for the first sheets ([method busy]); then it sets stage 2: the sheets stay
## on the floor, the trail behind them. Stage 0 hangs them back in their places.

const SHEETS: StringName = &"solitaire_posters"
## A node of a sheet in this group, such as the Open sign's string, stays where it hangs when the sheet
## leaves its place, and leaves no copies. It shakes and turns with the sheet before that.
const STAYS: StringName = &"solitaire_stays"
## A fall that never reaches the floor stops after this many steps.
const MAX_STEPS: int = 1000
## How much nearer than the copy before it each copy sorts, in metres: more than the shop is deep.
const LAYER_METRES: float = 100.0
const _PSX_WORLD := preload("res://shaders/psx_world.gdshader")
const _PSX_LAYERED := preload("res://shaders/psx_world_layered.gdshader")

## The names of the sheets in the order they fall. A sheet of the group that is not named falls last.
@export var order: Array[StringName] = [&"OpenSign", &"SignLeft", &"CommercialPoster", &"Sign"]
## The seconds from the start to the first sheet's shake: the Open sign turns over first, in its
## OpenSign.flip_seconds, as the shop closes.
@export var lead_seconds: float = 0.6
## The seconds from one sheet's start to the next one's.
@export var stagger_seconds: float = 2.5
## The names of the sheets that fall after all the others have landed, in this order, while the night
## fades out: the night doesn't wait for them. Each shakes while the sheets before them land, and the
## first leaves its place as the last of them lands.
@export var fade_order: Array[StringName] = [&"FuntasticSticker", &"TrashPoster", &"TapedNote"]
## The seconds from one sheet's start to the next one's, in [member fade_order].
@export var fade_stagger_seconds: float = 0.3
## The line where the sheets in [member fade_order] bounce: z in the shop, in metres, just in front of
## the counter.
@export var fade_lane_z: float = -0.85
## The seconds that a sheet shakes on the wall before it falls.
@export var shake_seconds: float = 1.0
## The widest tilt of the shake, in degrees; it grows to this from nothing.
@export var shake_degrees: float = 6.0
## The shakes per second.
@export var shake_rate: float = 9.0
## The line between the counter and the door where the sheets bounce: z in the shop, in metres.
@export var lane_z: float = -4.2
## The speed along the lane, in m/s, towards the other side of the shop.
@export var side_speed: float = 1.4
## The speed up when a sheet leaves the wall, in m/s.
@export var jump_speed: float = 2.0
## The pull down, in m/s per second.
@export var gravity: float = 7.0
## The share of the speed that a bounce keeps, 0 to 1.
@export_range(0.0, 1.0) var bounce: float = 0.85
## The bounces before a sheet stays on the floor.
@export var bounces: int = 5
## The seconds that a sheet takes to turn from the wall to face the counter.
@export var turn_seconds: float = 0.4
## The seconds between two copies of the trail.
@export var trail_step: float = 1.0 / 30.0
## The height of the shop floor, in metres.
@export var floor_height: float = 0.0

var _sheets: Array[Node3D] = []
var _homes: Array[Transform3D] = []
var _meshes: Array = []  # one Array[GeometryInstance3D] per sheet: its meshes and labels
var _stays: Array = []  # one Array[Node3D] per sheet: its nodes in the group STAYS
var _stay_homes: Array = []  # one Array[Transform3D] per sheet: each stay's own transform at home
var _stay_places: Array = []  # one Array[Transform3D] per sheet: each stay's global transform at home
var _paths: Array = []  # one Array[Transform3D] per sheet
var _starts: Array[int] = []  # the trail step where each sheet starts to shake
var _night_step: int = 0  # the trail step from which the night needn't wait
var _fallen: bool = false
var _step: int = 0
var _clock: float = 0.0
var _copies: int = 0
# Each sheet material's twin in the transparent pass, where sorting_offset orders the copies.
var _layered: Dictionary[Material, Material] = {}

@onready var _trail: Node3D = %Trail


func _ready() -> void:
	for node: Node in get_tree().get_nodes_in_group(SHEETS):
		_sheets.append(node as Node3D)
	if _sheets.is_empty():
		push_error("posters_bounce: nothing in the group %s" % SHEETS)
	for name_of: StringName in order + fade_order:
		if not _sheets.any(func(sheet: Node3D) -> bool: return sheet.name == name_of):
			push_error("posters_bounce: no %s in the group %s, from order or fade_order" % [name_of, SHEETS])
	_sheets.sort_custom(func(a: Node3D, b: Node3D) -> bool: return _rank(a) < _rank(b))
	for sheet: Node3D in _sheets:
		_homes.append(sheet.global_transform)
		var stays: Array[Node3D] = []
		var stay_homes: Array[Transform3D] = []
		var stay_places: Array[Transform3D] = []
		for node: Node in sheet.find_children("*", "Node3D", true, false):
			if node.is_in_group(STAYS):
				stays.append(node as Node3D)
				stay_homes.append((node as Node3D).transform)
				stay_places.append((node as Node3D).global_transform)
		_stays.append(stays)
		_stay_homes.append(stay_homes)
		_stay_places.append(stay_places)
		var meshes: Array[GeometryInstance3D] = []
		if sheet is MeshInstance3D:
			meshes.append(sheet as MeshInstance3D)
		for mesh: Node in sheet.find_children("*", "GeometryInstance3D", true, false):
			if (mesh is MeshInstance3D or mesh is Label3D) and not stays.any(func(stay: Node3D) -> bool: return stay == mesh or stay.is_ancestor_of(mesh)):
				meshes.append(mesh as GeometryInstance3D)
		var to_local := sheet.global_transform.affine_inverse()
		# Back to front, as each step's copies layer in this order: the Open sign's face over its back.
		meshes.sort_custom(func(a: GeometryInstance3D, b: GeometryInstance3D) -> bool: return (to_local * a.global_position).z < (to_local * b.global_position).z)
		_meshes.append(meshes)
	set_process(false)
	super()


func _rank(sheet: Node3D) -> int:
	var at := order.find(sheet.name)
	if at >= 0:
		return at
	at = fade_order.find(sheet.name)
	return order.size() + 1 + at if at >= 0 else order.size()


## True while the sheets fall, until the last sheet before [member fade_order] lands: the night waits
## for it.
func busy() -> bool:
	return stage() == 1 and _step < _night_step


func _apply(shown_stage: int) -> void:
	if shown_stage == 1:
		if not is_processing():
			_fall()
		return
	set_process(false)
	if shown_stage == 0:
		_remove_copies()
		_place(false)
	elif not _fallen:  # stage 2 without the whole fall: they stay where it ends
		_remove_copies()
		_place(true)
	_fallen = shown_stage != 0


func _process(delta: float) -> void:
	_clock += delta
	while _clock >= trail_step:
		_clock -= trail_step
		_step += 1
		var falling := false
		for index: int in _sheets.size():
			var path: Array = _paths[index]
			var since := (_step - _starts[index]) * trail_step
			var on_path := _step - _starts[index] - _shake_steps()
			if on_path < 0:
				_sheets[index].global_transform = _shaken(index, maxf(since, 0.0))
				falling = true
			elif on_path < path.size():
				_hold_stays(index, true)
				_sheets[index].global_transform = path[on_path]
				_leave_copy(_meshes[index])
				falling = true
		if not falling:
			_fallen = true
			set_stage(2)
			return


# Sheet [param index] on the wall, [param since] seconds into its shake: it tilts to and fro about
# its middle, further as the shake goes on.
func _shaken(index: int, since: float) -> Transform3D:
	var home := _homes[index]
	var tilt := deg_to_rad(shake_degrees) * minf(since / maxf(shake_seconds, 0.01), 1.0) * sin(since * shake_rate * TAU)
	return Transform3D(home.basis.rotated(home.basis.z.normalized(), tilt), home.origin)


func _fall() -> void:
	_remove_copies()
	_place(false)
	_paths = _sheets.map(_path_of)
	_starts.clear()
	_night_step = 0
	var faded := 0
	for index: int in _sheets.size():
		if fade_order.has(_sheets[index].name):  # _rank sorts these last, so _night_step is final here
			_starts.append(_night_step - _shake_steps() + roundi(faded * fade_stagger_seconds / trail_step))
			faded += 1
		else:
			_starts.append(roundi((lead_seconds + index * stagger_seconds) / trail_step))
			_night_step = maxi(_night_step, _starts[index] + _shake_steps() + (_paths[index] as Array).size())
	_fallen = false
	_step = -1
	_clock = trail_step
	set_process(true)


func _shake_steps() -> int:
	return roundi(shake_seconds / trail_step)


# Where [param sheet] is at each trail step, from its place on the wall to where it stays on the floor.
func _path_of(sheet: Node3D) -> Array[Transform3D]:
	var home := _homes[_sheets.find(sheet)]
	var scale := Basis.from_scale(home.basis.get_scale())
	var from := home.basis.get_rotation_quaternion()
	var bottom := _bottom_of(sheet)
	var drop := maxf(home.origin.y - bottom - floor_height, 0.01)
	var to_floor := (jump_speed + sqrt(jump_speed * jump_speed + 2.0 * gravity * drop)) / gravity
	var side := 1.0 if home.origin.x < 0.0 else -1.0
	var lane := fade_lane_z if fade_order.has(sheet.name) else lane_z
	var speed := Vector3(side * side_speed, jump_speed, (lane - home.origin.z) / to_floor)
	var at := home.origin
	var left := bounces
	var points: Array[Transform3D] = []
	while points.size() < MAX_STEPS:
		speed.y -= gravity * trail_step
		at += speed * trail_step
		var landed := at.y - bottom <= floor_height and speed.y < 0.0
		if landed:
			at.y = floor_height + bottom
			at.z = lane
			speed.z = 0.0
			speed.y *= -bounce
		var turned := from.slerp(Quaternion.IDENTITY, minf(points.size() * trail_step / turn_seconds, 1.0))
		points.append(Transform3D(Basis(turned) * scale, at))
		if landed:
			if left <= 0:
				break
			left -= 1
	return points


# How far the lowest point of [param sheet]'s meshes lies below its origin, in metres.
func _bottom_of(sheet: Node3D) -> float:
	var lowest := 0.0
	var to_local := sheet.global_transform.affine_inverse()
	for mesh: GeometryInstance3D in _meshes[_sheets.find(sheet)]:
		lowest = minf(lowest, ((to_local * mesh.global_transform) * mesh.get_aabb()).position.y)
	return -lowest * sheet.global_basis.get_scale().y


# Puts each sheet on the wall, or where its fall ends when [param fallen].
func _place(fallen: bool) -> void:
	for index: int in _sheets.size():
		_sheets[index].global_transform = _homes[index]
		_hold_stays(index, false)
	if fallen:
		for index: int in _sheets.size():
			_sheets[index].global_transform = _path_of(_sheets[index])[-1]
			_hold_stays(index, true)


# Keeps sheet [param index]'s stays where they hang at home while [param held], or back on the sheet.
func _hold_stays(index: int, held: bool) -> void:
	var stays: Array = _stays[index]
	for at: int in stays.size():
		var stay: Node3D = stays[at]
		if stay.top_level == held:
			continue
		stay.top_level = held
		if held:
			stay.global_transform = _stay_places[index][at]
		else:
			stay.transform = _stay_homes[index][at]


func _leave_copy(meshes: Array[GeometryInstance3D]) -> void:
	for mesh: GeometryInstance3D in meshes:
		if not mesh.is_visible_in_tree():
			continue
		var copy: GeometryInstance3D
		if mesh is Label3D:  # a label draws in the transparent pass on its own
			copy = mesh.duplicate(0) as Label3D
		else:
			copy = MeshInstance3D.new()
			(copy as MeshInstance3D).mesh = (mesh as MeshInstance3D).mesh
			copy.material_override = _layered_material(mesh as MeshInstance3D)
		copy.sorting_offset = _copies * LAYER_METRES
		_copies += 1
		copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_trail.add_child(copy)
		copy.global_transform = mesh.global_transform


func _remove_copies() -> void:
	for copy: Node in _trail.get_children():
		copy.queue_free()
	_copies = 0
	_layered.clear()  # a logo may have changed its art since


# [param mesh]'s material in the transparent pass; its own material, which can't layer, when it is
# neither psx_world nor a BaseMaterial3D.
func _layered_material(mesh: MeshInstance3D) -> Material:
	var material := mesh.get_active_material(0)
	if not _layered.has(material):
		var psx := material as ShaderMaterial
		if material is BaseMaterial3D:
			var blended := material.duplicate() as BaseMaterial3D
			blended.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_layered[material] = blended
		elif psx == null or psx.shader != _PSX_WORLD:
			push_error("posters_bounce: %s has neither a psx_world nor a BaseMaterial3D material, so its trail can't draw over the earlier copies" % mesh.get_path())
			_layered[material] = material
		else:
			var layered := psx.duplicate() as ShaderMaterial
			layered.shader = _PSX_LAYERED
			_layered[material] = layered
	return _layered[material]
