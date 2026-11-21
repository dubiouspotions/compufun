extends CorruptionSign
## The shop windows become Windows-logo windows: four coloured panes with the alley still behind them.

## The glass that the windows get.
@export var flag_glass: Material

## Each pane in the group shop_glass, with the material that it had.
var _plain: Dictionary[GeometryInstance3D, Material] = {}


func _ready() -> void:
	if flag_glass == null:
		push_error("shop_windows: flag_glass is not set in %s" % scene_file_path)
	for node: Node in get_tree().get_nodes_in_group(&"shop_glass"):
		var glass := node as GeometryInstance3D
		if glass == null:
			push_error("shop_windows: %s in the group shop_glass is not a GeometryInstance3D" % node.get_path())
			continue
		_plain[glass] = glass.material_override
	if _plain.is_empty():
		push_error("shop_windows: no window pane in the group shop_glass")
	super()


func _apply(shown_stage: int) -> void:
	for glass: GeometryInstance3D in _plain:
		glass.material_override = flag_glass if shown_stage >= 1 and flag_glass != null else _plain[glass]
