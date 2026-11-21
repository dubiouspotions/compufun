class_name CrtMonitor
extends Node3D
## A 90s CRT monitor. Its screen stays dark, or shows a live texture such as the screen buffer.

@onready var _screen: MeshInstance3D = %Screen


## Shows [param texture] on the screen, unshaded, so the screen glows.
func set_screen_texture(texture: Texture2D) -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = texture
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_screen.material_override = material
