class_name StorageBin
extends Node3D
## The bin in the storage room where the player puts parts away (wiki: Hardware Repair). A click
## with a part in the hand puts it in; a click with an empty hand takes the last part back out. The
## origin is the bin's front, at mid-height; the parts stick out of it.

## The longest side of a part in the bin, in metres. A bigger part shows smaller.
@export var shown_size: float = 0.1
## How far each part sticks out of the bin, in metres.
@export var stick_out: float = 0.08
## How far each next part lies above the one before, in metres.
@export var pile_step: float = 0.025

var _shown: Array[Piece] = []

@onready var _pieces: Node3D = %Pieces
@onready var _hotspot: Hotspot = %Hotspot


func _ready() -> void:
	_hotspot.clicked.connect(_on_clicked)
	Game.changed.connect(_sync)
	_sync()


func _on_clicked(_clicked: Hotspot) -> void:
	if Game.hand != null:
		Game.put_in_storage()
	else:
		Game.take_from_storage()


func _sync() -> void:
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
		model.position = Vector3(0.0, -0.04 + i * pile_step, stick_out - box.end.z * fit)
		_pieces.add_child(model)
