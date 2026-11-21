@tool
class_name Pipedream
extends Node3D
## Win95's 3D Pipes screensaver leaking into the shop: pipes grow out of this node's origin along
## -Z, then turn at random on a grid inside [member bounds]. The higher the day's warp, the more of
## them shows. One seed always grows the same pipes; a higher warp shows more of them, never others.

const DIRS: Array[Vector3i] = [
	Vector3i.LEFT, Vector3i.RIGHT, Vector3i.DOWN, Vector3i.UP, Vector3i.FORWARD, Vector3i.BACK,
]
## Where the pipes after the first start, in cells from the origin.
const STARTS: Array[Vector3i] = [
	Vector3i.ZERO, Vector3i.UP, Vector3i.RIGHT, Vector3i(1, 1, 0), Vector3i.DOWN,
	Vector3i(1, -1, 0), Vector3i.LEFT, Vector3i(-1, 1, 0), Vector3i(-1, -1, 0),
]

## The day's warp, 0 to 1 ([member Day.warp]). The pipes grow to match it at [member grow_speed];
## a lower warp, as after a reboot, takes them away at once.
var warp: float = 0.0:
	set(value):
		warp = value
		if is_node_ready():
			_shown = minf(_shown, amount(warp))
			_show()
			set_process(not is_equal_approx(_shown, amount(warp)))

## The warp of the first day with pipes. Below it, none show.
@export_range(0.0, 1.0, 0.01) var from_warp: float = 0.3
## The share of the pipes that shows at [member from_warp], 0 to 1. At warp 1, all of them show.
@export_range(0.0, 1.0, 0.01) var first_amount: float = 0.15
## How fast new pipe grows in, in segments per second for each pipe.
@export_range(0.5, 60.0, 0.5, "suffix:/s") var grow_speed: float = 4.0

@export_group("Shape")
## Change any of these, then press Regrow.
@export_tool_button("Regrow") var regrow: Callable = _rebuild
## The space the pipes may turn in, in metres from this node. They leave the origin straight
## along -Z until they are inside it.
@export var bounds: AABB = AABB(Vector3(-0.05, -0.8, -2.2), Vector3(1.15, 2.85, 2.15))
## The grid step, and the length of one segment, in metres.
@export_range(0.05, 1.0, 0.01, "suffix:m") var cell: float = 0.2
## One pipe per colour, at most 9.
@export var colors: Array[Color] = [
	Color(0.85, 0.12, 0.1), Color(0.12, 0.6, 0.2), Color(0.15, 0.3, 0.85), Color(0.9, 0.75, 0.1),
]
## The length of each pipe at warp 1, in segments. A pipe that runs into a dead end stops sooner.
@export_range(1, 500) var segments: int = 60
## The chance, 0 to 1, that a pipe turns at a cell.
@export_range(0.0, 1.0, 0.01) var turn_chance: float = 0.3
@export var pipe_seed: int = 95
@export_range(0.005, 0.5, 0.005, "suffix:m") var radius: float = 0.035
@export_range(0.005, 0.5, 0.005, "suffix:m") var joint_radius: float = 0.06
## The material of the pipes; each pipe gets a copy with its colour as albedo_color.
@export var material: ShaderMaterial
## The warp that the editor shows.
@export_range(0.0, 1.0, 0.01) var preview_warp: float = 1.0:
	set(value):
		preview_warp = value
		if Engine.is_editor_hint() and is_node_ready():
			_shown = amount(preview_warp)
			_show()

var _shown: float = 0.0
## Per pipe: [segment MultiMesh, joint MultiMesh, the segment index of each joint].
var _pipes: Array[Array] = []


func _ready() -> void:
	set_process(false)
	_rebuild()


func _process(delta: float) -> void:
	var target := amount(warp)
	_shown = move_toward(_shown, target, grow_speed * delta / maxi(segments, 1))
	_show()
	if is_equal_approx(_shown, target):
		set_process(false)


## The share of the pipes, 0 to 1, that shows at [param at_warp].
func amount(at_warp: float) -> float:
	if at_warp < from_warp and not is_equal_approx(at_warp, from_warp):
		return 0.0
	if is_equal_approx(from_warp, 1.0):
		return 1.0
	return lerpf(first_amount, 1.0, clampf((at_warp - from_warp) / (1.0 - from_warp), 0.0, 1.0))


## The segments that show now, over all pipes.
func shown_segments() -> int:
	var count := 0
	for pipe: Array in _pipes:
		count += (pipe[0] as MultiMesh).visible_instance_count
	return count


func _rebuild() -> void:
	for child: Node in get_children():
		child.queue_free()
	_pipes.clear()
	if material == null:
		push_error("Pipedream %s: no material" % get_path())
		return
	if colors.size() > STARTS.size():
		push_error("Pipedream %s: %d colours, but at most %d pipes" % [get_path(), colors.size(), STARTS.size()])
		return
	var segment_mesh := CylinderMesh.new()
	segment_mesh.top_radius = radius
	segment_mesh.bottom_radius = radius
	segment_mesh.height = cell
	segment_mesh.radial_segments = 6
	segment_mesh.rings = 0
	var joint_mesh := SphereMesh.new()
	joint_mesh.radius = joint_radius
	joint_mesh.height = joint_radius * 2.0
	joint_mesh.radial_segments = 6
	joint_mesh.rings = 3
	var paths := _grow()
	for i: int in paths.size():
		var path: Array[Vector3i] = paths[i]
		var pipe_material := material.duplicate() as ShaderMaterial
		pipe_material.set_shader_parameter(&"albedo_color", colors[i])
		var segment_transforms: Array[Transform3D] = []
		var joint_transforms: Array[Transform3D] = []
		var joint_at: Array[int] = []
		for k: int in range(1, path.size()):
			var dir := path[k] - path[k - 1]
			segment_transforms.append(Transform3D(_basis_along(dir), (Vector3(path[k - 1]) + Vector3(dir) * 0.5) * cell))
			if k + 1 < path.size() and path[k + 1] - path[k] != dir:
				joint_transforms.append(Transform3D(Basis.IDENTITY, Vector3(path[k]) * cell))
				joint_at.append(k)
		_pipes.append([
			_add_multimesh(segment_mesh, segment_transforms, pipe_material),
			_add_multimesh(joint_mesh, joint_transforms, pipe_material),
			joint_at,
		])
	_shown = amount(preview_warp if Engine.is_editor_hint() else warp)
	_show()


## The cells of each pipe, in growing order. The pipes grow in turns, so none takes all the room.
func _grow() -> Array[Array]:
	var rng := RandomNumberGenerator.new()
	rng.seed = pipe_seed
	var taken: Dictionary[Vector3i, bool] = {}
	var paths: Array[Array] = []
	var dirs: Array[Vector3i] = []
	for i: int in colors.size():
		var path: Array[Vector3i] = [STARTS[i]]
		var start := Vector3(STARTS[i]) * cell
		if not bounds.has_point(start) and not bounds.intersects_segment(start, start + Vector3.FORWARD * 1000.0):
			push_error("Pipedream %s: pipe %d starts at %s, which never reaches the bounds %s along -Z" % [get_path(), i, start, bounds])
			path.clear()
		else:
			taken[STARTS[i]] = true
		paths.append(path)
		dirs.append(Vector3i.FORWARD)
	for step: int in segments:
		for i: int in paths.size():
			var path: Array[Vector3i] = paths[i]
			if path.size() <= step:
				continue  # ran into a dead end, or never started
			var here: Vector3i = path[-1]
			var inside := bounds.has_point(Vector3(here) * cell)
			var options: Array[Vector3i] = []
			for dir: Vector3i in DIRS:
				if dir != dirs[i] and dir != -dirs[i]:
					options.append(dir)
			_shuffle(options, rng)
			if not inside or rng.randf() >= turn_chance:
				options.push_front(dirs[i])
			else:
				options.push_back(dirs[i])
			for dir: Vector3i in options:
				var next := here + dir
				var allowed := bounds.has_point(Vector3(next) * cell) or (not inside and dir == Vector3i.FORWARD)
				if allowed and not taken.has(next):
					taken[next] = true
					path.append(next)
					dirs[i] = dir
					break
	return paths


func _show() -> void:
	for pipe: Array in _pipes:
		var segment_multimesh: MultiMesh = pipe[0]
		var joint_at: Array[int] = pipe[2]
		var count := roundi(_shown * segment_multimesh.instance_count)
		segment_multimesh.visible_instance_count = count
		(pipe[1] as MultiMesh).visible_instance_count = joint_at.bsearch(count, false)


func _add_multimesh(mesh: Mesh, transforms: Array[Transform3D], pipe_material: Material) -> MultiMesh:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for j: int in transforms.size():
		multimesh.set_instance_transform(j, transforms[j])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.material_override = pipe_material
	add_child(instance)  # no owner: the pipes are made at load, never saved into the scene
	return multimesh


## Turns a cylinder, which stands along Y, to lie along [param dir].
static func _basis_along(dir: Vector3i) -> Basis:
	if dir.x != 0:
		return Basis(Vector3.BACK, PI / 2.0)
	if dir.z != 0:
		return Basis(Vector3.RIGHT, PI / 2.0)
	return Basis.IDENTITY


## Fisher-Yates with [param rng], so the same seed always shuffles the same way.
static func _shuffle(items: Array[Vector3i], rng: RandomNumberGenerator) -> void:
	for j: int in range(items.size() - 1, 0, -1):
		var k := rng.randi_range(0, j)
		var swap := items[j]
		items[j] = items[k]
		items[k] = swap
