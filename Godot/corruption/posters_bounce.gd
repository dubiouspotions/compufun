extends CorruptionSign
## The sheets in the group solitaire_posters (the logo on the left wall, the poster on the right wall)
## leave the wall like the cards of the Solitaire win: each drops onto the screen, bounces along its
## bottom edge and out at the side, and leaves itself behind on every frame, as nothing clears the
## trail. It draws in the world buffer, so the trail gets the PSX look. Stage 1 plays it, and the night
## waits for it ([method busy]); then it sets stage 2: the sheets are gone and the trail stays. Stage
## 0 hangs them back on the wall.

const SHEETS: StringName = &"solitaire_posters"

## The size of a sheet on the screen: pixels of the world buffer (480 x 270) per metre of the sheet.
@export var pixels_per_metre: float = 60.0
## The speed sideways, in pixels per second, towards the middle of the screen.
@export var side_speed: float = 170.0
## The speed up when a sheet leaves the wall, in pixels per second.
@export var jump_speed: float = 60.0
## The pull down, in pixels per second per second.
@export var gravity: float = 700.0
## The share of the speed that a bounce keeps, 0 to 1.
@export_range(0.0, 1.0) var bounce: float = 0.8

var _sheets: Array[Node3D] = []
var _cards: Array[Sprite2D] = []
var _speeds: Array[Vector2] = []

@onready var _overlay: CanvasLayer = %Overlay
@onready var _trail: SubViewport = %Trail


func _ready() -> void:
	for node: Node in get_tree().get_nodes_in_group(SHEETS):
		_sheets.append(node as Node3D)
	if _sheets.is_empty():
		push_error("posters_bounce: nothing in the group %s" % SHEETS)
	_trail.size = get_viewport().size
	(%Screen as TextureRect).texture = _trail.get_texture()
	set_process(false)
	super()


## True while the sheets fall: the night waits for it.
func busy() -> bool:
	return stage() == 1


func _apply(shown_stage: int) -> void:
	if shown_stage == 1:
		if not is_processing():
			_fall()
		return
	set_process(false)
	_overlay.visible = shown_stage != 0
	for sheet: Node3D in _sheets:
		sheet.visible = shown_stage == 0
	if shown_stage == 0:
		_clear()


func _process(delta: float) -> void:
	var size := Vector2(_trail.size)
	var gone := true
	for index: int in _cards.size():
		var card := _cards[index]
		var half := card.get_rect().size * card.scale * 0.5
		var speed := _speeds[index] + Vector2.DOWN * gravity * delta
		card.position += speed * delta
		if card.position.y + half.y > size.y and speed.y > 0.0:
			card.position.y = size.y - half.y
			speed.y *= -bounce
		_speeds[index] = speed
		gone = gone and (card.position.x < -half.x or card.position.x > size.x + half.x)
	if gone:
		set_stage(2)


func _fall() -> void:
	_clear()
	_overlay.show()
	var camera := get_viewport().get_camera_3d()
	var size := Vector2(_trail.size)
	for sheet: Node3D in _sheets:
		var card := Sprite2D.new()
		var mesh := _mesh_of(sheet)
		if mesh != null:
			card.texture = (mesh.material_override as ShaderMaterial).get_shader_parameter(&"albedo_texture")
			var metres := mesh.get_aabb().size.y * mesh.global_basis.get_scale().y
			card.scale = Vector2.ONE * metres * pixels_per_metre / card.texture.get_height()
		var half := card.get_rect().size * card.scale * 0.5
		var at := _on_screen(camera, sheet.global_position, size)
		card.position = at.clamp(half, size - half)
		_trail.add_child(card)
		_cards.append(card)
		var side := -1.0 if at.x > size.x * 0.5 else 1.0
		_speeds.append(Vector2(side * side_speed, -jump_speed))
		sheet.hide()
	set_process(true)


# Where [param point] shows in the world buffer; a point behind the camera goes to the side it is on.
func _on_screen(camera: Camera3D, point: Vector3, size: Vector2) -> Vector2:
	if camera == null:
		return size * 0.5
	if camera.is_position_behind(point):
		var right := (point - camera.global_position).dot(camera.global_basis.x) > 0.0
		return Vector2(size.x if right else 0.0, size.y * 0.3)
	return camera.unproject_position(point)


# The mesh that shows the picture of a sheet: the albedo_texture of its material, as LogoSign and
# Poster draw it.
func _mesh_of(sheet: Node3D) -> MeshInstance3D:
	var meshes := sheet.find_children("*", "MeshInstance3D", true, false)
	if sheet is MeshInstance3D:
		meshes.push_front(sheet)
	for mesh: MeshInstance3D in meshes:
		var look := mesh.material_override as ShaderMaterial
		if look != null and look.get_shader_parameter(&"albedo_texture") is Texture2D:
			return mesh
	push_error("posters_bounce: %s has no mesh with an albedo_texture" % sheet.get_path())
	return null


func _clear() -> void:
	for card: Sprite2D in _cards:
		card.queue_free()
	_cards.clear()
	_speeds.clear()
	_trail.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
