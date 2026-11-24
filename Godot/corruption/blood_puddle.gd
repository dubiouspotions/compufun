extends CorruptionSign
## Blood that seeped out under a computer as it was set down on the counter, and stays there for
## the rest of the game. Stage n: the blood lies at counter slot n - 1 (see JobSlots), where the
## computer stood. A puddle under the computer runs in a rivulet across the work mat to the
## counter's near edge (+Z from the slot), down the counter's front, and drips onto the floor into a
## second puddle. Started during play, it plays out over [method settled_seconds]; after a jump it
## shows the settled state at once. It drips, and each drop sounds as it lands, only on the day that
## it started in play (the flag [constant DAY_FLAG]); later it lies still. [member shape_seed] decides
## every shape, so it looks the same every time. A computer that slides left off the puddle, as one
## to its left leaves the counter, drags a smear of it to where it stops; the flag [constant DRAG_FLAG]
## keeps it.

## Emitted as a drop lands in the floor puddle and its sound plays: only while the blood is fresh.
signal dripped

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
## The sound of a drop landing in the floor puddle.
@export var drip_sound: SoundSet

@export_group("Drag")
## How wide the smear is across the counter where it leaves the puddle, and where it ends, in metres.
@export var drag_width: Vector2 = Vector2(0.22, 0.12)
## How many flat blobs make up a metre of the smear; each overlaps the next.
@export var drag_blobs_per_metre: float = 14.0
## How much of each smear blob's middle darkens to [member core_color]: thinner than the puddle.
@export_range(0.0, 1.0) var drag_core: float = 0.35

@export_group("Look")
## Every rim, the rivulet's path and its timing; another seed gives another shape.
@export var shape_seed: int = 7
## How high above the surface under it the blood lies, in metres; clear of z-fighting.
@export var lift: float = 0.0015
## Needs vertex_color_fade on: the meshes' vertex colours darken the middles.
@export var material: Material = preload("res://materials/blood_pool.tres")

## The counter slot + 1 where the smear that a computer dragged from the puddle ends; 0 or unset: no
## smear.
const DRAG_FLAG: StringName = &"blood_puddle_drag"
## The day that the blood started in play; 0 or unset: it started in a jump, and is not fresh.
const DAY_FLAG: StringName = &"blood_puddle_day"
const RIM_POINTS: int = 14
const TEXTURE_METRES: float = 0.2 ## How many metres one repeat of the texture spans.

var _jump: int = -1
var _shown_stage: int = 0
var _elapsed: float = 0.0
var _blob_starts: PackedFloat64Array = []
var _blob_nodes: Array[MeshInstance3D] = []
var _rivulet_end := Vector3.ZERO
var _slots: Dictionary[Job, int] = {}  # each job's slot at the last change, to see which computer slid
var _shown_drag: int = -1  # the slot where the shown smear ends; -1: none
var _drag_elapsed: float = 0.0

@onready var _blood: Node3D = %Blood
@onready var _puddle: MeshInstance3D = %Puddle
@onready var _rivulet: Node3D = %Rivulet
@onready var _streak: MeshInstance3D = %Streak
@onready var _run: MeshInstance3D = %Run
@onready var _drop: MeshInstance3D = %Drop
@onready var _floor_puddle: MeshInstance3D = %FloorPuddle
@onready var _drag: Node3D = %Drag
@onready var _drip_player: AudioStreamPlayer3D = %DripSound


func _ready() -> void:
	set_process(false)
	if drip_sound == null:
		push_error("%s: no drip_sound" % scene_file_path)
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
			_sync_drag(-1, live)
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
		if live and not fresh():
			Game.set_flag.call_deferred(DAY_FLAG, Game.day_number)  # out of the Game.changed that runs this
	elif shown_stage > 0 and not live:
		_elapsed = maxf(_elapsed, settled_seconds())
	_sync_drag(shown_stage - 1, live)
	_show()


# Records a computer that slid from the puddle's slot, or right of it, to a slot left of it, and
# shows the smear that the flag keeps.
func _sync_drag(puddle_slot: int, live: bool) -> void:
	var drag_to := Game.flag(DRAG_FLAG) - 1
	if live and puddle_slot >= 0:
		for job: Job in Game.jobs:
			if _slots.get(job, -1) >= puddle_slot and job.slot < puddle_slot and (drag_to < 0 or job.slot < drag_to):
				drag_to = job.slot
				Game.set_flag.call_deferred(DRAG_FLAG, drag_to + 1)  # out of the Game.changed that runs this
	_slots.clear()
	for job: Job in Game.jobs:
		_slots[job] = job.slot
	var shown := Game.flag(DRAG_FLAG) - 1 if puddle_slot >= 0 and Game.flag(DRAG_FLAG) - 1 < puddle_slot else -1
	if shown == _shown_drag:
		if not live:
			_drag_elapsed = INF
		return
	_shown_drag = shown
	for blob: Node in _drag.get_children():
		blob.queue_free()
	if shown >= 0:
		_build_drag(puddle_slot, shown)
	_drag_elapsed = 0.0 if live else INF
	set_process(shown >= 0 or is_processing())


## True on the day that the blood started in play: it drips.
func fresh() -> bool:
	return Game.flag(DAY_FLAG) == Game.day_number


func _process(delta: float) -> void:
	var landed := _landed()
	_elapsed += delta
	if _landed() > landed and fresh() and drip_sound != null:
		drip_sound.play_on(_drip_player)
		dripped.emit()
	_drag_elapsed += delta
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
	_grow(_floor_puddle, sqrt(clampf(_landed() * drip_seconds / floor_grow_seconds, 0.0, 1.0)))
	_show_drag()


# The smear reaches out from the puddle as the computer slides, with the same ease as JobSlots's slide.
func _show_drag() -> void:
	var slots := get_tree().get_first_node_in_group(&"job_slots") as JobSlots
	var seconds := slots.slide_seconds if slots != null else 0.0
	var t := clampf(_drag_elapsed / seconds, 0.0, 1.0) if seconds > 0.0 else 1.0
	var reach := (1.0 - cos(t * PI)) / 2.0
	_drag.visible = _shown_drag >= 0 and reach > 0.0
	_drag.scale = Vector3(maxf(reach, 0.01), 1.0, 1.0)


# A drop swells at the bottom of the streak, falls to the floor and lands, every drip_seconds.
func _show_drop() -> void:
	var drip := _elapsed - _streak_start() - streak_seconds
	if drip < 0.0 or not fresh():
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


# How many drops have landed in the floor puddle by _elapsed.
func _landed() -> int:
	var drip := _elapsed - _first_landing()
	return floori(drip / drip_seconds) + 1 if drip >= 0.0 else 0


func _first_landing() -> float:
	return _streak_start() + streak_seconds + swell_seconds + sqrt(2.0 * (floor_depth - lip_depth - drop_radius * 0.8) / gravity)  # as _show_drop hides it


# Shows node at share (0 to 1) of its full size; hidden at 0.
func _grow(node: Node3D, share: float) -> void:
	node.visible = share > 0.0
	node.scale = Vector3.ONE * maxf(share, 0.01)


# Ease-out from 0 to 1 over t in 0 to 1; 0 before, 1 after.
func _ease(t: float) -> float:
	return sin(clampf(t, 0.0, 1.0) * PI / 2.0)


# The smear from the puddle's middle at [param puddle_slot] to the same spot at [param to_slot], along
# -X: overlapping ragged blobs that narrow from drag_width.x to drag_width.y.
func _build_drag(puddle_slot: int, to_slot: int) -> void:
	var slots := get_tree().get_first_node_in_group(&"job_slots") as JobSlots
	if slots == null:
		push_error("blood_puddle: no JobSlots in the group job_slots")
		return
	var from := slots.slot_marker(puddle_slot)
	var to := slots.slot_marker(to_slot)
	if from == null or to == null:
		return
	_drag.position = offset + Vector3.UP * lift * 0.5
	var length := absf((from.global_transform.affine_inverse() * to.global_position).x)
	var count := maxi(2, ceili(length * drag_blobs_per_metre))
	var rng := RandomNumberGenerator.new()
	rng.seed = shape_seed + to_slot
	for i: int in count:
		var along := (i + 0.5) / count
		var blob := MeshInstance3D.new()
		blob.mesh = _disk(rng, Vector2(length / count * 0.8, lerpf(drag_width.x, drag_width.y, along) / 2.0), drag_core)
		blob.material_override = material
		blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		blob.position = Vector3(-length * along, lift * 0.02 * i, rng.randf_range(-wander, wander))  # each a hair higher: no z-fight
		_drag.add_child(blob)


func _build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = shape_seed
	_puddle.mesh = _disk(rng, Vector2(radius, radius), core)
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
		blob.mesh = _disk(rng, Vector2(blob_width / 2.0, spacing * 0.9), core)
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
	_floor_puddle.mesh = _disk(rng, Vector2(floor_radius, floor_radius), core)
	_floor_puddle.position = Vector3(_rivulet_end.x, lift - floor_depth, edge_distance + floor_radius * 0.5)
	_drip_player.position = _floor_puddle.position
	for mesh: MeshInstance3D in [_puddle, _streak, _run, _drop, _floor_puddle]:
		mesh.material_override = material


# A flat fan of triangles with a ragged rim, half-sizes size.x across and size.y along +Z; the
# texture lies flat across it, and core_share of the middle darkens to core_color.
func _disk(rng: RandomNumberGenerator, size: Vector2, core_share: float) -> ArrayMesh:
	var rim := PackedVector3Array()
	for i: int in RIM_POINTS:
		var angle := TAU * i / RIM_POINTS
		rim.append(Vector3(cos(angle) * size.x, 0.0, sin(angle) * size.y) * (1.0 + ragged * rng.randf_range(-0.5, 0.5)))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for i: int in RIM_POINTS:
		for point: Vector3 in [Vector3.ZERO, rim[i], rim[(i + 1) % RIM_POINTS]]:
			st.set_color(Color(core_color, 1.0 - core_share if point == Vector3.ZERO else 1.0))
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
