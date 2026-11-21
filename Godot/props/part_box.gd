@tool
class_name PartBox
extends Node3D
## A box of new parts on a storage shelf: a click takes one into the hand. Its part's model lies on
## top, so the box needs no label. The supply never runs out (wiki: Hardware Repair).

## The part in this box.
@export var part: Part:
	set(value):
		part = value
		if is_node_ready():
			_show()

var _model: Node3D

@onready var _hotspot: Hotspot = %Hotspot


func _ready() -> void:
	_show()


func _show() -> void:
	_hotspot.part = part
	if _model != null:
		_model.queue_free()
		_model = null
	if part == null or part.model == null:
		return
	_model = part.model.instantiate() as Node3D
	_model.position.y = 0.1
	add_child(_model)
