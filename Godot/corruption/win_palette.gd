extends CorruptionSign
## The colours of the world drift towards the 16 colours of Windows 95, further with each stage: the
## psx_post uniform windows_shades on the world's look.

## How far the colours drift at the last stage, 0 to 1. Each stage before it drifts an equal step less.
@export_range(0.0, 1.0) var full_drift: float = 0.9


func _apply(shown_stage: int) -> void:
	var drift := full_drift * shown_stage / maxi(stages, 1)
	for node: Node in get_tree().get_nodes_in_group(&"world_post"):
		var look := (node as CanvasItem).material as ShaderMaterial if node is CanvasItem else null
		if look == null:
			push_error("win_palette: %s has no ShaderMaterial for windows_shades" % node.get_path())
			continue
		look.set_shader_parameter(&"windows_shades", drift)
