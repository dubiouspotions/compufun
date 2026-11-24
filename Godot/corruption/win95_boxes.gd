extends CorruptionSign
## Every box of goods on the wall shelving (the MeshInstance3D in the group shelf_goods) becomes a
## Windows 95 box: the shelving's goods surface takes [member boxes].

## The surface of the wall shelving that holds the goods (tools/make_wall_shelf.gd).
const GOODS_SURFACE: int = 2

## The goods material with every box on the boards drawn as a Windows 95 box.
@export var boxes: Material

# The goods material of each shelving before the sign, by shelving.
var _plain: Dictionary[MeshInstance3D, Material] = {}


func _apply(shown_stage: int) -> void:
	var shelves := get_tree().get_nodes_in_group(&"shelf_goods")
	if shelves.is_empty() and shown_stage > 0:
		push_error("win95_boxes: no MeshInstance3D in the group shelf_goods, so no box turns")
	for node: Node in shelves:
		var shelf := node as MeshInstance3D
		if shelf == null or shelf.get_surface_override_material_count() <= GOODS_SURFACE:
			push_error("win95_boxes: %s in the group shelf_goods is not a MeshInstance3D with a goods surface %d" % [node.get_path(), GOODS_SURFACE])
			continue
		if not _plain.has(shelf):
			_plain[shelf] = shelf.get_surface_override_material(GOODS_SURFACE)
		shelf.set_surface_override_material(GOODS_SURFACE, boxes if shown_stage > 0 else _plain[shelf])
