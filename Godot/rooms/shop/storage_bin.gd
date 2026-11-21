class_name StorageBin
extends Node3D
## The bin in the storage room where the player puts parts away (wiki: Hardware Repair). A click
## with a part in the hand puts it in; a click with an empty hand takes the last part back out. While
## the hand holds a part the bin is outlined, as the trash can is. The origin is the bin's front, at
## mid-height; the parts lie on top of the bin, where the player sees them.

## The outline colour while the hand holds a part, and while the mouse is over the bin.
@export var ready_color: Color = Color(0.75, 0.9, 1.0)
@export var hover_color: Color = Color(1.0, 0.82, 0.2)
## The longest side of a part on the bin, in metres. A bigger part shows smaller.
@export var shown_size: float = 0.16
## The height of the bin's top above the origin, and the depth of its middle behind it, in metres.
@export var top_height: float = 0.055
@export var middle_depth: float = 0.085
## How far each next part lies above the one before, in metres.
@export var pile_step: float = 0.025

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
		Game.put_in_storage()
	else:
		Game.take_from_storage()


func _set_hovered(on: bool) -> void:
	_hovered = on
	_sync()


func _sync() -> void:
	var holding := Game.hand != null
	_hotspot.set_enabled(holding or not Game.stored.is_empty())
	_hovered = _hovered and _hotspot.input_ray_pickable
	_outline.visible = holding or _hovered
	(_outline.material_override as StandardMaterial3D).albedo_color = hover_color if _hovered else ready_color
	if _shown == Game.stored:
		return
	_shown = Game.stored.duplicate()
	for child: Node in _pieces.get_children():
		child.queue_free()
	for i: int in _shown.size():
		var part := _shown[i].part
		if part.model == null:
			push_error("StorageBin: %s has no model" % part.resource_path)
			continue
		var model := part.model.instantiate() as Node3D
		var box := Part.bounds(model)
		var fit := minf(1.0, shown_size / maxf(box.size[box.get_longest_axis_index()], 0.001))
		model.scale = Vector3.ONE * fit
		model.position = Vector3(-box.get_center().x * fit, top_height + i * pile_step, -middle_depth - box.get_center().z * fit)
		_pieces.add_child(model)
