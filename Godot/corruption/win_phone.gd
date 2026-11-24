extends CorruptionSign
## Every desk phone (the Body of each Node3D in the group desk_phones, props/phone.tscn: the one on
## the counter and the one in the call box) turns into the Windows 95 Modems icon in 3D, a yellow
## phone on a modem (tools/make_win_phone.gd). Only its look changes: the shop's outline, pulse and
## clicks stay on the same Body.

## The icon's model, which stands in for the push-button phone's mesh.
@export var mesh: Mesh
## The icon's material, on the model's one surface.
@export var material: Material

# The mesh and surface materials of each phone's Body before the sign, by Body.
var _plain: Dictionary[MeshInstance3D, Array] = {}


func _apply(shown_stage: int) -> void:
	var phones := get_tree().get_nodes_in_group(&"desk_phones")
	if phones.is_empty() and shown_stage > 0:
		push_error("win_phone: no Node3D in the group desk_phones, so no phone turns")
	for phone: Node in phones:
		var body := phone.get_node_or_null(^"Body") as MeshInstance3D
		if body == null:
			push_error("win_phone: %s in the group desk_phones has no MeshInstance3D named Body" % phone.get_path())
			continue
		if not _plain.has(body):
			var materials: Array[Material] = []
			for i: int in body.get_surface_override_material_count():
				materials.append(body.get_surface_override_material(i))
			_plain[body] = [body.mesh, materials]
		var plain: Array = _plain[body]
		if shown_stage > 0 and body.mesh != mesh:
			for i: int in body.get_surface_override_material_count():
				body.set_surface_override_material(i, null)
			body.mesh = mesh
			body.set_surface_override_material(0, material)
		elif shown_stage == 0 and body.mesh != plain[0]:
			body.set_surface_override_material(0, null)
			body.mesh = plain[0]
			var materials: Array[Material] = plain[1]
			for i: int in materials.size():
				body.set_surface_override_material(i, materials[i])
