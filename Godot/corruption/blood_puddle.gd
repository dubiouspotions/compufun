extends CorruptionSign
## Blood that seeped out under a computer as it was set down on the counter, and stays there for
## the rest of the game. Stage n: the puddle lies at counter slot n - 1 (see JobSlots), where the
## computer stood. Started during play, it seeps out over [member seep_seconds]; after a jump it
## shows at once.

## Where the puddle's middle lies from the slot's marker, in metres: out from under the computer.
@export var offset: Vector3 = Vector3(0.07, 0.0, 0.2)
## About how far the puddle reaches from its middle, in metres.
@export var radius: float = 0.1
## How ragged its rim is: 0 round, 1 very ragged.
@export_range(0.0, 1.0) var ragged: float = 0.45
## The puddle's shape; another seed gives another rim.
@export var shape_seed: int = 7
@export var seep_seconds: float = 10.0
## How high above the counter's mat the puddle lies, in metres; clear of z-fighting.
@export var lift: float = 0.0015
@export var material: Material = preload("res://materials/blood.tres")

const RIM_POINTS: int = 14

var _jump: int = -1
var _shown_stage: int = 0
var _seep: Tween

@onready var _puddle: MeshInstance3D = %Puddle


func _ready() -> void:
	_puddle.mesh = _make_mesh()
	_puddle.material_override = material
	super()


func _apply(shown_stage: int) -> void:
	var live := _jump == Game.jump
	_jump = Game.jump
	if shown_stage == _shown_stage:
		return
	_shown_stage = shown_stage
	if _seep != null:
		_seep.kill()
	_puddle.visible = false
	if shown_stage == 0:
		return
	var slots := get_tree().get_first_node_in_group(&"job_slots") as JobSlots
	if slots == null:
		push_error("blood_puddle: no JobSlots in the group job_slots")
		return
	var marker := slots.slot_marker(shown_stage - 1)
	if marker == null:
		return
	_puddle.global_transform = marker.global_transform * Transform3D(Basis(), offset + Vector3.UP * lift)
	_puddle.visible = true
	_puddle.scale = Vector3.ONE
	if live:
		_puddle.scale = Vector3(0.05, 1.0, 0.05)
		_seep = create_tween()
		_seep.tween_property(_puddle, ^"scale", Vector3.ONE, seep_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# A flat fan of triangles with a ragged rim, its texture laid flat across it.
func _make_mesh() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = shape_seed
	var rim := PackedVector3Array()
	for i: int in RIM_POINTS:
		var angle := TAU * i / RIM_POINTS
		rim.append(Vector3(cos(angle), 0.0, sin(angle)) * radius * (1.0 + ragged * rng.randf_range(-0.5, 0.5)))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for i: int in RIM_POINTS:
		for point: Vector3 in [Vector3.ZERO, rim[i], rim[(i + 1) % RIM_POINTS]]:
			st.set_uv(Vector2(point.x, point.z) / (radius * 2.0) + Vector2(0.5, 0.5))
			st.add_vertex(point)
	return st.commit()
