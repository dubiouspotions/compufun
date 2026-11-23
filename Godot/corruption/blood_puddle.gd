extends CorruptionSign
## Blood that seeped out under a computer as it was set down on the counter, and stays there for
## the rest of the game. Stage n: the blood lies at counter slot n - 1 (see JobSlots), where the
## computer stood. A puddle under the computer runs in a rivulet across the work mat to the
## counter's near edge (+Z from the slot), down the counter's front, and drips onto the floor into a
## second puddle. Started during play, it plays out over [method settled_seconds]; after a jump it
## shows the settled state at once. It drips for as long as it shows. [member shape_seed] decides
## every shape, so it looks the same every time.

@export_group("Counter")
## From the slot's marker along +Z to the counter's near edge, in metres. shop.tscn: the counter's
## Top reaches z -0.87 and JobSlots stands at z -1.2.
@export var edge_distance: float = 0.33
## From the work mat's top down to the bottom of the counter top's front face, in metres: the mat
## (0.012) and the Top (0.05).
@export var lip_depth: float = 0.062
## From the work mat's top down to the floor, in metres.
@export var floor_depth: float = 1.012
## How far the counter's top juts out past the front of its body, in metres.
@export var overhang: float = 0.055

@export_group("Puddle")
## Where the puddle's middle lies from the slot's marker, in metres: under the tower's front right
## corner, so that it seeps out at the front and the side.
@export var offset: Vector3 = Vector3(0.1, 0.0, 0.08)
## About how far the puddle reaches from its middle, in metres.
@export var radius: float = 0.16
## How ragged the rims of the puddles and blobs are: 0 round, 1 very ragged.
@export_range(0.0, 1.0) var ragged: float = 0.45
## How long the puddle takes to seep out to its full size after the drop-off, in seconds.
@export var seep_seconds: float = 10.0
## The colour that the middle of each puddle and blob darkens to.
@export var core_color: Color = Color(0.09, 0.0, 0.01)
## How much of the middle is [member core_color]: 0 none, 1 all of it.
@export_range(0.0, 1.0) var core: float = 0.8

@export_group("Rivulet")
## Where the rivulet leaves the puddle, from the slot's marker, in metres. It runs from there along
## +Z to the counter's edge.
@export var rivulet_from: Vector3 = Vector3(0.2, 0.0, 0.19)
## How far the rivulet ends up sideways (+X) at the edge from where it started, in metres.
@export var rivulet_drift: float = 0.05
## How far each blob strays sideways from the rivulet's line, at most, in metres.
@export var wander: float = 0.008
## The flat blobs that make up the rivulet, one after another.
@export_range(2, 32) var blobs: int = 8
## How wide a blob is, in metres; each is long enough to overlap the next.
@export var blob_width: float = 0.028
## When the first blob starts to grow, in seconds after the drop-off.
@export var rivulet_delay: float = 2.0
## From the first blob's start until the last blob is full at the edge, in seconds.
@export var rivulet_seconds: float = 12.0
## How long one blob takes to grow to its full size, in seconds.
@export var blob_grow_seconds: float = 4.0

@export_group("Drip")
## How wide the streak down the counter's front is at its top, in metres.
@export var streak_width: float = 0.018
## How long the streak takes to run down the counter's front once the rivulet is at the edge, in
## seconds. The drip starts when it is down.
@export var streak_seconds: float = 3.0
## How wide the blood that runs down the body of the counter to the floor is, in metres, and how long
## it takes to get there once the streak is down, in seconds.
@export var run_width: float = 0.026
@export var run_seconds: float = 8.0
## How big a drop swells before it falls, in metres.
@export var drop_radius: float = 0.012
## From one drop to the next, in seconds.
@export var drip_seconds: float = 3.0
## How long a drop swells at the bottom of the streak before it falls, in seconds; shorter than
## [member drip_seconds].
@export var swell_seconds: float = 2.2
## How fast a falling drop speeds up, in metres per second squared.
@export var gravity: float = 9.8
## About how far the puddle on the floor reaches at its full size, in metres.
@export var floor_radius: float = 0.08
## How long the floor puddle takes to grow to its full size from the first drop, in seconds.
@export var floor_grow_seconds: float = 60.0

@export_group("Look")
## Every rim, the rivulet's path and its timing; another seed gives another shape.
@export var shape_seed: int = 7
## How high above the surface under it the blood lies, in metres; clear of z-fighting.
@export var lift: float = 0.0015
## Needs vertex_color_fade on: the meshes' vertex colours darken the middles.
@export var material: Material = preload("res://materials/blood_pool.tres")

const RIM_POINTS: int = 14
const TEXTURE_METRES: float = 0.2 ## How many metres one repeat of the texture spans.

var _jump: int = -1
var _shown_stage: int = 0
var _elapsed: float = 0.0
var _blob_starts: PackedFloat64Array = []
var _blob_nodes: Array[MeshInstance3D] = []
var _rivulet_end := Vector3.ZERO

@onready var _blood: Node3D = %Blood
@onready var _puddle: MeshInstance3D = %Puddle
@onready var _rivulet: Node3D = %Rivulet
@onready var _streak: MeshInstance3D = %Streak
@onready var _run: MeshInstance3D = %Run
@onready var _drop: MeshInstance3D = %Drop
@onready var _floor_puddle: MeshInstance3D = %FloorPuddle


func _ready() -> void:
	set_process(false)
	_build()
	super()


## Seconds from the drop-off until the blood has run its course and the floor puddle is full. After
## that, only the drip moves.
func settled_seconds() -> float:
	return _first_landing() + floor_grow_seconds


func _apply(shown_stage: int) -> void:
	var live := _jump == Game.jump
	_jump = Game.jump
	if shown_stage != _shown_stage:
		_shown_stage = shown_stage
		_blood.visible = false
		set_process(false)
		if shown_stage == 0:
			return
		var slots := get_tree().get_first_node_in_group(&"job_slots") as JobSlots
		if slots == null:
			push_error("blood_puddle: no JobSlots in the group job_slots")
			return
		var marker := slots.slot_marker(shown_stage - 1)
		if marker == null:
			return
		_blood.global_transform = marker.global_transform
		_blood.visible = true
		set_process(true)
		_elapsed = 0.0 if live else settled_seconds()
	elif shown_stage > 0 and not live:
		_elapsed = maxf(_elapsed, settled_seconds())
	_show()


func _process(delta: float) -> void:
	_elapsed += delta
	_show()


# Shows every piece as it is _elapsed seconds after the drop-off.
func _show() -> void:
	_grow(_puddle, maxf(0.15, _ease(_elapsed / seep_seconds)))
	for i: int in _blob_nodes.size():
		_grow(_blob_nodes[i], _ease((_elapsed - _blob_starts[i]) / blob_grow_seconds))
	var streak := _ease((_elapsed - _streak_start()) / streak_seconds)
	_streak.visible = streak > 0.0
	_streak.scale = Vector3(streak_width, lip_depth * maxf(streak, 0.01), 1.0)
	var run := _ease((_elapsed - _streak_start() - streak_seconds) / run_seconds)
	_run.visible = run > 0.0
	_run.scale = Vector3(run_width, (floor_depth - lip_depth) * maxf(run, 0.01), 1.0)
	_show_drop()
	var drip := _elapsed - _first_landing()
	var landed := floorf(drip / drip_seconds) + 1.0 if drip >= 0.0 else 0.0
	_grow(_floor_puddle, sqrt(clampf(landed * drip_seconds / floor_grow_seconds, 0.0, 1.0)))


# A drop swells at the bottom of the streak, falls to the floor and lands, every drip_seconds.
func _show_drop() -> void:
	var drip := _elapsed - _streak_start() - streak_seconds
	if drip < 0.0:
		_drop.visible = false
		return
	var phase := fmod(drip, drip_seconds)
	var hang := Vector3(_rivulet_end.x, -lip_depth, edge_distance + drop_radius)
	if phase < swell_seconds:
		var size := drop_radius * _ease(phase / swell_seconds)
		_drop.visible = size > 0.0
		_drop.position = hang + Vector3.DOWN * size * 0.8
		_drop.scale = Vector3(size, size * 1.3, size) if size > 0.0 else Vector3.ONE * drop_radius
		return
	var fall := phase - swell_seconds
	var drop := drop_radius * 0.8 + 0.5 * gravity * fall * fall
	_drop.visible = drop < floor_depth - lip_depth
	_drop.position = hang + Vector3.DOWN * drop
	_drop.scale = Vector3(drop_radius * 0.7, drop_radius * 2.0, drop_radius * 0.7)


func _streak_start() -> float:
	return rivulet_delay + rivulet_seconds


func _first_landing() -> float:
	return _streak_start() + streak_seconds + swell_seconds + sqrt(2.0 * (floor_depth - lip_depth) / gravity)


# Shows node at share (0 to 1) of its full size; hidden at 0.
func _grow(node: Node3D, share: float) -> void:
	node.visible = share > 0.0
	node.scale = Vector3.ONE * maxf(share, 0.01)


# Ease-out from 0 to 1 over t in 0 to 1; 0 before, 1 after.
func _ease(t: float) -> float:
	return sin(clampf(t, 0.0, 1.0) * PI / 2.0)


func _build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = shape_seed
	_puddle.mesh = _disk(rng, Vector2(radius, radius))
	_puddle.position = offset + Vector3.UP * lift
	var path := Vector3(rivulet_drift, 0.0, edge_distance - rivulet_from.z)
	var spacing := path.length() / blobs
	var steps := PackedFloat64Array()
	for i: int in blobs - 1:
		steps.append(rng.randf_range(0.5, 1.5))
	var total := 0.0
	for step: float in steps:
		total += step
	var start := 0.0
	for i: int in blobs:
		var blob := MeshInstance3D.new()
		blob.mesh = _disk(rng, Vector2(blob_width / 2.0, spacing * 0.9))
		blob.material_override = material
		blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Each next blob a little higher, so that their overlaps don't z-fight.
		var stray := Vector3(rng.randf_range(-wander, wander), lift * (1.2 + 0.1 * i), 0.0)
		blob.position = rivulet_from + path * (i + 0.5) / blobs + stray
		blob.rotation.y = atan2(path.x, path.z) + rng.randf_range(-0.3, 0.3)
		_rivulet.add_child(blob)
		_blob_nodes.append(blob)
		_blob_starts.append(rivulet_delay + start)
		if i < steps.size():
			start += (rivulet_seconds - blob_grow_seconds) * steps[i] / total
	_rivulet_end = _blob_nodes[-1].position
	_streak.mesh = _streak_mesh()
	_streak.position = Vector3(_rivulet_end.x, 0.0, edge_distance + lift)
	_run.mesh = _streak.mesh
	_run.position = Vector3(_rivulet_end.x, -lip_depth, edge_distance - overhang + lift)
	_drop.mesh = _drop_mesh()
	_floor_puddle.mesh = _disk(rng, Vector2(floor_radius, floor_radius))
	_floor_puddle.position = Vector3(_rivulet_end.x, lift - floor_depth, edge_distance + floor_radius * 0.5)
	for mesh: MeshInstance3D in [_puddle, _streak, _run, _drop, _floor_puddle]:
		mesh.material_override = material


# A flat fan of triangles with a ragged rim, half-sizes size.x across and size.y along +Z; the
# texture lies flat across it, and the middle darkens to core_color.
func _disk(rng: RandomNumberGenerator, size: Vector2) -> ArrayMesh:
	var rim := PackedVector3Array()
	for i: int in RIM_POINTS:
		var angle := TAU * i / RIM_POINTS
		rim.append(Vector3(cos(angle) * size.x, 0.0, sin(angle) * size.y) * (1.0 + ragged * rng.randf_range(-0.5, 0.5)))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for i: int in RIM_POINTS:
		for point: Vector3 in [Vector3.ZERO, rim[i], rim[(i + 1) % RIM_POINTS]]:
			st.set_color(Color(core_color, 1.0 - core if point == Vector3.ZERO else 1.0))
			st.set_uv(Vector2(point.x, point.z) / TEXTURE_METRES)
			st.add_vertex(point)
	return st.commit()


# A quad down from the origin to y -1, 1 wide at the top and narrower at the bottom, facing +Z.
func _streak_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.BACK)
	var top_left := Vector3(-0.5, 0.0, 0.0)
	var top_right := Vector3(0.5, 0.0, 0.0)
	var bottom_left := Vector3(-0.3, -1.0, 0.0)
	var bottom_right := Vector3(0.3, -1.0, 0.0)
	for point: Vector3 in [top_left, top_right, bottom_left, top_right, bottom_right, bottom_left]:
		st.set_color(Color(core_color, 1.0 - core * 0.5))
		st.set_uv(Vector2(point.x, -point.y) * 0.25)
		st.add_vertex(point)
	return st.commit()


# A low-poly unit sphere with vertex colours, which the material needs.
func _drop_mesh() -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 8
	sphere.rings = 4
	var arrays := sphere.get_mesh_arrays()
	var colors := PackedColorArray()
	colors.resize((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
	colors.fill(Color(core_color, 1.0 - core * 0.5))
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
