class_name CrtScreen
extends TextureRect
## Shows [member buffer] through the CRT look ([code]shaders/crt.gdshader[/code], set as this
## node's material), and passes it the mouse bent through the same curve, so that a click lands on
## what the bent picture shows under the cursor. The shader draws the mouse cursor into the
## picture, so it bends, glows and stays on the screen where the player left it. See docs/crt.md.
##
## The buffer must not be a child of a SubViewportContainer: Godot then works out its hover from
## the container's straight transform, so hover and clicks disagree under the curve.

## The group of every CRT screen.
const GROUP: StringName = &"crt_screens"
const _BENT: Array[StringName] = [&"curvature_x", &"curvature_y", &"underscan", &"corner_radius"]

## The picture to show; it gets the mouse and, while this node is visible, the keys.
@export var buffer: SubViewport
## The monitor's tube: it powers this node's look, and draws the cursor.
@export var tube: CrtTube
## The look of the 3D monitor; while the camera zooms in, the curve blends from its curve to this
## node's material's.
@export var far_look: ShaderMaterial
## The cursor over most of the desktop, and the pixel of it that points.
@export var arrow_cursor: Texture2D = preload("res://win95/theme/arrow_cursor.png")
@export var arrow_hotspot: Vector2 = Vector2.ZERO
## The cursor over text, and the pixel of it that points.
@export var ibeam_cursor: Texture2D = preload("res://win95/theme/ibeam_cursor.png")
@export var ibeam_hotspot: Vector2 = Vector2(4, 9)
## The cursors over a window's resizable frame, by shape; each points from its centre.
@export var sizing_cursors: Dictionary[Control.CursorShape, Texture2D] = {
	Control.CURSOR_VSIZE: preload("res://win95/theme/size_ns_cursor.png"),
	Control.CURSOR_HSIZE: preload("res://win95/theme/size_we_cursor.png"),
	Control.CURSOR_FDIAGSIZE: preload("res://win95/theme/size_nwse_cursor.png"),
	Control.CURSOR_BDIAGSIZE: preload("res://win95/theme/size_nesw_cursor.png"),
}

## False hides the cursor, as when the screen shows no computer.
var cursor_visible: bool = true:
	set(value):
		cursor_visible = value
		_sync_cursor()
## Draws the cursor this many buffer pixels from the mouse; clicks still land at the mouse. The
## corruption sign corruption/pointer_escape.tscn slides it off the screen.
var cursor_offset: Vector2 = Vector2.ZERO:
	set(value):
		cursor_offset = value
		_sync_cursor()

var _near: Dictionary[StringName, float] = {}
var _cursor_at: Vector2 = Vector2(320, 240)
var _cursor: Texture2D


func _ready() -> void:
	add_to_group(GROUP)
	if buffer == null:
		push_error("CrtScreen %s: no buffer" % get_path())
		return
	texture = buffer.get_texture()
	buffer.handle_input_locally = false  # a key that the desktop takes doesn't also turn the camera
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	visibility_changed.connect(func() -> void: if not visible: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE)
	var look := material as ShaderMaterial
	if look == null:
		push_error("CrtScreen %s: the material is not a ShaderMaterial" % get_path())
		return
	material = look.duplicate()  # the zoom changes the curve; the look's .tres stays as it is
	(material as ShaderMaterial).set_shader_parameter(&"screen_texture", texture)
	if tube == null:
		push_error("CrtScreen %s: no tube" % get_path())
		return
	tube.add_look(material)
	for uniform in _BENT:
		_near[uniform] = _param(material, uniform)
	_set_cursor(arrow_cursor)


## Where the mouse points in [member buffer], in its pixels.
func cursor_at() -> Vector2:
	return _cursor_at


## The picture position (0..1) that the glass position [param uv] (0..1) shows; outside 0..1 is
## the black border. The twin of crt_bend() in crt.gdshaderinc.
func bend(uv: Vector2) -> Vector2:
	if not material is ShaderMaterial:
		return uv
	var c := (uv * 2.0 - Vector2.ONE) * (1.0 + _param(material, &"underscan") * 2.0)
	c *= Vector2.ONE + Vector2(_param(material, &"curvature_y"), _param(material, &"curvature_x")) * Vector2(c.y * c.y, c.x * c.x)
	return c * 0.5 + Vector2(0.5, 0.5)


## Blends the curve from [member far_look]'s (0, the 3D monitor) to the material's own (1, the
## open Screen View).
func set_closeness(closeness: float) -> void:
	var look := material as ShaderMaterial
	if look == null or far_look == null or _near.is_empty():
		return
	for uniform in _BENT:
		look.set_shader_parameter(uniform, lerpf(_param(far_look, uniform), _near[uniform], closeness))


func _gui_input(event: InputEvent) -> void:
	var mouse := event as InputEventMouse
	if mouse == null or buffer == null:
		return
	var pixels := Vector2(buffer.size)
	var bent := mouse.duplicate() as InputEventMouse
	bent.position = bend(mouse.position / size) * pixels
	bent.global_position = bent.position  # controls in the buffer read either
	var motion := bent as InputEventMouseMotion
	if motion != null:
		motion.relative = bent.position - bend((mouse.position - motion.relative) / size) * pixels
	buffer.push_input(bent, true)
	accept_event()  # after the push, which clears the flag: a frozen desktop takes nothing, and the click must not leave the view
	_cursor_at = bent.position.clamp(Vector2.ZERO, pixels - Vector2.ONE)
	var over := buffer.gui_get_hovered_control()
	var shape := over.get_cursor_shape(over.get_global_transform_with_canvas().affine_inverse() * bent.position) if over != null else Control.CURSOR_ARROW
	_set_cursor(ibeam_cursor if shape == Control.CURSOR_IBEAM else sizing_cursors.get(shape, arrow_cursor))


func _unhandled_input(event: InputEvent) -> void:
	if buffer != null and is_visible_in_tree() and not event is InputEventMouse:
		buffer.push_input(event)


# The system cursor hides over the screen; the shader draws the desktop's.
func _on_mouse_entered() -> void:
	buffer.notification(NOTIFICATION_VP_MOUSE_ENTER)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func _on_mouse_exited() -> void:
	buffer.notification(NOTIFICATION_VP_MOUSE_EXIT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _set_cursor(cursor: Texture2D) -> void:
	if cursor != _cursor and tube != null:
		_cursor = cursor
		tube.set_param(&"crt_cursor_texture", cursor)
	_sync_cursor()


func _sync_cursor() -> void:
	var hotspot := ibeam_hotspot if _cursor == ibeam_cursor else arrow_hotspot
	if _cursor in sizing_cursors.values():
		hotspot = (_cursor.get_size() / 2.0).floor()
	if tube != null:
		tube.set_param(&"crt_cursor", (_cursor_at - hotspot + cursor_offset).floor() if cursor_visible else Vector2(-1000, -1000))


# The uniform's value in [param look], or the shader's default where the look leaves it unset.
static func _param(look: ShaderMaterial, uniform: StringName) -> float:
	var value: Variant = look.get_shader_parameter(uniform)
	if value == null:
		value = RenderingServer.shader_get_parameter_default(look.shader.get_rid(), uniform)
	return value
