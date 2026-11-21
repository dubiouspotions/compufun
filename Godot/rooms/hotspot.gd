class_name Hotspot
extends Area3D
## A thing that the player clicks. Every hotspot is this scene (rooms/hotspot.tscn); the room
## decides what a click does from [member action].

## The player clicked the hotspot with the left mouse button.
signal clicked(hotspot: Hotspot)

enum Action { GO_TO_VIEW, CALL_CUSTOMER }

## The name on the label above the thing.
@export var label_text: String = "THING"
@export var action: Action = Action.GO_TO_VIEW
## For GO_TO_VIEW: the name of the view marker to go to.
@export var view: StringName = &""
## The size of the clickable box, in metres. It applies when the game runs.
@export var size: Vector3 = Vector3(0.5, 0.5, 0.5)

@onready var _shape: CollisionShape3D = %Shape
@onready var _label: Label3D = %Label


func _ready() -> void:
	var box := BoxShape3D.new()
	box.size = size
	_shape.shape = box
	_label.position = Vector3(0.0, size.y * 0.5 + 0.12, 0.0)
	set_label(label_text)
	input_event.connect(_on_input_event)
	mouse_entered.connect(func() -> void: _label.modulate = Color.YELLOW)
	mouse_exited.connect(func() -> void: _label.modulate = Color.WHITE)


func set_label(text: String) -> void:
	label_text = text
	_label.text = text


func show_label(on: bool) -> void:
	_label.visible = on


## Shows or hides the hotspot. A hidden hotspot does not take clicks.
func set_enabled(on: bool) -> void:
	visible = on
	input_ray_pickable = on


func _on_input_event(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_index: int) -> void:
	var mouse := event as InputEventMouseButton
	if mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)
