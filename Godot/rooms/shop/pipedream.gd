@tool
class_name Pipedream
extends Node3D
## Win95's 3D Pipes screensaver leaking into the shop: pipes grow out of this node's origin along
## -Z until they reach a free cell, then turn at random on a grid of free cells: inside
## [member bounds], outside [member solids], and in front of no hotspot as [member clear_views] see
## it. They show only while the corruption sign pipedream lets them in ([member stage]); then the
## higher the day's warp, the more of them shows. One seed always grows the same pipes; a higher warp
## shows more of them, never others. Each pipe grows only while the camera can't see where it grows
## next, so the player never sees one move.

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
		_retarget()
## How far the corruption sign pipedream lets the pipes in: 0 shows none, 1 grows them with
## [member warp], 2 grows all of them. Pipes grow in at [member grow_speed]; a lower stage takes
## them away at once.
var stage: int = 0:
	set(value):
		stage = value
		_retarget()

## The warp from which the pipes grow past [member first_amount]. Below it, the sign shows that many.
@export_range(0.0, 1.0, 0.01) var from_warp: float = 0.3
## The share of the pipes, 0 to 1, that shows when the sign starts, up to [member from_warp]. At
## warp 1, all of them show.
@export_range(0.0, 1.0, 0.01) var first_amount: float = 0.15
## How fast new pipe grows in at first, in segments per second for each pipe. The speed rises
## evenly with the share shown, up to [member late_grow_speed] when all of them show, so the pipes
## peek out for a while, then spread fast.
@export_range(0.05, 60.0, 0.05, "suffix:/s") var grow_speed: float = 0.15
@export_range(0.05, 60.0, 0.05, "suffix:/s") var late_grow_speed: float = 4.15

@export_group("Shape")
## Change any of these, then press Regrow.
@export_tool_button("Regrow") var regrow: Callable = _rebuild
## The space the pipes may turn in, in metres from this node.
@export var bounds: AABB = AABB(Vector3(-0.95, -4.0, -2.75), Vector3(1.45, 4.95, 2.85))
## The views whose clicks the pipes keep clear: no pipe passes in front of a hotspot under this
## node's parent, as seen from each view's eye (its marker), except on the way out of the origin.
@export var clear_views: Array[Node3D] = []
## The things that the pipes grow around rather than through, such as the desk top: each one's
## meshes, merged into a box.
@export var solids: Array[Node3D] = []
## The grid step, and the length of one segment, in metres.
@export_range(0.05, 1.0, 0.01, "suffix:m") var cell: float = 0.1
## One pipe per colour, at most 9.
@export var colors: Array[Color] = [
	Color(0.85, 0.12, 0.1), Color(0.12, 0.6, 0.2), Color(0.15, 0.3, 0.85), Color(0.9, 0.75, 0.1),
]
## The length of each pipe at warp 1, in segments. A pipe that runs into a dead end stops sooner.
@export_range(1, 1000) var segments: int = 500
## The chance, 0 to 1, that a pipe turns at a cell.
@export_range(0.0, 1.0, 0.01) var turn_chance: float = 0.25
@export var pipe_seed: int = 95
@export_range(0.005, 0.5, 0.005, "suffix:m") var radius: float = 0.025
@export_range(0.005, 0.5, 0.005, "suffix:m") var joint_radius: float = 0.04
## The material of the pipes; each pipe gets a copy with its colour as albedo_color.
@export var material: ShaderMaterial
## The warp that the editor shows.
@export_range(0.0, 1.0, 0.01) var preview_warp: float = 1.0:
	set(value):
		preview_warp = value
		if Engine.is_editor_hint() and is_node_ready():
			_show_all(amount(preview_warp))

## Per pipe: [segment MultiMesh, joint MultiMesh, the segment index of each joint, its cells, the
## share of it that shows].
var _pipes: Array[Array] = []
## Per clear view: {eye: the inverse of its marker's transform, hotspots: what _project gives for
## each hotspot in front of it}.
var _clear: Array[Dictionary] = []
var _solid_boxes: Array[AABB] = []
var _free_cells: Dictionary[Vector3i, bool] = {}  # what _free found, while _grow runs


func _ready() -> void:
	set_process(false)
	_rebuild()


func _process(delta: float) -> void:
	var target := _target()
	var camera := get_viewport().get_camera_3d()
	var grown := true
	for pipe: Array in _pipes:
		var share: float = pipe[4]
		if share < target and not _next_seen(pipe, camera):
			share = move_toward(share, target, lerpf(grow_speed, late_grow_speed, share) * delta / maxi(segments, 1))
			_show_share(pipe, share)
		grown = grown and is_equal_approx(share, target)
	if grown:
		set_process(false)


## True while the next segment of [param pipe] is in [param camera]'s view.
func _next_seen(pipe: Array, camera: Camera3D) -> bool:
	if camera == null:
		return false
	var path: Array[Vector3i] = pipe[3]
	var next := (pipe[0] as MultiMesh).visible_instance_count
	if next + 1 >= path.size():
		return false
	for k: int in [next, next + 1]:
		if camera.is_position_in_frustum(global_transform * (Vector3(path[k]) * cell)):
			return true
	return false


## The share of the pipes, 0 to 1, that shows at [param at_warp] in stage 1.
func amount(at_warp: float) -> float:
	if is_equal_approx(from_warp, 1.0):
		return 1.0 if is_equal_approx(at_warp, 1.0) else first_amount
	return lerpf(first_amount, 1.0, clampf((at_warp - from_warp) / (1.0 - from_warp), 0.0, 1.0))


# The share of the pipes that [member stage] and [member warp] show.
func _target() -> float:
	match stage:
		0:
			return 0.0
		1:
			return amount(warp)
	return 1.0


func _retarget() -> void:
	if not is_node_ready() or Engine.is_editor_hint():
		return
	var target := _target()
	var growing := false
	for pipe: Array in _pipes:
		_show_share(pipe, minf(pipe[4], target))
		growing = growing or not is_equal_approx(pipe[4], target)
	set_process(growing)


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
			path,
			0.0,
		])
	if Engine.is_editor_hint():
		_show_all(amount(preview_warp))
	else:
		_retarget()


## The cells of each pipe, in growing order. The pipes grow in turns, so none takes all the room.
func _grow() -> Array[Array]:
	_collect_clear()
	_free_cells.clear()
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
			var inside := _free(here)
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
				var leaving := not inside and dir == Vector3i.FORWARD and next.z * cell >= bounds.position.z
				var allowed := leaving or _free(next)
				if allowed and not taken.has(next):
					taken[next] = true
					path.append(next)
					dirs[i] = dir
					break
	return paths


## True when a pipe may turn at [param at]: inside [member bounds], clear of [member solids], and in
## front of no hotspot as a clear view sees it.
func _free(at: Vector3i) -> bool:
	if not _free_cells.has(at):
		_free_cells[at] = _clear_of_all(at)
	return _free_cells[at]


func _clear_of_all(at: Vector3i) -> bool:
	if not bounds.has_point(Vector3(at) * cell):
		return false
	var half := Vector3.ONE * (cell * 0.5 + joint_radius)
	var box := global_transform * AABB(Vector3(at) * cell - half, half * 2.0)
	for solid: AABB in _solid_boxes:
		if solid.intersects(box):
			return false
	for view: Dictionary in _clear:
		var seen := _project(view.eye, box)
		if seen.is_empty():
			continue
		for hotspot: Dictionary in view.hotspots:
			if seen.near < hotspot.far and (seen.rect as Rect2).intersects(hotspot.rect):
				return false
	return true


func _collect_clear() -> void:
	_clear.clear()
	_solid_boxes.clear()
	var hotspots: Array[AABB] = []
	if get_parent() != null:
		for area: Node in get_parent().find_children("*", "Area3D", true, false):
			if area is Hotspot:
				var size: Vector3 = area.get(&"size")
				hotspots.append((area as Node3D).global_transform * AABB(-size * 0.5, size))
	for view: Node3D in clear_views:
		if view == null:
			push_error("Pipedream %s: a clear view is empty" % get_path())
			continue
		var eye := view.global_transform.affine_inverse()
		var in_front: Array[Dictionary] = []
		for hotspot: AABB in hotspots:
			var seen := _project(eye, hotspot)
			if not seen.is_empty():
				in_front.append(seen)
		_clear.append({"eye": eye, "hotspots": in_front})
	for solid: Node3D in solids:
		if solid == null:
			push_error("Pipedream %s: a solid is empty" % get_path())
			continue
		var merged := AABB()
		var meshes := solid.find_children("*", "GeometryInstance3D", true, false)
		if solid is GeometryInstance3D:
			meshes.append(solid)
		for mesh: GeometryInstance3D in meshes:
			var box := mesh.global_transform * mesh.get_aabb()
			merged = box if merged.size == Vector3.ZERO else merged.merge(box)
		if merged.size == Vector3.ZERO:
			push_error("Pipedream %s: the solid %s has no mesh" % [get_path(), solid.get_path()])
			continue
		_solid_boxes.append(merged)


## [param box] as [param eye] sees it: {rect: its corners on a screen one metre ahead, near and far:
## its nearest and farthest depth}. Empty when any corner is behind the eye.
static func _project(eye: Transform3D, box: AABB) -> Dictionary:
	var rect := Rect2()
	var near := INF
	var far := 0.0
	for i: int in 8:
		var local := eye * box.get_endpoint(i)
		var depth := -local.z
		if depth < 0.05:
			return {}
		var point := Vector2(local.x, local.y) / depth
		rect = Rect2(point, Vector2.ZERO) if i == 0 else rect.expand(point)
		near = minf(near, depth)
		far = maxf(far, depth)
	return {"rect": rect, "near": near, "far": far}


func _show_all(share: float) -> void:
	for pipe: Array in _pipes:
		_show_share(pipe, share)


func _show_share(pipe: Array, share: float) -> void:
	pipe[4] = share
	var segment_multimesh: MultiMesh = pipe[0]
	var joint_at: Array[int] = pipe[2]
	var count := roundi(share * segment_multimesh.instance_count)
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
