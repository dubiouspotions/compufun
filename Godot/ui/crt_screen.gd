class_name CrtScreen
extends TextureRect
## Shows [member buffer] through the CRT look ([code]shaders/crt.gdshader[/code], set as this
## node's material), and passes it the mouse bent through the same curve, so that a click lands on
## what the bent picture shows under the cursor. Plays the power-off, warm-up and degauss of the
## tube. See docs/crt.md.
##
## The buffer must not be a child of a SubViewportContainer: Godot then works out its hover from
## the container's straight transform, so hover and clicks disagree under the curve.

## The picture to show; it gets the mouse and, while this node is visible, the keys.
@export var buffer: SubViewport
## The seconds that the picture takes to collapse to a dot and fade at power-off.
@export var power_off_seconds: float = 0.6
## The seconds that the tube takes to warm up to full brightness at power-on.
@export var warmup_seconds: float = 2.5
## The seconds that the degauss wobble takes to die down.
@export var degauss_seconds: float = 1.2

var _tweens: Dictionary[StringName, Tween] = {}


func _ready() -> void:
	if buffer == null:
		push_error("CrtScreen %s: no buffer" % get_path())
		return
	texture = buffer.get_texture()
	buffer.handle_input_locally = false  # a key that the desktop takes doesn't also turn the camera
	mouse_entered.connect(buffer.notification.bind(NOTIFICATION_VP_MOUSE_ENTER))
	mouse_exited.connect(buffer.notification.bind(NOTIFICATION_VP_MOUSE_EXIT))


## The picture position (0..1) that the glass position [param uv] (0..1) shows; outside 0..1 is
## the black border. The twin of warp() in crt.gdshader.
func warp(uv: Vector2) -> Vector2:
	if not material is ShaderMaterial:
		return uv
	var c := (uv * 2.0 - Vector2.ONE) * (1.0 + _param(&"underscan") * 2.0)
	c *= Vector2.ONE + Vector2(_param(&"curvature_y"), _param(&"curvature_x")) * Vector2(c.y * c.y, c.x * c.x)
	return c * 0.5 + Vector2(0.5, 0.5)


## Collapses the picture to a line and a dot, which fades.
func power_off() -> void:
	_animate(&"power", 0.0, power_off_seconds)


## Warms the tube up from dark, with the degauss wobble of a monitor that was off a while.
func power_on() -> void:
	_set_uniform(&"power", 1.0)
	_set_uniform(&"warmup", 0.0)
	_animate(&"warmup", 1.0, warmup_seconds, Tween.EASE_OUT)
	degauss()


## Shakes the picture and swims its colours, dying down over [member degauss_seconds].
func degauss() -> void:
	_set_uniform(&"degauss", 1.0)
	_animate(&"degauss", 0.0, degauss_seconds, Tween.EASE_OUT)


func _gui_input(event: InputEvent) -> void:
	var mouse := event as InputEventMouse
	if mouse == null or buffer == null:
		return
	accept_event()
	var pixels := Vector2(buffer.size)
	var bent := mouse.duplicate() as InputEventMouse
	bent.position = warp(mouse.position / size) * pixels
	var motion := bent as InputEventMouseMotion
	if motion != null:
		motion.relative = bent.position - warp((mouse.position - motion.relative) / size) * pixels
	buffer.push_input(bent, true)


func _unhandled_input(event: InputEvent) -> void:
	if buffer != null and is_visible_in_tree() and not event is InputEventMouse:
		buffer.push_input(event)


# The uniform's value in the material, or the shader's default where the material leaves it unset.
func _param(uniform: StringName) -> float:
	var shader := material as ShaderMaterial
	var value: Variant = shader.get_shader_parameter(uniform)
	if value == null:
		value = RenderingServer.shader_get_parameter_default(shader.shader.get_rid(), uniform)
	return value


func _set_uniform(uniform: StringName, value: float) -> void:
	var shader := material as ShaderMaterial
	if shader == null:
		push_error("CrtScreen %s: the material is not a ShaderMaterial; can't set %s" % [get_path(), uniform])
		return
	shader.set_shader_parameter(uniform, value)


func _animate(uniform: StringName, to: float, seconds: float, easing: Tween.EaseType = Tween.EASE_IN) -> void:
	var shader := material as ShaderMaterial
	if shader == null:
		push_error("CrtScreen %s: the material is not a ShaderMaterial; can't animate %s" % [get_path(), uniform])
		return
	if _tweens.has(uniform):
		_tweens[uniform].kill()
	var tween := create_tween().set_ease(easing).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(shader, "shader_parameter/%s" % uniform, to, seconds)
	_tweens[uniform] = tween
