class_name CrtMonitor
extends Node3D
## A 90s CRT monitor. Its screen stays dark, or shows a live texture such as the screen buffer.

## The tube's look when the screen shows a texture. Each monitor gets its own copy.
@export var screen_look: ShaderMaterial = preload("res://shaders/crt_looks/world_monitor.tres")

@onready var _screen: MeshInstance3D = %Screen


## The four corners of the screen, in world space.
func screen_corners() -> Array[Vector3]:
	var half := (_screen.mesh as QuadMesh).size * 0.5
	var corners: Array[Vector3] = []
	for corner: Vector2 in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)]:
		corners.append(_screen.global_transform * Vector3(corner.x, corner.y, 0.0))
	return corners


## Shows [param texture] on the screen through [member screen_look]: bent, glowing, and powered
## by the tube state that CrtTube animates.
func set_screen_texture(texture: Texture2D) -> void:
	var look := screen_look.duplicate() as ShaderMaterial
	look.set_shader_parameter(&"screen_texture", texture)
	_screen.material_override = look
