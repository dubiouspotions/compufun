class_name CustomerBody
extends Node3D
## The 3D customer: one grey body for all customers, with the face texture of the person.

const NO_FACE_COLOR: Color = Color(0.45, 0.45, 0.45)

var _shown: Customer

@onready var _face: MeshInstance3D = %Face
@onready var _face_label: Label3D = %FaceLabel
@onready var _name_label: Label3D = %NameLabel


## Shows the name and the face of [param customer]. null clears them.
func show_customer(customer: Customer) -> void:
	if customer == _shown:
		return
	_shown = customer
	_name_label.text = customer.display_name if customer != null else ""
	var face: Texture2D = null
	if customer != null and customer.person != null:
		face = customer.person.face
	var material := StandardMaterial3D.new()
	material.albedo_texture = face
	material.albedo_color = Color.WHITE if face != null else NO_FACE_COLOR
	_face.material_override = material
	_face_label.visible = face == null
