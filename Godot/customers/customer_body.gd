class_name CustomerBody
extends Node3D
## The 3D customer: one placeholder body for all customers. It wears the person's photos: the face
## photo on the face, the average colour of the face photo on the skin, and the shirt from the
## clothes portrait. The back of the shirt repeats a strip at the side of the portrait's clothes, so
## that buttons, pockets and prints stay on the front. The trousers take the customer's colour, and the
## head wears the customer's hat. It walks, with footsteps, while it moves, and carries a computer in
## when the shop says so (carrying).

# The shirt parameters that a portrait sets; without a portrait they come from shirt_material.
const SHIRT_PARAMETERS: Array[StringName] = [&"albedo_texture", &"albedo_color", &"uv_rect", &"tint_texture",
	&"tint_rect", &"fill_transparent"]

## The modelled parts that the photo relief replaces; a hat hangs from the head, so it goes too.
const MODELLED_UPPER_BODY: Array[StringName] = [&"Torso", &"Neck", &"Head", &"Face", &"ShoulderL", &"ShoulderR"]

## The face when the person has no face texture yet.
@export var default_face: Texture2D
## The footsteps where no Ground is under the body; each step plays one take of them.
@export var steps: SoundSet = preload("res://sounds/footsteps.tres")
## The size of the face photo, as a share of the face area: the front of the head from the chin to
## the brow. 1 fills the area; the rest of the area takes the skin colour.
@export_range(0.3, 1.0) var face_scale: float = 0.85
## The gap below the face photo, as a share of the face area's height. Raise it to lift the eyeline;
## above 1 - face_scale, the top of the photo is cut off.
@export_range(0.0, 0.7) var face_lift: float = 0.15
## The portrait pose whose clothes the shirt shows.
@export var clothes_pose: StringName = &"neutral"
## The width of the strip at the side of each shirt part that its back shows, as a share of the
## part's width in the texture. Wider shows more of the front's details on the back.
@export_range(0.05, 0.5) var back_strip: float = 0.15
## The speed, in metres per second, at which the walk plays at its own pace.
@export var walk_speed: float = 1.4
## Shows the upper body as a relief of the person's neutral portrait (PhotoRelief) in place of the
## modelled head, torso, arms and hat; the arms are the photo's, so they hang stiff. Off, or for a
## person with no neutral portrait: the modelled upper body.
@export var photo_relief: bool = true
## The relief's scale: how wide a head is and how high its top is, in metres, and how far the
## middle of the relief bulges each way.
@export var relief_head_width: float = 0.18
@export var relief_top: float = 1.8
@export var relief_depth: float = 0.12
## How far the arms swing while the body walks without a computer, in degrees.
@export var arm_swing: float = 17.0
## How far forward the arms reach to hold the computer, in degrees.
@export var carry_reach: float = 20.0
## The shared materials. Each part that uses one gets this body's own copy, which the customer
## changes.
@export var face_material: ShaderMaterial
@export var skin_material: ShaderMaterial
@export var shirt_material: ShaderMaterial
@export var trousers_material: ShaderMaterial
## The trousers: one low-poly mesh, the pelvis and two straight legs (front is -Z). The legs swing
## with HipL and HipR: their vertices turn about the hips, the crotch row half as far.

## How many sides each trouser leg has.
@export_range(4, 16) var leg_sides: int = 8
## The radius of each straight trouser leg, in metres.
@export var leg_radius: float = 0.072
## Where the trousers end at the top (the waist, under the shirt) and at the bottom (the ankle).
@export var waist_height: float = 1.02
@export var ankle_height: float = 0.08
## How far below the hips the legs part, in metres.
@export var crotch_drop: float = 0.05

var _shown: Customer
var _has_shown: bool = false
var _face: ShaderMaterial
var _skin: ShaderMaterial
var _shirt: ShaderMaterial
var _trousers: ShaderMaterial
var _last_position: Vector3
var _hat: Node3D
var _relief: MeshInstance3D
var _trouser_points: PackedVector3Array
var _trouser_normals: PackedVector3Array
var _trouser_arrays: Array
# Per vertex: -1 the left leg, 1 the right leg, 0 the pelvis; the size is how far it turns (0 to 1).
var _trouser_swing: PackedFloat32Array
var _swung: Vector2 = Vector2(INF, INF)

## True while the body carries a computer in. The shop sets it for a drop-off.
var carrying: bool = false:
	set(value):
		carrying = value
		if is_node_ready():
			_computer.visible = value

@onready var _animation: AnimationPlayer = %AnimationPlayer
@onready var _steps: AudioStreamPlayer3D = %Steps
@onready var _computer: PcTower = %Computer
@onready var _shoulder_left: Node3D = $ShoulderL
@onready var _shoulder_right: Node3D = $ShoulderR
@onready var _hat_mount: Node3D = %HatMount
@onready var _hip_l: Node3D = $HipL
@onready var _hip_r: Node3D = $HipR
@onready var _trousers_mesh: MeshInstance3D = %Trousers


func _ready() -> void:
	add_to_group(ShopDoor.WALKERS)
	_face = _own_copy(face_material)
	_face.set_shader_parameter("uv_rect", _face_rect())
	_skin = _own_copy(skin_material)
	_shirt = _own_copy(shirt_material)
	for node: Node in find_children("*", "MeshInstance3D"):
		var part := node as MeshInstance3D
		if part.material_override == _shirt:
			part.mesh = _back_from_side(part)
	_trousers = _own_copy(trousers_material)
	_trousers_mesh.mesh = ArrayMesh.new()
	_build_trousers()
	_relief = MeshInstance3D.new()
	_relief.name = &"Relief"
	_relief.rotation.y = PI  # the relief's front faces +Z, the body's -Z
	_relief.visible = false
	add_child(_relief)
	_last_position = global_position
	_computer.visible = carrying
	_animation.play(&"idle")


func _process(delta: float) -> void:
	# Only the move across the ground counts; the walk's own bob is up and down.
	var moved := global_position - _last_position
	moved.y = 0.0
	var speed := moved.length() / maxf(delta, 0.0001)
	_last_position = global_position
	# A jump, such as the move back to the start of the path, is not a walk.
	if speed > 0.05 and speed < 20.0:
		_animation.speed_scale = speed / walk_speed
		if _animation.assigned_animation != &"walk":
			_animation.play(&"walk", 0.15)
	elif _animation.assigned_animation != &"idle":
		_animation.speed_scale = 1.0
		_animation.play(&"idle", 0.2)
	_move_arms(delta)
	_skin_trousers()


# The arms hold the computer, or swing against the legs while walking, or hang. They ease between
# those, so a change of pose never snaps.
func _move_arms(delta: float) -> void:
	var swing := 0.0
	if _animation.assigned_animation == &"walk" and _animation.current_animation_length > 0.0:
		var cycle := _animation.current_animation_position / _animation.current_animation_length
		swing = deg_to_rad(arm_swing) * sin(TAU * cycle)
	var left := -swing
	var right := swing
	if carrying:
		left = deg_to_rad(carry_reach)
		right = left
	var weight := minf(delta * 10.0, 1.0)
	_shoulder_left.rotation.x = lerpf(_shoulder_left.rotation.x, left, weight)
	_shoulder_right.rotation.x = lerpf(_shoulder_right.rotation.x, right, weight)


## Plays one footstep of the Ground under the body, or of [member steps] where there is none. The
## walk animation calls it when a foot lands.
func step() -> void:
	var ground := Ground.under(global_position, get_tree())
	if ground == null:
		steps.play_on(_steps)
	elif ground.steps == null:
		push_error("CustomerBody: the Ground %s has no steps" % ground.get_path())
		steps.play_on(_steps)
	else:
		ground.steps.play_on(_steps)


## Dresses the body as [param customer]. null shows the default face and clothes.
func show_customer(customer: Customer) -> void:
	if _has_shown and customer == _shown:
		return
	_has_shown = true
	_shown = customer
	_computer.dress(customer.computer if customer != null else null)
	var person := customer.person if customer != null else null
	var face := default_face
	if person != null and person.face != null:
		face = person.face
	_face.set_shader_parameter("albedo_texture", face)
	_face.set_shader_parameter("tint_texture", face)
	_skin.set_shader_parameter("tint_texture", face)
	_skin.set_shader_parameter("tint_from_texture", true)
	var portrait: Texture2D = person.portraits.get(clothes_pose) if person != null else null
	if portrait != null:
		var rect := person.shirt_rect
		var area := Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y)
		_shirt.set_shader_parameter("albedo_texture", portrait)
		_shirt.set_shader_parameter("albedo_color", Color.WHITE)
		_shirt.set_shader_parameter("uv_rect", area)
		_shirt.set_shader_parameter("tint_texture", portrait)
		_shirt.set_shader_parameter("tint_rect", area)
		_shirt.set_shader_parameter("fill_transparent", true)
	else:
		for parameter: StringName in SHIRT_PARAMETERS:
			_shirt.set_shader_parameter(parameter, shirt_material.get_shader_parameter(parameter))
	var trousers: Color = trousers_material.get_shader_parameter("albedo_color")
	_trousers.set_shader_parameter("albedo_color", customer.trousers_color if customer != null else trousers)
	_wear_hat(customer)
	_show_relief(person)


# Shows the person's photo relief in place of the modelled upper body, or the modelled body when
# there is no relief to show.
func _show_relief(person: Person) -> void:
	var portrait: Texture2D = person.portraits.get(&"neutral") if person != null else null
	var shown := photo_relief and portrait != null
	_relief.visible = shown
	var torso_too := true
	if shown:
		var image := portrait.get_image()
		var scale := relief_head_width / PhotoRelief.head_width(image)
		var bottom := relief_top - image.get_height() * scale
		_relief.mesh = PhotoRelief.build(image, scale, relief_depth)
		_relief.position = Vector3(0.0, bottom, 0.0)
		_relief.set_surface_override_material(PhotoRelief.Surface.FRONT, _relief_material(portrait, Color.WHITE))
		var back := _relief_material(person.back, Color.WHITE) if person.back != null else _relief_material(portrait, Color(0.78, 0.78, 0.78))
		_relief.set_surface_override_material(PhotoRelief.Surface.BACK, back)
		_relief.set_surface_override_material(PhotoRelief.Surface.HEAD_BACK, back if person.back != null else _plain_head_back())
		# A portrait cut at the chest leaves the modelled torso to fill the gap down to the trousers.
		torso_too = bottom >= waist_height - 0.02
	for part: StringName in MODELLED_UPPER_BODY:
		(get_node(NodePath(part)) as Node3D).visible = not shown or (part == &"Torso" and torso_too)


func _relief_material(texture: Texture2D, tint: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = skin_material.shader
	material.set_shader_parameter(&"albedo_texture", texture)
	material.set_shader_parameter(&"albedo_color", tint)
	return material


# Without a back picture, the back of the head takes the hat or hair colour from the vertex colours.
func _plain_head_back() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	return material


func _wear_hat(customer: Customer) -> void:
	if _hat != null:
		_hat.queue_free()
		_hat = null
	var scene := customer.hat if customer != null else null
	if scene == null:
		return
	var hat := scene.instantiate()
	if hat == null:
		push_error("CustomerBody: the hat %s of %s doesn't instantiate" % [scene.resource_path, customer.resource_path])
		return
	if not hat is Node3D:
		push_error("CustomerBody: the hat %s of %s has a %s root, not a Node3D" % [scene.resource_path,
			customer.resource_path, hat.get_class()])
		hat.free()
		return
	_hat = hat
	_hat_mount.add_child(_hat)


# The uv_rect that shows the whole face photo at face_scale, centred, face_lift above the chin.
func _face_rect() -> Vector4:
	var corner := Vector2((1.0 - face_scale) * 0.5, 1.0 - face_lift - face_scale)
	return Vector4(-corner.x / face_scale, -corner.y / face_scale, 1.0 / face_scale, 1.0 / face_scale)


# A copy of the part's mesh whose back faces (+Z; the body looks along -Z) have their own vertices,
# with UVs that repeat the strip at the part's +X side across the back instead of mirroring the front.
# Along each ring of the back, the vertices alternate between the two edges of the strip.
func _back_from_side(part: MeshInstance3D) -> ArrayMesh:
	var mesh := part.mesh
	assert(mesh != null and mesh.get_surface_count() == 1, "CustomerBody: %s needs one surface" % part.name)
	var arrays := mesh.surface_get_arrays(0)
	for kept: int in [Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV2, Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS]:
		assert(arrays[kept] == null, "CustomerBody: %s has vertex data that the back copy drops" % part.name)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT] if arrays[Mesh.ARRAY_TANGENT] != null else PackedFloat32Array()
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var u_min := INF
	var u_max := -INF
	for uv: Vector2 in uvs:
		u_min = minf(u_min, uv.x)
		u_max = maxf(u_max, uv.x)
	var strip := (u_max - u_min) * back_strip
	var back_corners: Array[int] = []
	var rings: Dictionary[float, Array] = {}
	for corner: int in indices.size():
		var first := corner - corner % 3
		var facing := normals[indices[first]] + normals[indices[first + 1]] + normals[indices[first + 2]]
		if facing.z <= 0.3 * facing.length():
			continue
		back_corners.append(corner)
		var ring: Array = rings.get_or_add(snappedf(vertices[indices[corner]].y, 0.001), [])
		if not ring.has(indices[corner]):
			ring.append(indices[corner])
	var back_copy: Dictionary[int, int] = {}
	for ring: Array in rings.values():
		ring.sort_custom(func(a: int, b: int) -> bool: return vertices[a].x > vertices[b].x)
		for rank: int in ring.size():
			var index: int = ring[rank]
			back_copy[index] = vertices.size()
			vertices.append(vertices[index])
			normals.append(normals[index])
			if not tangents.is_empty():
				tangents.append_array(tangents.slice(index * 4, index * 4 + 4))
			uvs.append(Vector2(u_min + strip * (rank % 2), uvs[index].y))
	for corner: int in back_corners:
		indices[corner] = back_copy[indices[corner]]
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents if not tangents.is_empty() else null
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var copy := ArrayMesh.new()
	copy.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return copy


func _build_trousers() -> void:
	var hip_left := _hip_l.position
	var hip_right := _hip_r.position
	var crotch := hip_left.y - crotch_drop
	var knee := (crotch + ankle_height) * 0.5
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points: Array[Vector3] = []
	var swings: Array[float] = []
	# One vertex per call; every face gets its own corners, so the polygons stay flat-edged and crisp.
	var corner := func(at: Vector3, swing: float) -> void:
		tool.set_uv(Vector2(atan2(at.z, at.x) / TAU * 2.0, at.y * 3.0))
		tool.add_vertex(at)
		points.append(at)
		swings.append(swing)
	var quad := func(a: Vector3, b: Vector3, c: Vector3, d: Vector3, sa: float, sb: float, sc: float, sd: float) -> void:
		# Godot's front faces run clockwise; a, b, c, d run the other way round as seen from outside.
		corner.call(a, sa); corner.call(c, sc); corner.call(b, sb)
		corner.call(a, sa); corner.call(d, sd); corner.call(c, sc)
	# The ring of one leg at a height: angle 0 points to +X, 90 degrees to +Z (the back).
	var ring := func(centre: Vector3, height: float) -> Array[Vector3]:
		var out: Array[Vector3] = []
		for k: int in leg_sides:
			var angle := TAU * k / leg_sides
			out.append(Vector3(centre.x + cos(angle) * leg_radius, height, sin(angle) * leg_radius))
		return out
	for side: int in [-1, 1]:
		var centre := hip_left if side < 0 else hip_right
		var rings := [ring.call(centre, crotch), ring.call(centre, knee), ring.call(centre, ankle_height)]
		var weights := [0.5 * side, side, side]
		for band: int in 2:
			for k: int in leg_sides:
				var n := (k + 1) % leg_sides
				quad.call(rings[band][k], rings[band][n], rings[band + 1][n], rings[band + 1][k], weights[band], weights[band], weights[band + 1], weights[band + 1])
		# The outer half of each leg's top ring rises straight up as the pelvis wall.
		for k: int in leg_sides:
			var n := (k + 1) % leg_sides
			var a: Vector3 = rings[0][k]
			var b: Vector3 = rings[0][n]
			if (a.x - centre.x) * side < -0.001 or (b.x - centre.x) * side < -0.001:
				continue
			quad.call(Vector3(a.x, waist_height, a.z), Vector3(b.x, waist_height, b.z), b, a, 0.0, 0.0, 0.5 * side, 0.5 * side)
	# The front and the back of the pelvis span the gap between the legs; the crotch closes it below.
	for z: float in [-leg_radius, leg_radius]:
		var left := Vector3(hip_left.x, crotch, z)
		var right := Vector3(hip_right.x, crotch, z)
		var left_top := Vector3(left.x, waist_height, z)
		var right_top := Vector3(right.x, waist_height, z)
		if z < 0.0:
			quad.call(left_top, right_top, right, left, 0.0, 0.0, 0.5, -0.5)
		else:
			quad.call(right_top, left_top, left, right, 0.0, 0.0, -0.5, 0.5)
	quad.call(Vector3(hip_left.x, crotch, -leg_radius), Vector3(hip_right.x, crotch, -leg_radius), Vector3(hip_right.x, crotch, leg_radius), Vector3(hip_left.x, crotch, leg_radius), -0.5, 0.5, 0.5, -0.5)
	tool.generate_normals()
	_trouser_arrays = tool.commit_to_arrays()
	_trouser_points = _trouser_arrays[Mesh.ARRAY_VERTEX]
	_trouser_normals = _trouser_arrays[Mesh.ARRAY_NORMAL]
	_trouser_swing = PackedFloat32Array(swings)
	_skin_trousers(true)


# Turns the leg vertices with the hips; does nothing while the hips stand still.
func _skin_trousers(force: bool = false) -> void:
	var angles := Vector2(_hip_l.rotation.x, _hip_r.rotation.x)
	if not force and angles.is_equal_approx(_swung):
		return
	_swung = angles
	var points := _trouser_points.duplicate()
	var normals := _trouser_normals.duplicate()
	for i: int in points.size():
		var swing := _trouser_swing[i]
		if swing == 0.0:
			continue
		var hip := _hip_l if swing < 0.0 else _hip_r
		var turn := Basis(Vector3.RIGHT, hip.rotation.x * absf(swing))
		points[i] = hip.position + turn * (points[i] - hip.position)
		normals[i] = turn * normals[i]
	var arrays := _trouser_arrays.duplicate()
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := _trousers_mesh.mesh as ArrayMesh
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


func _own_copy(shared: ShaderMaterial) -> ShaderMaterial:
	assert(shared != null, "CustomerBody: set the four materials in the inspector")
	var copy := shared.duplicate() as ShaderMaterial
	for node: Node in find_children("*", "MeshInstance3D"):
		var part := node as MeshInstance3D
		if part.material_override == shared:
			part.material_override = copy
	return copy
