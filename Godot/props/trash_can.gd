class_name TrashCan
extends Node3D
## The trash can by the work desk. While the hand holds a part, the can is outlined and a click
## anywhere on it emits [signal trash_requested]; with an empty hand it takes no clicks.

## The player clicked the can while the hand holds a part.
signal trash_requested

## The outline colour while the hand holds a part.
@export var ready_color: Color = Color(0.75, 0.9, 1.0)
## The outline colour while the hand holds a part and the mouse is over the can.
@export var hover_color: Color = Color(1.0, 0.82, 0.2)

var _hovered: bool = false

@onready var _hotspot: Hotspot = %Hotspot
@onready var _outline: MeshInstance3D = %Outline


func _ready() -> void:
	_hotspot.clicked.connect(func(_h: Hotspot) -> void: trash_requested.emit())
	_hotspot.mouse_entered.connect(_set_hovered.bind(true))
	_hotspot.mouse_exited.connect(_set_hovered.bind(false))
	Game.changed.connect(_sync)
	_sync()


func _set_hovered(on: bool) -> void:
	_hovered = on
	_sync()


func _sync() -> void:
	var holding := Game.hand != null
	_hotspot.set_enabled(holding)
	_hovered = _hovered and holding
	_outline.visible = holding
	(_outline.material_override as StandardMaterial3D).albedo_color = hover_color if _hovered else ready_color
