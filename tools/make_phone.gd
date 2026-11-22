extends SceneTree
## Builds the shop's mid-1990s push-button desk phone: its atlas (materials/textures/phone.png)
## and its mesh, props/phone.tres, with two surfaces: 0 the plastic body and handset
## (BODY_MATERIAL), 1 the atlas details (materials/phone.tres): the sloped keypad face and the
## coiled cord. The atlas draws its plastic from BODY_MATERIAL's texture and colour, so the two match.
## The keypad faces +Z, X runs across the phone, the floor is at Y 0; the handset lies across the
## back on two cradle hooks, and its cord coils down the -X side onto the desk and into the base.
## Usage, from Godot/: godot --headless --path . -s ../tools/make_phone.gd, then --import.

const ATLAS_PATH := "res://materials/textures/phone.png"
const MESH_PATH := "res://props/phone.tres"
const BODY_MATERIAL := "res://materials/beige_plastic.tres"
const ATLAS_SIZE := Vector2(64.0, 64.0)

const SLOPE := Rect2i(0, 0, 48, 32)
const CORD := Rect2i(48, 0, 8, 8)

const KEY := Color8(84, 82, 78)
const KEY_SHADE := Color8(48, 46, 44)
const MARK := Color8(226, 224, 216)
const LED := Color8(220, 40, 30)
const LABEL := Color8(242, 240, 232)

## The base's side profile as (z, y), front bottom to back bottom; the keypad face runs from the
## third point to the fourth.
const PROFILE: Array[Vector2] = [Vector2(0.105, 0.0), Vector2(0.105, 0.022), Vector2(0.092, 0.03),
	Vector2(-0.03, 0.05), Vector2(-0.098, 0.05), Vector2(-0.105, 0.042), Vector2(-0.105, 0.0)]
## Half the base's width at the floor, and how much narrower each side gets at the top.
const HALF_WIDTH := 0.1
const TOP_INSET := 0.012
const TOP := 0.05

## The handset: its centre line across X at depth HANDSET_Z, the grip's half height and depth, the
## cups' at the ends, and how far the ends dip.
const HANDSET_Z := -0.066
const HANDSET_HALF_LENGTH := 0.106
const GRIP := Vector2(0.017, 0.011)
const CUP := Vector2(0.026, 0.016)
const HOOK_TOP := 0.061
const DIP := 0.018

const CORD_RADIUS := 0.0045
const CORD_POINTS: Array[Vector3] = [Vector3(-0.1, 0.052, -0.066), Vector3(-0.122, 0.03, -0.06),
	Vector3(-0.133, 0.007, -0.02), Vector3(-0.127, 0.007, 0.035), Vector3(-0.098, 0.014, 0.045)]

var _img := Image.create(int(ATLAS_SIZE.x), int(ATLAS_SIZE.y), false, Image.FORMAT_RGBA8)
var _body := SurfaceTool.new()
var _detail := SurfaceTool.new()


func _initialize() -> void:
	var failed := not _draw_atlas()
	if not failed:
		var err := _img.save_png(ProjectSettings.globalize_path(ATLAS_PATH))
		if err != OK:
			push_error("make_phone: couldn't save %s: %s" % [ATLAS_PATH, error_string(err)])
			failed = true
		else:
			print("make_phone: wrote ", ATLAS_PATH)
	for st: SurfaceTool in [_body, _detail]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_base()
	_handset()
	_cord()
	failed = not _save() or failed
	quit(1 if failed else 0)


func _save() -> bool:
	var mesh := ArrayMesh.new()
	for st: SurfaceTool in [_body, _detail]:
		st.index()
		st.commit(mesh)
	var err := ResourceSaver.save(mesh, MESH_PATH)
	if err != OK:
		push_error("make_phone: couldn't save %s: %s" % [MESH_PATH, error_string(err)])
		return false
	print("make_phone: wrote ", MESH_PATH)
	return true


# --- The atlas -------------------------------------------------------------------------------

## Fills the atlas with BODY_MATERIAL's plastic, then draws the keypad face and the cord's coils.
func _draw_atlas() -> bool:
	var material := load(BODY_MATERIAL) as ShaderMaterial
	var texture := material.get_shader_parameter(&"albedo_texture") as Texture2D if material != null else null
	if texture == null:
		push_error("make_phone: %s is not a ShaderMaterial with an albedo_texture" % BODY_MATERIAL)
		return false
	var plastic := Image.load_from_file(ProjectSettings.globalize_path(texture.resource_path))
	if plastic == null or plastic.is_empty():
		push_error("make_phone: couldn't read %s" % texture.resource_path)
		return false
	plastic.decompress()
	var tint: Color = material.get_shader_parameter(&"albedo_color")
	for y in int(ATLAS_SIZE.y):
		for x in int(ATLAS_SIZE.x):
			_img.set_pixel(x, y, plastic.get_pixel(x % plastic.get_width(), y % plastic.get_height()) * tint)
	_keypad()
	_coils()
	return true


## Twelve keys in four rows, three function keys and the message lamp on the left, and the paper
## number label along the front edge. The top of the rect is the back of the face.
func _keypad() -> void:
	var o := SLOPE.position
	_img.fill_rect(Rect2i(o.x + 5, o.y + 3, 2, 2), LED)
	for row in 3:
		_key(Rect2i(o.x + 3, o.y + 9 + row * 6, 6, 4))
	for row in 4:
		for col in 3:
			var key := Rect2i(o.x + 16 + col * 9, o.y + 4 + row * 6, 7, 4)
			_key(key)
			_img.fill_rect(Rect2i(key.position.x + 3, key.position.y + 1, 1, 2), MARK)
	_img.fill_rect(Rect2i(o.x + 14, o.y + SLOPE.size.y - 4, 30, 2), LABEL)


func _key(r: Rect2i) -> void:
	_img.fill_rect(r, KEY)
	_img.fill_rect(Rect2i(r.position.x, r.end.y - 1, r.size.x, 1), KEY_SHADE)
	_img.fill_rect(Rect2i(r.end.x - 1, r.position.y, 1, r.size.y), KEY_SHADE)


## Dark grooves between the coils; each cord segment maps onto the whole rect.
func _coils() -> void:
	for y in range(CORD.position.y + 1, CORD.end.y, 2):
		for x in range(CORD.position.x, CORD.end.x):
			_img.set_pixel(x, y, _img.get_pixel(x, y).darkened(0.45))


func _uv(rect: Rect2i, f: Vector2) -> Vector2:
	return (Vector2(rect.position) + Vector2(rect.size) * f) / ATLAS_SIZE


# --- The mesh --------------------------------------------------------------------------------

func _half_width(y: float) -> float:
	return HALF_WIDTH - TOP_INSET * y / TOP


## The base: its profile extruded across X, narrowing to the top, and the two cradle hooks.
func _base() -> void:
	var centre := Vector3(0.0, TOP * 0.5, 0.0)
	var count := PROFILE.size()
	for i in count:
		var a := PROFILE[i]
		var b := PROFILE[(i + 1) % count]
		var quad: Array[Vector3] = [_at(a, -1.0), _at(a, 1.0), _at(b, 1.0), _at(b, -1.0)]
		if i == 2:
			var uvs: Array[Vector2] = [_uv(SLOPE, Vector2(0, 1)), _uv(SLOPE, Vector2(1, 1)), _uv(SLOPE, Vector2(1, 0)), _uv(SLOPE, Vector2(0, 0))]
			_polygon(_detail, quad, uvs, centre)
		else:
			_polygon(_body, quad, [], centre)
	for side: float in [-1.0, 1.0]:
		var cap: Array[Vector3] = []
		for p in PROFILE:
			cap.append(_at(p, side))
		_polygon(_body, cap, [], centre)
	for x: float in [-0.068, 0.068]:
		_box(Vector3(x, (TOP + HOOK_TOP) * 0.5, HANDSET_Z), Vector3(0.02, HOOK_TOP - TOP + 0.004, 0.03))


func _at(p: Vector2, side: float) -> Vector3:
	return Vector3(side * _half_width(p.y), p.y, p.x)


func _box(center: Vector3, size: Vector3) -> void:
	var h := size * 0.5
	var corners: Array[Vector3] = []
	for i in 8:
		corners.append(center + Vector3(h.x * (1 if i & 1 else -1), h.y * (1 if i & 2 else -1), h.z * (1 if i & 4 else -1)))
	for face: Array in [[0, 1, 3, 2], [4, 5, 7, 6], [0, 1, 5, 4], [2, 3, 7, 6], [0, 2, 6, 4], [1, 3, 7, 5]]:
		var quad: Array[Vector3] = []
		for k: int in face:
			quad.append(corners[k])
		_polygon(_body, quad, [], center)


## A convex flat polygon with one normal, facing away from [param inside].
func _polygon(st: SurfaceTool, points: Array[Vector3], uvs: Array[Vector2], inside: Vector3) -> void:
	var middle := Vector3.ZERO
	for p in points:
		middle += p
	middle /= points.size()
	var n := (points[1] - points[0]).cross(points[2] - points[0]).normalized()
	var reverse := n.dot(middle - inside) > 0.0  # Godot's front faces wind clockwise seen from outside
	if not reverse:
		n = -n
	for i in range(1, points.size() - 1):
		var tri := [0, i + 1, i] if reverse else [0, i, i + 1]
		for k: int in tri:
			st.set_normal(n)
			if not uvs.is_empty():
				st.set_uv(uvs[k])
			st.add_vertex(points[k])


## The handset: an elliptic tube along X that widens into the ear and mouth cups and dips at the
## ends, resting on the cradle hooks.
func _handset() -> void:
	var rings: Array = []
	var steps := 14
	var sides := 8
	var top_y := HOOK_TOP + GRIP.y
	for s in steps + 1:
		var x := lerpf(-HANDSET_HALF_LENGTH, HANDSET_HALF_LENGTH, float(s) / steps)
		var end := clampf((absf(x) - 0.06) / (HANDSET_HALF_LENGTH - 0.06), 0.0, 1.0)
		var half := GRIP.lerp(CUP, smoothstep(0.0, 1.0, end))
		var y := top_y - DIP * end * end
		var ring: Array[Vector3] = []
		for k in sides:
			var a := TAU * k / sides
			ring.append(Vector3(x, y + sin(a) * half.y, HANDSET_Z + cos(a) * half.x))
		rings.append([Vector3(x, y, HANDSET_Z), ring])
	_tube(_body, rings, Rect2i())


## The coiled cord: a thin tube along a Catmull-Rom curve through CORD_POINTS.
func _cord() -> void:
	var path: Array[Vector3] = []
	var per := 8
	for i in CORD_POINTS.size() - 1:
		var p0 := CORD_POINTS[maxi(i - 1, 0)]
		var p1 := CORD_POINTS[i]
		var p2 := CORD_POINTS[i + 1]
		var p3 := CORD_POINTS[mini(i + 2, CORD_POINTS.size() - 1)]
		for s in per:
			var t := float(s) / per
			path.append(0.5 * ((2.0 * p1) + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (3.0 * p1 - p0 - 3.0 * p2 + p3) * t * t * t))
	path.append(CORD_POINTS[-1])
	var rings: Array = []
	var sides := 6
	for i in path.size():
		var tangent := (path[mini(i + 1, path.size() - 1)] - path[maxi(i - 1, 0)]).normalized()
		var across := tangent.cross(Vector3.UP).normalized()
		if across.length_squared() < 0.5:
			across = Vector3.RIGHT
		var up := across.cross(tangent).normalized()
		var ring: Array[Vector3] = []
		for k in sides:
			var a := TAU * k / sides
			ring.append(path[i] + (across * cos(a) + up * sin(a)) * CORD_RADIUS)
		rings.append([path[i], ring])
	_tube(_detail, rings, CORD)


## Joins rings of [centre, Array[Vector3]] into a closed tube with smooth normals and capped ends.
## A [param rect] maps onto every segment, around and along; an empty one maps nothing.
func _tube(st: SurfaceTool, rings: Array, rect: Rect2i) -> void:
	for r in rings.size() - 1:
		var c0: Vector3 = rings[r][0]
		var c1: Vector3 = rings[r + 1][0]
		var a: Array[Vector3] = rings[r][1]
		var b: Array[Vector3] = rings[r + 1][1]
		var sides := a.size()
		for k in sides:
			var k1 := (k + 1) % sides
			var corners: Array[Vector3] = [a[k], a[k1], b[k1], b[k]]
			var centres: Array[Vector3] = [c0, c0, c1, c1]
			var uvs: Array[Vector2] = [Vector2(float(k) / sides, 0), Vector2(float(k + 1) / sides, 0), Vector2(float(k + 1) / sides, 1), Vector2(float(k) / sides, 1)]
			var n := (corners[1] - corners[0]).cross(corners[2] - corners[0])
			var tri := [0, 2, 1, 0, 3, 2] if n.dot(corners[0] - c0) > 0.0 else [0, 1, 2, 0, 2, 3]
			for i: int in tri:
				st.set_normal((corners[i] - centres[i]).normalized())
				if rect != Rect2i():
					st.set_uv(_uv(rect, uvs[i]))
				st.add_vertex(corners[i])
	for end: int in [0, rings.size() - 1]:
		var cap: Array[Vector3] = []
		cap.assign(rings[end][1])
		var beyond: Vector3 = rings[1 if end == 0 else end - 1][0]
		var uvs: Array[Vector2] = []
		if rect != Rect2i():
			for p in cap:
				uvs.append(_uv(rect, Vector2(0.5, 0.5)))
		_polygon(st, cap, uvs, beyond)
