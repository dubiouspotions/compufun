class_name CrtMonitor
extends Node3D
## A 90s CRT monitor. Its screen stays dark, or shows a live texture such as the screen buffer; while
## its tube is on, it hums faintly.

## The tube's look when the screen shows a texture. Each monitor gets its own copy.
@export var screen_look: ShaderMaterial = preload("res://shaders/crt_looks/world_monitor.tres")
## The energy of the light that the warm screen casts in front of it while it shows a computer's
## picture, and while it shows the monitor's own NO SIGNAL box. %Glow holds the light's colour and reach.
@export_range(0.0, 4.0, 0.01) var picture_glow_energy: float = 2.0
@export_range(0.0, 4.0, 0.01) var no_signal_glow_energy: float = 0.8

var _look: ShaderMaterial

@onready var _screen: MeshInstance3D = %Screen
@onready var _glow: Light3D = %Glow
@onready var _hum: Hum = %Hum


func _ready() -> void:
	_glow.visible = false
	set_process(false)


# The light and the hum follow the tube's uniforms on the 3D screen, which a CrtTube animates.
func _process(_delta: float) -> void:
	var lit := _tube(&"crt_warmup") ** 2 * smoothstep(0.0, 0.3, _tube(&"crt_sync")) * smoothstep(0.5, 1.0, _tube(&"crt_power")) * (1.0 - _tube(&"crt_blank"))
	_glow.light_energy = lit * lerpf(no_signal_glow_energy, picture_glow_energy, _tube(&"crt_picture"))
	_glow.visible = _glow.light_energy > 0.001
	_hum.on = _tube(&"crt_power") > 0.5


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
	set_process(true)
	return look
