class_name MovablePanel
extends PanelContainer
## A touch panel that the player drags by its [member grip] to wherever it is out of the way. It
## stays inside its parent Control (the window), and keeps its place across runs in
## [member config_path], in the section [member config_section]. Being a STOP control, it takes
## every touch on it, so nothing behind it reacts.

## The canvas size that [member default_position] is given in.
const DESIGN_FRAME := Vector2(1920.0, 1080.0)

## The file that every panel keeps its place in. Tests point it at their own folder.
static var config_path: String = "user://touch_controls.cfg"

## The section of [member config_path] for this panel; each panel needs its own.
@export var config_section: String = ""
## Where the panel starts until the player moves it: its top left corner in the 1920 x 1080 design
## frame. In a parent of another size, the panel keeps its share of the free room on each axis, so a
## panel at the bottom stays at the bottom and a centred one stays centred.
@export var default_position: Vector2 = Vector2.ZERO
## The bar that the player drags the panel by.
@export var grip: Control

var _drag_from: Vector2 = Vector2.ZERO  # the grab point in the panel, while dragging
var _dragging: bool = false


func _ready() -> void:
	if config_section.is_empty():
		push_error("MovablePanel %s: no config_section" % get_path())
	if grip == null:
		push_error("MovablePanel %s: no grip" % get_path())
	else:
		grip.gui_input.connect(_on_grip_input)
	position = _load_position()
	resized.connect(_clamp)
	var frame := get_parent() as Control
	if frame != null:
		frame.resized.connect(_clamp)
	_clamp.call_deferred()  # once the containers have sized the panel


## Moves the panel to [param at] (its top left corner in the parent), clamped inside the parent.
func place(at: Vector2) -> void:
	position = at
	_clamp()


## Writes the panel's place to [member config_path], keeping the other panels' sections. Returns
## the error; it reports one itself.
func save_position() -> Error:
	var config := ConfigFile.new()
	var err := config.load(config_path)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		push_error("MovablePanel %s: can't read %s (%s); writing it anew" % [name, config_path, error_string(err)])
		config = ConfigFile.new()
	config.set_value(config_section, "position", position)
	err = config.save(config_path)
	if err != OK:
		push_error("MovablePanel %s: can't save %s: %s" % [name, config_path, error_string(err)])
	return err


func _load_position() -> Vector2:
	var config := ConfigFile.new()
	var err := config.load(config_path)
	if err == ERR_FILE_NOT_FOUND:
		return _default_place()
	if err != OK:
		push_error("MovablePanel %s: can't read %s: %s" % [name, config_path, error_string(err)])
		return _default_place()
	var saved: Variant = config.get_value(config_section, "position", null)
	if saved == null:
		return _default_place()
	if not saved is Vector2:
		push_error("MovablePanel %s: [%s] position in %s is %s, not a Vector2" % [name, config_section, config_path, saved])
		return _default_place()
	return saved


# default_position, moved to keep its share of the free room in the parent (see default_position).
func _default_place() -> Vector2:
	var design_room := DESIGN_FRAME - size
	var share := (default_position / design_room.max(Vector2.ONE)).clamp(Vector2.ZERO, Vector2.ONE)
	return (share * (get_parent_area_size() - size)).round()


func _clamp() -> void:
	var frame := get_parent_area_size()
	position = position.clamp(Vector2.ZERO, (frame - size).max(Vector2.ZERO))


# Mouse events: a real mouse, or the one that Godot makes from the first finger.
func _on_grip_input(event: InputEvent) -> void:
	var mouse := event as InputEventMouse
	if mouse == null:
		return
	var at := _in_parent(grip.get_global_transform_with_canvas() * mouse.position)
	var button := mouse as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		_dragging = button.pressed
		_drag_from = at - position
		if not button.pressed:
			save_position()
	elif mouse is InputEventMouseMotion and _dragging:
		place(at - _drag_from)


func _in_parent(canvas_at: Vector2) -> Vector2:
	var frame := get_parent() as CanvasItem
	return frame.get_global_transform_with_canvas().affine_inverse() * canvas_at if frame != null else canvas_at
