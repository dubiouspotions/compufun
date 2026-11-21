extends PanelContainer
## What the player holds, in a corner of every view (wiki: Hardware Repair): the part turning in a
## small window, its name, and BROKEN when it is broken. Hidden while the hand is empty.

## The turns per second of the part on show.
@export var turn_speed: float = 0.4
## How big the part on show is, in metres across, whatever its real size.
@export var shown_size: float = 0.13
## The seconds that the panel takes to fade in.
@export var fade_seconds: float = 0.15

var _held: Piece

@onready var _turntable: Node3D = %Turntable
@onready var _name: Label = %Name
@onready var _broken: Label = %Broken


func _ready() -> void:
	Game.changed.connect(_sync)
	_sync()


func _process(delta: float) -> void:
	_turntable.rotate_y(TAU * turn_speed * delta)


func _sync() -> void:
	var holding := Game.hand != null
	if holding and not visible:
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, fade_seconds)
	visible = holding
	set_process(holding)
	if Game.hand == _held:
		return
	_held = Game.hand
	for child: Node in _turntable.get_children():
		child.queue_free()
	if _held == null:
		return
	_name.text = _held.part.display_name
	_broken.visible = _held.broken
	if _held.part.model == null:
		push_error("Hand: %s has no model" % _held.part.resource_path)
		return
	var model := _held.part.model.instantiate() as Node3D
	_turntable.add_child(model)
	var box := _bounds(model)
	var longest := maxf(box.size.x, maxf(box.size.y, box.size.z))
	var fit := shown_size / maxf(longest, 0.001)
	model.scale = Vector3.ONE * fit
	model.position = -box.get_center() * fit


# The box around the model's meshes, in the model's own space.
func _bounds(model: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var part_box: AABB = mesh.transform * mesh.get_aabb()
		box = part_box if first else box.merge(part_box)
		first = false
	return box
