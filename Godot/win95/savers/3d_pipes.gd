extends Saver
## The 3D Pipes screensaver, as Win95 OSR2's SSPIPES.SCR draws it by default: one shiny pipe at a time
## grows through a 3D grid seen straight down its depth, turning at rounded elbows, until it runs into
## a dead end or reaches its length; then the next starts in a new colour. Once the grid holds
## [member full_segments], the picture dissolves to black and the pipes start over. Any key, click or
## mouse move ends it.

## The grid's size in cells; one segment spans one cell.
var grid := Vector3i(20, 20, 20)
## How far in front of the grid's front face the camera stands, in cells.
var eye_distance: float = 6.0
## The camera's vertical field of view, in degrees.
var fov: float = 75.0
## Segments per second.
var segments_per_second: float = 12.0
## How long a pipe grows, in segments, unless it runs into a dead end first.
var pipe_length := Vector2i(40, 120)
## How many segments fill the picture before it dissolves.
var full_segments: int = 650
## The chance, 0 to 1, that a pipe turns at a cell where it could go straight on.
var turn_chance: float = 0.3
## The pipe's radius, as a share of a cell.
var pipe_radius: float = 0.26
## How long the dissolve to black takes, in seconds.
var dissolve_seconds: float = 1.5

const _DISSOLVE := preload("res://win95/savers/dissolve.gdshader")
const _DIRS: Array[Vector3i] = [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.DOWN, Vector3i.UP, Vector3i.FORWARD, Vector3i.BACK]
const _COLOURS: Array[Color] = [Color(0.4, 1.0, 0.45), Color(0.85, 0.85, 0.85), Color(0.1, 0.75, 0.7),
		Color(0.9, 0.15, 0.1), Color(0.2, 0.3, 1.0), Color(0.95, 0.85, 0.15), Color(0.85, 0.2, 0.85)]
const _BEND_SEGMENTS: int = 8
const _ROUND_SEGMENTS: int = 12

var _world: Node3D
var _dissolve: ShaderMaterial
var _occupied: Dictionary[Vector3i, bool] = {}
var _head := Vector3i.ZERO
## The way that the pipe came into [member _head]; ZERO before its first segment.
var _heading := Vector3i.ZERO
var _left: int = 0
var _material: StandardMaterial3D
var _segments: int = 0
var _due: float = 0.0
var _dissolve_time: float = -1.0
var _half_pipe: CylinderMesh
var _pipe: CylinderMesh
var _elbow: ArrayMesh


func _ready() -> void:
	super()
	var container := SubViewportContainer.new()
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(container)
	var viewport := SubViewport.new()
	viewport.own_world_3d = true  # else it draws the shop's world
	container.add_child(viewport)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color.BLACK
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.15, 0.15, 0.15)
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	viewport.add_child(world_environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -30, 0)
	viewport.add_child(light)
	var camera := Camera3D.new()
	camera.fov = fov
	camera.position = Vector3(grid.x / 2.0, grid.y / 2.0, grid.z + eye_distance)
	viewport.add_child(camera)
	_world = Node3D.new()
	viewport.add_child(_world)
	var overlay := ColorRect.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dissolve = ShaderMaterial.new()
	_dissolve.shader = _DISSOLVE
	overlay.material = _dissolve
	add_child(overlay)
	_pipe = _cylinder(1.0)
	_half_pipe = _cylinder(0.5)
	_elbow = _make_elbow()
	_new_pipe()


## How many segments the pipes have now.
func segment_count() -> int:
	return _segments


func _process(delta: float) -> void:
	if _dissolve_time >= 0.0:
		_dissolve_time += delta
		_dissolve.set_shader_parameter(&"progress", _dissolve_time / dissolve_seconds)
		if _dissolve_time >= dissolve_seconds:
			_dissolve_time = -1.0
			_dissolve.set_shader_parameter(&"progress", 0.0)
			_start_over()
		return
	_due += delta * segments_per_second
	while _due >= 1.0 and _dissolve_time < 0.0:
		_due -= 1.0
		_grow()


func _start_over() -> void:
	for child: Node in _world.get_children():
		child.queue_free()
	_occupied.clear()
	_segments = 0
	_due = 0.0
	_new_pipe()


func _new_pipe() -> void:
	for _attempt: int in 100:
		var at := Vector3i(randi() % grid.x, randi() % grid.y, randi() % grid.z)
		if not _occupied.has(at):
			_occupied[at] = true
			_head = at
			_heading = Vector3i.ZERO
			_left = randi_range(pipe_length.x, pipe_length.y)
			var last := _material.albedo_color if _material != null else Color.BLACK
			_material = StandardMaterial3D.new()
			_material.albedo_color = _COLOURS[randi() % _COLOURS.size()]
			while _material.albedo_color == last:
				_material.albedo_color = _COLOURS[randi() % _COLOURS.size()]
			_material.metallic_specular = 1.0
			_material.roughness = 0.3
			return
	_start_dissolve()  # the grid is full


# One segment on: the piece at the cell that the pipe leaves is a straight pipe or an elbow, now that
# its way out is known. A pipe at a dead end or at its length ends there, and the next one starts.
func _grow() -> void:
	var free := _DIRS.filter(func(d: Vector3i) -> bool: return _inside(_head + d) and not _occupied.has(_head + d))
	if free.is_empty() or _left <= 0:
		if _heading != Vector3i.ZERO:
			_add(_half_pipe, _straight(Vector3(_head) - Vector3(_heading) * 0.25, _heading))
		if _segments >= full_segments:
			_start_dissolve()
		else:
			_new_pipe()
		return
	var next := _heading
	if _heading == Vector3i.ZERO or _heading not in free or randf() < turn_chance:
		var turns := free.filter(func(d: Vector3i) -> bool: return d != _heading)
		next = turns[randi() % turns.size()] if not turns.is_empty() else _heading
	var at := Vector3(_head)
	if _heading == Vector3i.ZERO:
		_add(_half_pipe, _straight(at + Vector3(next) * 0.25, next))
	elif next == _heading:
		_add(_pipe, _straight(at, next))
	else:
		_add(_elbow, _bend(at, _heading, next))
	_head += next
	_heading = next
	_occupied[_head] = true
	_left -= 1
	_segments += 1


func _start_dissolve() -> void:
	_dissolve_time = 0.0


func _inside(at: Vector3i) -> bool:
	return at.x >= 0 and at.y >= 0 and at.z >= 0 and at.x < grid.x and at.y < grid.y and at.z < grid.z


func _add(mesh: Mesh, at: Transform3D) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material
	instance.transform = at
	_world.add_child(instance)


# A cylinder centred on [param centre], its Y axis along [param axis].
static func _straight(centre: Vector3, axis: Vector3i) -> Transform3D:
	var along := Vector3(axis)
	var basis := Basis() if along.abs() == Vector3.UP else Basis(Vector3.UP.cross(along).normalized(), PI / 2.0)
	return Transform3D(basis, centre)


# The elbow at [param at], from the middle of the face that the pipe came in by, along [param from],
# to the middle of the face that it leaves by, along [param to] (see [method _make_elbow]).
static func _bend(at: Vector3, from: Vector3i, to: Vector3i) -> Transform3D:
	var x := -Vector3(to)
	var y := Vector3(from)
	return Transform3D(Basis(x, y, x.cross(y)), at + (Vector3(to) - Vector3(from)) * 0.5)


func _cylinder(length: float) -> CylinderMesh:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = pipe_radius
	cylinder.bottom_radius = pipe_radius
	cylinder.height = length
	cylinder.radial_segments = _ROUND_SEGMENTS
	cylinder.rings = 1
	return cylinder


# A quarter torus of bend radius 0.5 around the origin in the XY plane, from (0.5, 0, 0), heading +Y,
# to (0, 0.5, 0), heading -X.
func _make_elbow() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in _BEND_SEGMENTS + 1:
		var angle := PI / 2.0 * i / _BEND_SEGMENTS
		var out := Vector3(cos(angle), sin(angle), 0.0)
		for j: int in _ROUND_SEGMENTS + 1:
			var around := TAU * j / _ROUND_SEGMENTS
			var normal := out * cos(around) + Vector3.BACK * sin(around)
			tool.set_normal(normal)
			tool.add_vertex(out * 0.5 + normal * pipe_radius)
	var ring := _ROUND_SEGMENTS + 1
	for i: int in _BEND_SEGMENTS:
		for j: int in _ROUND_SEGMENTS:
			var a := i * ring + j
			for index: int in [a, a + 1, a + ring, a + 1, a + ring + 1, a + ring]:  # clockwise from outside: Godot's front faces
				tool.add_index(index)
	return tool.commit()
