class_name TrashCan
extends Node3D
## The trash can by the work desk (wiki: Hardware Repair). A click with a part in the hand throws it
## in, on top of what lies there; with an empty hand, a click throws away the printout that the player
## carries (Game.printout). With neither, a click goes to [member look_view], and there takes the part
## on top back. The can is outlined while the player holds a part or carries a printout.

## The outline colour while a click would do something, and while the mouse is over the can.
@export var ready_color: Color = Color(0.75, 0.9, 1.0)
@export var hover_color: Color = Color(1.0, 0.82, 0.2)
## The close-up that looks down into the can.
@export var look_view: StringName = &"Trash"
## The longest side of a part in the can, in metres. A bigger part shows smaller.
@export var shown_size: float = 0.2
## The height of the bottom part above the can's floor, and how far each next one lies above it.
@export var floor_height: float = 0.03
@export var pile_step: float = 0.03
## How far a part may turn and slide off the middle as it lands, so the pile looks thrown.
@export_range(0.0, 180.0) var toss_degrees: float = 70.0
@export var toss_offset: float = 0.03

var _shown: Array[Piece] = []
var _hovered: bool = false

@onready var _pieces: Node3D = %Pieces
@onready var _hotspot: Hotspot = %Hotspot
@onready var _outline: MeshInstance3D = %Outline


func _ready() -> void:
	_hotspot.clicked.connect(_on_clicked)
	_hotspot.mouse_entered.connect(_set_hovered.bind(true))
	_hotspot.mouse_exited.connect(_set_hovered.bind(false))
	Game.changed.connect(_sync)
	_sync()


func _on_clicked(_clicked: Hotspot) -> void:
	if Game.hand != null:
		Game.trash_part()
	elif not Game.printout.is_empty():
		Game.trash_printout()
	elif Game.view != look_view:
		Game.go_to_view(look_view)
	else:
		Game.take_from_trash()


func _set_hovered(on: bool) -> void:
	_hovered = on
	_sync()


func _sync() -> void:
	var holding := Game.hand != null or not Game.printout.is_empty()
	_hotspot.set_enabled(holding or Game.view != look_view or not Game.trashed.is_empty())
	_hovered = _hovered and _hotspot.input_ray_pickable
	_outline.visible = holding or _hovered
	(_outline.material_override as StandardMaterial3D).albedo_color = hover_color if _hovered else ready_color
	if _shown == Game.trashed:
		return
	_shown = Game.trashed.duplicate()
	for child: Node in _pieces.get_children():
		child.queue_free()
	for i: int in _shown.size():
		var part := _shown[i].part
		if part.model == null:
			push_error("TrashCan: %s has no model" % part.resource_path)
			continue
		var model := part.model.instantiate() as Node3D
		var box := Part.bounds(model)
		var fit := minf(1.0, shown_size / maxf(box.size[box.get_longest_axis_index()], 0.001))
		# The same toss for the same place in the pile, so a re-read doesn't shuffle it.
		var rng := RandomNumberGenerator.new()
		rng.seed = i
		var holder := Node3D.new()
		holder.rotation.y = deg_to_rad(rng.randf_range(-toss_degrees, toss_degrees))
		holder.position = Vector3(rng.randf_range(-toss_offset, toss_offset), floor_height + i * pile_step, rng.randf_range(-toss_offset, toss_offset))
		model.scale = Vector3.ONE * fit
		model.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z) * fit
		holder.add_child(model)
		_pieces.add_child(holder)
