class_name CrtMonitor
extends Node3D
## A 90s CRT monitor. Its screen stays dark, or shows a live texture such as the screen buffer; while
## its tube is on, it hums faintly, and its picture lights the desk in front (%Glow) and, in the
## picture's average colour, its own bezel (%ScreenLight).

## The tube's look when the screen shows a texture. Each monitor gets its own copy.
@export var screen_look: ShaderMaterial = preload("res://shaders/crt_looks/world_monitor.tres")
## The energy of the light that the warm screen casts in front of it while it shows a computer's
## picture, and while it shows the monitor's own NO SIGNAL box. %Glow holds the light's colour and reach.
@export_range(0.0, 4.0, 0.01) var picture_glow_energy: float = 2.0
@export_range(0.0, 4.0, 0.01) var no_signal_glow_energy: float = 0.8
## The energy of %ScreenLight, the light that the picture casts on the bezel around it, at a white
## picture. It takes the picture's average colour and brightness, and is off while the tube is dark.
@export_range(0.0, 4.0, 0.01) var screen_light_energy: float = 0.3
## The seconds between two reads of the picture's average colour; each read waits for the GPU.
@export_range(0.05, 2.0, 0.05, "suffix:s") var average_seconds: float = 0.25

const _AVERAGE_SHADER: Shader = preload("res://shaders/screen_average.gdshader")

var _look: ShaderMaterial
var _average: SubViewport
var _average_colour: Color = Color.WHITE
var _reading: bool = false
var _next_read: float = 0.0

@onready var _screen: MeshInstance3D = %Screen
@onready var _glow: Light3D = %Glow
@onready var _screen_light: Light3D = %ScreenLight
@onready var _hum: Hum = %Hum


func _ready() -> void:
	_glow.visible = false
	_screen_light.visible = false
	set_process(false)


# The light and the hum follow the tube's uniforms on the 3D screen, which a CrtTube animates.
func _process(delta: float) -> void:
	var lit := _tube(&"crt_warmup") ** 2 * smoothstep(0.0, 0.3, _tube(&"crt_sync")) * smoothstep(0.5, 1.0, _tube(&"crt_power")) * (1.0 - _tube(&"crt_blank"))
	_glow.light_energy = lit * lerpf(no_signal_glow_energy, picture_glow_energy, _tube(&"crt_picture"))
	_glow.visible = _glow.light_energy > 0.001
	var peak := maxf(_average_colour.r, maxf(_average_colour.g, _average_colour.b))
	_screen_light.light_energy = lit * screen_light_energy * peak
	_screen_light.visible = _screen_light.light_energy > 0.001
	if _screen_light.visible:
		_screen_light.light_color = _average_colour / peak
	_hum.on = _tube(&"crt_power") > 0.5
	_next_read -= delta
	if _next_read <= 0.0 and not _reading and _average != null:
		_next_read = average_seconds
		_read_average()


# Renders the picture's average into the 1 x 1 viewport and reads it back. A headless run draws
# nothing, so there the light keeps white.
func _read_average() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_reading = true
	_average.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	_reading = false
	var image := _average.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("%s: the average of the screen texture did not draw; the screen light stays %s" % [get_path(), _average_colour])
		return
	_average_colour = image.get_pixel(0, 0)


func _tube(uniform: StringName) -> float:
	return float(_look.get_shader_parameter(uniform))


## The four corners of the screen, in world space.
func screen_corners() -> Array[Vector3]:
	var half := (_screen.mesh as QuadMesh).size * 0.5
	var corners: Array[Vector3] = []
	for corner: Vector2 in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)]:
		corners.append(_screen.global_transform * Vector3(corner.x, corner.y, 0.0))
	return corners


## Shows [param texture] on the screen through a copy of [member screen_look], bent and glowing.
## Returns the copy, for a CrtTube to power; the screen lights the room in front of it as the tube glows.
func set_screen_texture(texture: Texture2D) -> ShaderMaterial:
	var look := screen_look.duplicate() as ShaderMaterial
	look.set_shader_parameter(&"screen_texture", texture)
	_screen.material_override = look
	_look = look
	if _average == null:
		_average = SubViewport.new()
		_average.size = Vector2i.ONE
		_average.disable_3d = true
		_average.render_target_update_mode = SubViewport.UPDATE_DISABLED
		var rect := ColorRect.new()
		rect.size = Vector2.ONE
		rect.material = ShaderMaterial.new()
		(rect.material as ShaderMaterial).shader = _AVERAGE_SHADER
		_average.add_child(rect)
		add_child(_average, false, Node.INTERNAL_MODE_BACK)
	((_average.get_child(0) as ColorRect).material as ShaderMaterial).set_shader_parameter(&"screen_texture", texture)
	set_process(true)
	return look
