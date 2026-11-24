class_name Piece
extends RefCounted
## One real part: which Part it is, and whether it is broken. It sits in a computer, lies on a job's
## mat, or is in the player's hand.

const PSX_WORLD: Shader = preload("res://shaders/psx_world.gdshader")

var part: Part
var broken: bool = false
## True for a piece from a box in the storage that has never been in a computer: only such a piece
## can go back into its box.
var unused: bool = false
## True for a working piece that the customer wants out of the computer (Problem.unwanted_part): it
## runs and looks like any other, but a computer with it in isn't fixed (Job.hardware_fixed).
var unwanted: bool = false


func _init(piece_part: Part, piece_broken: bool = false, piece_unused: bool = false, piece_unwanted: bool = false) -> void:
	part = piece_part
	broken = piece_broken
	unused = piece_unused
	unwanted = piece_unwanted


## A new instance of the part's [member Part.model], its Broken child shown only when this piece is
## broken (see [member Part.model]). A broken piece's meshes that use the PSX look also show grime:
## darker, with dirt (a copy of their material with the psx_world shader's [code]grime[/code] at 1).
## null, with an error, when the part has no model.
func make_model() -> Node3D:
	if part.model == null:
		push_error("Piece: %s has no model" % part.resource_path)
		return null
	var model := part.instantiate_model()
	var broken_look := model.get_node_or_null(^"Broken") as Node3D
	if broken_look != null:
		broken_look.visible = broken
	if broken:
		for mesh: Node in model.find_children("*", "GeometryInstance3D"):
			var material := (mesh as GeometryInstance3D).material_override as ShaderMaterial
			if material != null and material.shader == PSX_WORLD:
				var grimy := material.duplicate() as ShaderMaterial
				grimy.set_shader_parameter(&"grime", 1.0)
				(mesh as GeometryInstance3D).material_override = grimy
	return model
