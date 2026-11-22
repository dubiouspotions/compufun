extends CorruptionSign
## The sheets in the group solitaire_posters (the logo on the left wall, the poster on the right wall)
## leave the wall like the cards of the Solitaire win: each turns to face the counter, drops to the
## floor between the counter and the door, bounces lower and lower towards the other side of the
## shop, and leaves a still copy of itself at every step, lit like the room. Stage 1 plays it, and the
## night waits for it ([method busy]); then it sets stage 2: the sheets stay on the floor, the trail
## behind them. Stage 0 hangs them back on the wall.

const SHEETS: StringName = &"solitaire_posters"
## A fall that never reaches the floor stops after this many steps.
const MAX_STEPS: int = 1000

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
var _meshes: Array = []  # one Array[MeshInstance3D] per sheet
var _paths: Array = []  # one Array[Transform3D] per sheet
var _fallen: bool = false
var _step: int = 0
var _clock: float = 0.0

@onready var _trail: Node3D = %Trail


func _ready() -> void:
	for node: Node in get_tree().get_nodes_in_group(SHEETS):
		var sheet := node as Node3D
		_sheets.append(sheet)
		_homes.append(sheet.global_transform)
		var meshes: Array[MeshInstance3D] = []
		if sheet is MeshInstance3D:
			meshes.append(sheet as MeshInstance3D)
		for mesh: Node in sheet.find_children("*", "MeshInstance3D", true, false):
			meshes.append(mesh as MeshInstance3D)
		_meshes.append(meshes)
	if _sheets.is_empty():
		push_error("posters_bounce: nothing in the group %s" % SHEETS)
	set_process(false)
	super()


## True while the sheets fall: the night waits for it.
func busy() -> bool:
	return stage() == 1


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
		var moved := false
		for index: int in _sheets.size():
			var path: Array = _paths[index]
			if _step < path.size():
				_sheets[index].global_transform = path[_step]
				_leave_copy(_meshes[index])
				moved = true
		if not moved:
			_fallen = true
			set_stage(2)
			return


func _fall() -> void:
	_remove_copies()
	_place(false)
	_paths = _sheets.map(_path_of)
	_fallen = false
	_step = -1
	_clock = trail_step
	set_process(true)


# Where [param sheet] is at each trail step, from its place on the wall to where it stays on the floor.
func _path_of(sheet: Node3D) -> Array[Transform3D]:
	var home := _homes[_sheets.find(sheet)]
	var scale := Basis.from_scale(home.basis.get_scale())
	var from := home.basis.get_rotation_quaternion()
	var bottom := _bottom_of(sheet)
	var drop := maxf(home.origin.y - bottom - floor_height, 0.01)
	var to_floor := (jump_speed + sqrt(jump_speed * jump_speed + 2.0 * gravity * drop)) / gravity
	var side := 1.0 if home.origin.x < 0.0 else -1.0
	var speed := Vector3(side * side_speed, jump_speed, (lane_z - home.origin.z) / to_floor)
	var at := home.origin
	var left := bounces
	var points: Array[Transform3D] = []
	while points.size() < MAX_STEPS:
		speed.y -= gravity * trail_step
		at += speed * trail_step
		var landed := at.y - bottom <= floor_height and speed.y < 0.0
		if landed:
			at.y = floor_height + bottom
			at.z = lane_z
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
	for mesh: MeshInstance3D in _meshes[_sheets.find(sheet)]:
		lowest = minf(lowest, ((to_local * mesh.global_transform) * mesh.get_aabb()).position.y)
	return -lowest * sheet.global_basis.get_scale().y


# Puts each sheet on the wall, or where its fall ends when [param fallen].
func _place(fallen: bool) -> void:
	for index: int in _sheets.size():
		_sheets[index].global_transform = _homes[index]
	if fallen:
		for index: int in _sheets.size():
			_sheets[index].global_transform = _path_of(_sheets[index])[-1]


func _leave_copy(meshes: Array[MeshInstance3D]) -> void:
	for mesh: MeshInstance3D in meshes:
		var copy := MeshInstance3D.new()
		copy.mesh = mesh.mesh
		copy.material_override = mesh.material_override
		copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_trail.add_child(copy)
		copy.global_transform = mesh.global_transform


func _remove_copies() -> void:
	for copy: Node in _trail.get_children():
		copy.queue_free()
